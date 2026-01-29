import SwiftUI
import ADBAssistant

struct ToolbarView: View {
    @EnvironmentObject var adbManager: ADBManager
    @EnvironmentObject var logBuffer: LogBuffer
    @Binding var searchText: String
    @Binding var selectedLevels: Set<LogLevel>
    @Binding var selectedPackage: String?
    @Binding var isSearching: Bool
    @FocusState var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Device picker
            DevicePicker()

            // Package picker
            PackagePicker(selectedPackage: $selectedPackage)

            Divider()
                .frame(height: 20)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button(action: { Self.clearSearch(&searchText) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            
            Divider()
                .frame(height: 20)
            
            // Level filters
            LevelFilterView(selectedLevels: $selectedLevels)
            
            Spacer()
            
            // Action buttons
            Button(action: { Self.stopLogcat(adbManager) }) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
            .disabled(!adbManager.isConnected)
            
            Button(action: { Self.startLogcat(adbManager) }) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .disabled(adbManager.isConnected || adbManager.selectedDevice == nil)
            
            Button(action: { Self.clearDeviceLogs(adbManager, logBuffer) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
    
    static func clearSearch(_ searchText: inout String) {
        searchText = ""
    }
    
    static func stopLogcat(_ adbManager: ADBManager) {
        adbManager.stopLogcat()
    }
    
    static func startLogcat(_ adbManager: ADBManager) {
        Task {
            try? await adbManager.startLogcat()
        }
    }
    
    static func clearDeviceLogs(_ adbManager: ADBManager, _ logBuffer: LogBuffer) {
        logBuffer.clear()
        Task {
            try? await adbManager.clearLogs()
        }
    }
}

struct DevicePicker: View {
    @EnvironmentObject var adbManager: ADBManager
    @EnvironmentObject var logBuffer: LogBuffer

    var body: some View {
        Menu {
            ForEach(adbManager.devices) { device in
                Button(action: selectDeviceAction(device: device, adbManager: adbManager, logBuffer: logBuffer)) {
                    HStack {
                        Text(Self.deviceDisplayName(device))
                        if device.id == adbManager.selectedDevice?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            if adbManager.devices.isEmpty {
                Text("No devices connected")
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            Button("Refresh", action: { Self.refreshDevices(adbManager) })
        } label: {
            HStack {
                Image(systemName: "iphone")
                Text(adbManager.selectedDevice.map { Self.deviceDisplayName($0) } ?? "Select Device")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }
    
    static func deviceDisplayName(_ device: Device) -> String {
        if let model = device.model {
            return "\(model) (\(device.serial.prefix(8)))"
        }
        return device.serial
    }
    
    func selectDeviceAction(device: Device, adbManager: ADBManager, logBuffer: LogBuffer) -> () -> Void {
        {
            guard device.id != adbManager.selectedDevice?.id else { return }
            adbManager.stopLogcat()
            logBuffer.clear()
            adbManager.selectedDevice = device
            Task {
                try? await adbManager.startLogcat()
            }
        }
    }
    
    static func refreshDevices(_ adbManager: ADBManager) {
        Task {
            await adbManager.refreshDevices()
        }
    }
}

struct PackagePicker: View {
    @EnvironmentObject var adbManager: ADBManager
    @Binding var selectedPackage: String?

    var body: some View {
        Menu {
            Button(action: { selectedPackage = nil }) {
                HStack {
                    Text("All Packages")
                    if selectedPackage == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            if !adbManager.packages.isEmpty {
                Divider()

                ForEach(adbManager.packages, id: \.self) { package in
                    Button(action: { selectedPackage = package }) {
                        HStack {
                            Text(package)
                            if package == selectedPackage {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Refresh", action: { Self.refreshPackages(adbManager) })
        } label: {
            HStack {
                Image(systemName: "shippingbox")
                Text(selectedPackage ?? "All Packages")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }

    static func refreshPackages(_ adbManager: ADBManager) {
        Task {
            await adbManager.refreshPackages()
        }
    }
}

struct LevelFilterView: View {
    @Binding var selectedLevels: Set<LogLevel>
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(LogLevel.allCases.filter { $0 != .silent }, id: \.self) { level in
                LevelButton(
                    level: level,
                    isSelected: selectedLevels.contains(level),
                    action: toggleLevelAction(level: level)
                )
            }
        }
    }
    
    func toggleLevelAction(level: LogLevel) -> () -> Void {
        {
            if selectedLevels.contains(level) {
                selectedLevels.remove(level)
            } else {
                selectedLevels.insert(level)
            }
        }
    }
}

struct LevelButton: View {
    let level: LogLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(level.character)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 20, height: 20)
                .background(isSelected ? levelColor.opacity(0.3) : Color.clear)
                .foregroundStyle(levelColor)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(levelColor.opacity(isSelected ? 1 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("Toggle \(level) logs")
    }
    
    private var levelColor: Color {
        switch level {
        case .verbose: return .gray
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .fatal: return .purple
        case .silent: return .clear
        }
    }
}
