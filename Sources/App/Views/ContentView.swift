import SwiftUI
import ADBAssistant

struct ContentView: View {
    @EnvironmentObject var adbManager: ADBManager
    @EnvironmentObject var logBuffer: LogBuffer
    
    @State private var searchText: String = ""
    @State private var selectedLevels: Set<LogLevel> = [.debug, .info, .warning, .error]
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView(
                searchText: $searchText,
                selectedLevels: $selectedLevels,
                isSearching: $isSearching
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Log list
            LogListView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Status bar
            StatusBarView()
                .padding(.horizontal)
                .padding(.vertical, 6)
        }
        .onAppear(perform: handleInitialAppear)
        .onReceive(adbManager.logStream, perform: handleLogStream)
        .onChange(of: searchText, perform: handleSearchTextChange)
        .onChange(of: selectedLevels, perform: handleSelectedLevelsChange)
        .onAppear(perform: handleKeyboardShortcutsAppear)
    }
    
    func handleInitialAppear() {
        setupLogStream()
        Task {
            await adbManager.refreshDevices()
        }
    }
    
    func handleLogStream(_ entries: [LogEntry]) {
        logBuffer.append(entries)
    }
    
    func handleSearchTextChange(_: String) {
        updateFilter()
    }
    
    func handleSelectedLevelsChange(_: Set<LogLevel>) {
        updateFilter()
    }
    
    func handleKeyboardShortcutsAppear() {
        setupKeyboardShortcuts()
    }
    
    private func setupLogStream() {
        // Subscribe to log stream from ADB manager
        // This would be set up when a device is selected
    }
    
    private func setupKeyboardShortcuts() {
        // Keyboard shortcuts are handled by the menu commands in ADBAssistantApp
    }
    
    static func buildFilter(searchText: String, selectedLevels: Set<LogLevel>) -> LogFilter {
        var filter = LogFilter(levels: selectedLevels)
        if !searchText.isEmpty {
            filter.searchQuery = searchText
        }
        return filter
    }
    
    func updateFilter() {
        logBuffer.setFilter(Self.buildFilter(searchText: searchText, selectedLevels: selectedLevels))
    }
}

#if DEBUG && !SKIP_PREVIEWS
#Preview {
    ContentView()
        .environmentObject(ADBManager())
        .environmentObject(LogBuffer())
}
#endif
