import SwiftUI
import ADBAssistant

struct LogListView: View {
    @EnvironmentObject var logBuffer: LogBuffer
    @State private var selectedEntry: LogEntry?
    @State private var expandedJSONEntries: Set<UUID> = []
    
    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedEntry) {
                ForEach(logBuffer.filteredEntries) { entry in
                    LogRowView(
                        entry: entry,
                        isExpanded: expandedJSONEntries.contains(entry.id),
                        onToggleJSON: {
                            toggleJSON(for: entry)
                        }
                    )
                    .id(entry.id)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .listRowSeparator(.hidden)
                    .background(entryBackground(for: entry))
                }
            }
            .listStyle(.plain)
            .overlay(alignment: .bottom) {
                if logBuffer.isPaused && logBuffer.newLogCount > 0 {
                    ResumeButton(count: logBuffer.newLogCount) {
                        logBuffer.resume()
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    private func toggleJSON(for entry: LogEntry) {
        if expandedJSONEntries.contains(entry.id) {
            expandedJSONEntries.remove(entry.id)
        } else {
            expandedJSONEntries.insert(entry.id)
        }
    }
    
    private func entryBackground(for entry: LogEntry) -> some View {
        if entry.id == selectedEntry?.id {
            return Color.accentColor.opacity(0.2)
        }
        switch entry.level {
        case .error, .fatal:
            return Color.red.opacity(0.05)
        case .warning:
            return Color.orange.opacity(0.05)
        default:
            return Color.clear
        }
    }
}

struct LogRowView: View {
    let entry: LogEntry
    let isExpanded: Bool
    let onToggleJSON: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Level indicator
                LevelIndicator(level: entry.level)
                
                // Timestamp
                Text(formattedTime(entry.timestamp))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                // Tag
                Text(entry.tag)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(tagColor(for: entry.tag))
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)
                
                // Message
                HStack(spacing: 4) {
                    if entry.containsJSON {
                        Button(action: onToggleJSON) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(entry.message)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(isExpanded ? nil : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 2)
            
            // Expanded JSON view
            if isExpanded, let json = JSONDetector.extractJSON(from: entry.message) {
                JSONView(jsonString: json)
                    .padding(.leading, 200)
                    .padding(.bottom, 4)
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func tagColor(for tag: String) -> Color {
        // Generate consistent color based on tag hash
        var hash = 0
        for char in tag.unicodeScalars {
            hash = Int(char.value) + ((hash << 5) - hash)
        }
        
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}

struct LevelIndicator: View {
    let level: LogLevel
    
    var body: some View {
        Text(level.character)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .frame(width: 16, height: 16)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(3)
    }
    
    private var backgroundColor: Color {
        switch level {
        case .verbose: return Color.gray.opacity(0.2)
        case .debug: return Color.blue.opacity(0.2)
        case .info: return Color.green.opacity(0.2)
        case .warning: return Color.orange.opacity(0.3)
        case .error: return Color.red.opacity(0.3)
        case .fatal: return Color.purple.opacity(0.4)
        case .silent: return Color.clear
        }
    }
    
    private var foregroundColor: Color {
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

struct JSONView: View {
    let jsonString: String
    
    var body: some View {
        if let prettyJSON = JSONDetector.prettyPrintJSON(jsonString) {
            Text(prettyJSON)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        } else {
            Text(jsonString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct ResumeButton: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("\(count) new logs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(16)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}
