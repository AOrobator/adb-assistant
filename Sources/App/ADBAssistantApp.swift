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
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ADB Assistant") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "ADB Assistant",
                            .applicationVersion: "1.0",
                            .credits: NSAttributedString(string: "A native macOS logcat viewer")
                        ]
                    )
                }
            }
            
            CommandMenu("Logs") {
                Button("Clear Logs") {
                    logBuffer.clear()
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Pause/Resume") {
                    if logBuffer.isPaused {
                        logBuffer.resume()
                    } else {
                        logBuffer.pause()
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
            }
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
