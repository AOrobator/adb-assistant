import Foundation
import Combine

/// Manages ADB device communication and log streaming
@MainActor
public class ADBManager: ObservableObject {
    
    @Published public var devices: [Device] = []
    @Published public var selectedDevice: Device?
    @Published public var isConnected: Bool = false
    @Published public var connectionError: String?
    
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var cancellables = Set<AnyCancellable>()
    private var logSubject = PassthroughSubject<LogEntry, Never>()
    private var disconnectTimer: Timer?
    
    public var logStream: AnyPublisher<LogEntry, Never> {
        logSubject.eraseToAnyPublisher()
    }
    
    public init() {
        // Start auto-refresh timer for device detection
        startDeviceRefreshTimer()
    }
    
    private var refreshTimer: Timer?
    
    private func startDeviceRefreshTimer() {
        // Initial refresh
        Task {
            await refreshDevicesWithAutoSelect()
        }
        
        // Set up periodic refresh every 2 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshDevicesWithAutoSelect()
            }
        }
    }
    
    private func refreshDevicesWithAutoSelect() async {
        do {
            let newDevices = try await listDevices()
            
            // Auto-select logic:
            // 1. If no device selected and there's only one device, select it
            // 2. If selected device is no longer connected, select another if available
            // 3. If selected device is still connected, keep it
            
            if selectedDevice == nil && newDevices.count == 1 {
                // Auto-select the only device
                selectedDevice = newDevices.first
            } else if let current = selectedDevice, !newDevices.contains(where: { $0.id == current.id }) {
                // Selected device disconnected, try to select another
                selectedDevice = newDevices.first
            }
            // Otherwise keep current selection
        } catch {
            connectionError = error.localizedDescription
        }
    }
    
    // MARK: - Device Management
    
    /// Lists all connected ADB devices
    public func listDevices() async throws -> [Device] {
        let output = try await executeADBCommand(["devices", "-l"])
        let devices = parseDevices(output)
        
        await MainActor.run {
            self.devices = devices
        }
        
        return devices
    }
    
    /// Refreshes the device list
    public func refreshDevices() async {
        do {
            _ = try await listDevices()
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Log Streaming
    
    /// Starts streaming logs from the selected device
    public func startLogcat(filter: String? = nil) async throws {
        guard let device = selectedDevice else {
            throw ADBError.noDeviceSelected
        }
        
        stopLogcat()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        var arguments = ["adb", "-s", device.serial, "logcat", "-v", "threadtime"]
        if let filter = filter, !filter.isEmpty {
            arguments.append(filter)
        }
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard let output = String(data: data, encoding: .utf8),
                  !output.isEmpty else { return }
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                guard let entry = LogParser.parseLine(line) else { continue }
                Task { @MainActor in
                    self.logSubject.send(entry)
                }
            }
            
            // Reset disconnect timer on data received
            Task { @MainActor in
                self.resetDisconnectTimer()
            }
        }
        
        // Handle errors
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let error = String(data: data, encoding: .utf8),
                  !error.isEmpty else { return }
            
            Task { @MainActor in
                self?.connectionError = error
                self?.isConnected = false
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isConnected = false
                self?.cancelDisconnectTimer()
            }
        }
        
        try process.run()
        
        self.process = process
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.isConnected = true
        self.connectionError = nil
        
        // Start disconnect detection timer
        startDisconnectTimer()
    }
    
    /// Stops the logcat stream
    public func stopLogcat() {
        process?.terminate()
        process = nil
        outputPipe = nil
        errorPipe = nil
        isConnected = false
        cancelDisconnectTimer()
    }
    
    /// Clears the log buffer on the device
    public func clearLogs() async throws {
        guard let device = selectedDevice else {
            throw ADBError.noDeviceSelected
        }
        
        _ = try await executeADBCommand(["-s", device.serial, "logcat", "-c"])
    }
    
    /// Gets the PID for a package name
    public func getPID(for package: String) async throws -> Int? {
        guard let device = selectedDevice else {
            throw ADBError.noDeviceSelected
        }
        
        let output = try await executeADBCommand([
            "-s", device.serial, "shell", "pidof", package
        ])
        
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }
    
    /// Lists installed packages
    public func listPackages() async throws -> [String] {
        guard let device = selectedDevice else {
            throw ADBError.noDeviceSelected
        }
        
        let output = try await executeADBCommand([
            "-s", device.serial, "shell", "pm", "list", "packages"
        ])
        
        return output.components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard line.hasPrefix("package:") else { return nil }
                return String(line.dropFirst(8))
            }
    }
    
    // MARK: - Private Methods
    
    private func executeADBCommand(_ arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["adb"] + arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ADBError.commandFailed(output))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseDevices(_ output: String) -> [Device] {
        let lines = output.components(separatedBy: .newlines)
        var devices: [Device] = []
        
        for line in lines.dropFirst(1) { // Skip "List of devices attached" header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let components = trimmed.components(separatedBy: .whitespaces)
            guard components.count >= 2 else { continue }
            
            let serial = components[0]
            let statusString = components[1]
            let status = DeviceStatus(rawValue: statusString) ?? .unknown
            
            // Parse model from product:xxx model:yyy
            var model: String?
            if let modelIndex = components.firstIndex(where: { $0.hasPrefix("model:") }) {
                model = String(components[modelIndex].dropFirst(6))
            }
            
            devices.append(Device(serial: serial, model: model, status: status))
        }
        
        return devices
    }
    
    // MARK: - Disconnect Detection
    
    private func startDisconnectTimer() {
        disconnectTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.isConnected = false
            }
        }
    }
    
    private func resetDisconnectTimer() {
        disconnectTimer?.fireDate = Date().addingTimeInterval(0.5)
    }
    
    private func cancelDisconnectTimer() {
        disconnectTimer?.invalidate()
        disconnectTimer = nil
    }
}

public enum ADBError: Error, LocalizedError {
    case noDeviceSelected
    case commandFailed(String)
    case notInstalled
    
    public var errorDescription: String? {
        switch self {
        case .noDeviceSelected:
            return "No device selected"
        case .commandFailed(let output):
            return "ADB command failed: \(output)"
        case .notInstalled:
            return "ADB is not installed or not in PATH"
        }
    }
}
