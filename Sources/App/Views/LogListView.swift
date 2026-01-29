import SwiftUI
import ADBAssistant

struct LogListView: View {
    @EnvironmentObject private var logBuffer: LogBuffer
    @StateObject private var viewModel = LogListViewModel()
    
    var body: some View {
        LogListContent(
            viewModel: viewModel,
            onResume: {
                logBuffer.resume()
            }
        )
        .onAppear {
            viewModel.bind(to: logBuffer)
        }
    }
}

struct LogListContent: View {
    @ObservedObject var viewModel: LogListViewModel
    let onResume: () -> Void
    @State private var selectedEntry: LogEntry?
    @State private var expandedJSONEntries: Set<UUID> = []
    @State private var isAutoScrollEnabled = true
    @State private var hasUserScrolled = false
    @State private var autoScrollTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Auto-scroll toggle
                HStack {
                    Toggle("Auto-scroll", isOn: $isAutoScrollEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: isAutoScrollEnabled) { newValue in
                            handleAutoScrollToggle(newValue, scrollTo: { id in
                                proxy.scrollTo(id, anchor: .bottom)
                            })
                        }

                    Spacer()

                    if viewModel.isPaused {
                        Button("Resume", action: handleResume)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05))

                // Log list
                List(selection: $selectedEntry) {
                    ForEach(viewModel.entries) { entry in
                        LogRowView(
                            entry: entry,
                            isExpanded: expandedJSONEntries.contains(entry.id),
                            onToggleJSON: toggleJSON
                        )
                        .id(entry.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                        .background(Self.entryBackground(for: entry, selectedEntryID: selectedEntry?.id))
                    }
                }
                .listStyle(.plain)
                .onChange(of: viewModel.entries.last?.id) { _ in
                    handleEntriesChanged(scrollTo: { id in
                        proxy.scrollTo(id, anchor: .bottom)
                    })
                }
                .onAppear {
                    handleInitialScroll(scrollTo: { id in
                        proxy.scrollTo(id, anchor: .bottom)
                    })
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        handleDragChanged()
                    }
                )
            }
            .overlay(alignment: .bottom) {
                if viewModel.isPaused && viewModel.newLogCount > 0 {
                    ResumeButton(count: viewModel.newLogCount, action: handleResume)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    func toggleJSON(for entryID: UUID) {
        if expandedJSONEntries.contains(entryID) {
            expandedJSONEntries.remove(entryID)
        } else {
            expandedJSONEntries.insert(entryID)
        }
    }
    
    func handleAutoScrollToggle(_ newValue: Bool, scrollTo: @escaping (UUID) -> Void) {
        guard newValue else { return }
        hasUserScrolled = false
        if let lastEntry = viewModel.entries.last {
            withAnimation {
                scrollTo(lastEntry.id)
            }
        }
    }
    
    func handleEntriesChanged(scrollTo: @escaping (UUID) -> Void) {
        // Auto-scroll to bottom when new entries arrive (if enabled)
        // Use async to not block the UI update
        if isAutoScrollEnabled && !hasUserScrolled && !viewModel.isPaused {
            autoScrollTask?.cancel()
            autoScrollTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms delay for UI to settle
                guard !Task.isCancelled else { return }
                if let lastEntry = viewModel.entries.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        scrollTo(lastEntry.id)
                    }
                }
            }
        }
    }
    
    func handleInitialScroll(scrollTo: @escaping (UUID) -> Void) {
        // Scroll to bottom on initial load
        if let lastEntry = viewModel.entries.last {
            scrollTo(lastEntry.id)
        }
    }
    
    func handleResume() {
        onResume()
        isAutoScrollEnabled = true
        hasUserScrolled = false
    }
    
    func handleDragChanged() {
        // Detect user scrolling to disable auto-scroll
        if isAutoScrollEnabled {
            hasUserScrolled = true
            isAutoScrollEnabled = false
        }
    }
    
    static func entryBackground(for entry: LogEntry, selectedEntryID: UUID?) -> Color {
        if entry.id == selectedEntryID {
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

struct LogRowView: View, Equatable {
    let entry: LogEntry
    let isExpanded: Bool
    let onToggleJSON: (UUID) -> Void
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private static var tagColorCache: [String: Color] = [:]
    
    static func == (lhs: LogRowView, rhs: LogRowView) -> Bool {
        lhs.entry.id == rhs.entry.id && lhs.isExpanded == rhs.isExpanded
    }
    
    var toggleJSONAction: () -> Void {
        { onToggleJSON(entry.id) }
    }
    
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
                        Button(action: toggleJSONAction) {
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
        Self.timeFormatter.string(from: date)
    }
    
    private func tagColor(for tag: String) -> Color {
        if let cached = Self.tagColorCache[tag] {
            return cached
        }
        
        var hash = 0
        for char in tag.utf8 {
            hash = (hash &* 31) &+ Int(char)
        }
        
        let hue = Double(abs(hash) % 360) / 360.0
        let color = Color(hue: hue, saturation: 0.7, brightness: 0.8)
        Self.tagColorCache[tag] = color
        return color
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
