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
        .onAppear {
            setupLogStream()
            Task {
                await adbManager.refreshDevices()
            }
        }
        .onChange(of: searchText) { _ in
            updateFilter()
        }
        .onChange(of: selectedLevels) { _ in
            updateFilter()
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }
    
    private func setupLogStream() {
        // Subscribe to log stream from ADB manager
        // This would be set up when a device is selected
    }
    
    private func setupKeyboardShortcuts() {
        // Keyboard shortcuts are handled by the menu commands in ADBAssistantApp
    }
    
    private func updateFilter() {
        let minLevel = selectedLevels.min() ?? .verbose
        let maxLevel = selectedLevels.max() ?? .fatal
        
        var filter = LogFilter(
            minLevel: minLevel,
            maxLevel: maxLevel
        )
        
        if !searchText.isEmpty {
            filter.searchQuery = searchText
        }
        
        logBuffer.setFilter(filter)
    }
}

#Preview {
    ContentView()
        .environmentObject(ADBManager())
        .environmentObject(LogBuffer())
}
