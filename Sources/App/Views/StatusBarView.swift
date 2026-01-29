import SwiftUI
import ADBAssistant

struct StatusBarView: View {
    @EnvironmentObject var adbManager: ADBManager
    @EnvironmentObject var logBuffer: LogBuffer
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        HStack {
            // Left: Stats
            HStack(spacing: 16) {
                Text("Lines: \(logBuffer.totalCount)")
                Text("Showing: \(logBuffer.filteredEntries.count)")
                
                let errorCount = logBuffer.entries.filter { $0.level == .error || $0.level == .fatal }.count
                if errorCount > 0 {
                    Text("\(errorCount) errors")
                        .foregroundStyle(.red)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            
            Spacer()
            
            // Center: Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(Self.statusColor(isConnected: adbManager.isConnected, isPaused: logBuffer.isPaused))
                    .frame(width: 8, height: 8)
                
                Text(Self.statusText(
                    isConnected: adbManager.isConnected,
                    isPaused: logBuffer.isPaused,
                    hasDevice: adbManager.selectedDevice != nil
                ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Right: Timestamp
            Text(Self.formattedTime(Date()))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    static func statusColor(isConnected: Bool, isPaused: Bool) -> Color {
        if !isConnected {
            return .red
        }
        if isPaused {
            return .orange
        }
        return .green
    }
    
    static func statusText(isConnected: Bool, isPaused: Bool, hasDevice: Bool) -> String {
        if !isConnected {
            return hasDevice ? "Disconnected" : "No device"
        }
        if isPaused {
            return "Paused"
        }
        return "Streaming"
    }
    
    static func formattedTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
