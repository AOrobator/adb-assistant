import SwiftUI
import ADBAssistant

struct ToolbarView: View {
    @EnvironmentObject var adbManager: ADBManager
    @Binding var searchText: String
    @Binding var selectedLevels: Set<LogLevel>
    @Binding var isSearching: Bool
    @FocusState var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Device picker
            DevicePicker()
            
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
                    Button(action: { searchText = "" }) {
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
            Button(action: { adbManager.stopLogcat() }) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
            .disabled(!adbManager.isConnected)
            
            Button(action: {
                Task {
                    try? await adbManager.startLogcat()
                }
            }) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .disabled(adbManager.isConnected || adbManager.selectedDevice == nil)
            
            Button(action: {
                Task {
                    try? await adbManager.clearLogs()
                }
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct DevicePicker: View {
    @EnvironmentObject var adbManager: ADBManager
    
    var body: some View {
        Menu {
            ForEach(adbManager.devices) { device in
                Button(action: {
                    adbManager.selectedDevice = device
                }) {
                    HStack {
                        Text(deviceDisplayName(device))
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
            
            Button("Refresh") {
                Task {
                    await adbManager.refreshDevices()
                }
            }
        } label: {
            HStack {
                Image(systemName: "iphone")
                Text(adbManager.selectedDevice.map { deviceDisplayName($0) } ?? "Select Device")
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
    
    private func deviceDisplayName(_ device: Device) -> String {
        if let model = device.model {
            return "\(model) (\(device.serial.prefix(8)))"
        }
        return device.serial
    }
}

struct LevelFilterView: View {
    @Binding var selectedLevels: Set<LogLevel>
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(LogLevel.allCases.filter { $0 != .silent }, id: \.self) { level in
                LevelButton(
                    level: level,
                    isSelected: selectedLevels.contains(level)
                ) {
                    if selectedLevels.contains(level) {
                        selectedLevels.remove(level)
                    } else {
                        selectedLevels.insert(level)
                    }
                }
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
