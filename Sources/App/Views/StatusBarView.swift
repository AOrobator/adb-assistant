import SwiftUI
import ADBAssistant

struct StatusBarView: View {
    @EnvironmentObject var adbManager: ADBManager
    @EnvironmentObject var logBuffer: LogBuffer
    
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
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Right: Timestamp
            Text(currentTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusColor: Color {
        if !adbManager.isConnected {
            return .red
        }
        if logBuffer.isPaused {
            return .orange
        }
        return .green
    }
    
    private var statusText: String {
        if !adbManager.isConnected {
            return adbManager.selectedDevice == nil ? "No device" : "Disconnected"
        }
        if logBuffer.isPaused {
            return "Paused"
        }
        return "Streaming"
    }
    
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
