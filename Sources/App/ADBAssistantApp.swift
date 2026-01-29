import SwiftUI
import ADBAssistant

@main
struct ADBAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var adbManager = ADBManager()
    @StateObject private var logBuffer = LogBuffer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adbManager)
                .environmentObject(logBuffer)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ADB Assistant", action: showAboutPanel)
            }
            
            CommandMenu("Logs") {
                Button("Clear Logs", action: clearLogs)
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Pause/Resume", action: togglePauseResume)
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }
    
    func showAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: aboutPanelOptions())
    }
    
    func aboutPanelOptions() -> [NSApplication.AboutPanelOptionKey: Any] {
        [
            .applicationName: "ADB Assistant",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "A native macOS logcat viewer")
        ]
    }
    
    func clearLogs() {
        logBuffer.clear()
    }
    
    func togglePauseResume() {
        if logBuffer.isPaused {
            logBuffer.resume()
        } else {
            logBuffer.pause()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App launched
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
