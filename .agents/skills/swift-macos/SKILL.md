---
name: swift-macos
description: Trigger when writing Swift code for macOS, SwiftUI views, or using XcodeGen.
---

# Swift + macOS Patterns

## Project Structure

```
adb-assistant/
├── project.yml          # XcodeGen config
├── Sources/
│   └── App/
│       └── adb-assistant.swift
├── Resources/
│   └── Assets.xcassets
└── build.sh
```

## SwiftUI Basics

```swift
import SwiftUI

struct LogViewer: View {
    @State private var logs: [LogEntry] = []
    @State private var isPaused = false
    
    var body: some View {
        List(logs) { entry in
            LogRow(entry: entry)
        }
        .overlay(alignment: .bottom) {
            if isPaused {
                ResumeButton(onResume: { isPaused = false })
            }
        }
    }
}
```

## Keyboard Shortcuts

```swift
struct LogViewer: View {
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        List(...)
            .focusable()
            .onKeyPress(.command, .k) {
                // Clear logs
            }
            .onKeyPress(.command, .g) {
                // Next match
            }
    }
}
```

## Process Control

```swift
import Foundation

class ADBManager: ObservableObject {
    @Published var isRunning = false
    private var process: Process?
    private var outputPipe: Pipe?
    
    func startLogcat() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/adb")
        process.arguments = ["shell", "logcat", "-d"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
        
        try? process.run()
        self.process = process
    }
    
    func stop() {
        process?.terminate()
    }
}
```

## XcodeGen project.yml

```yaml
name: adb-assistant
options:
  bundleIdPrefix: com.aorobator
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"

targets:
  adb-assistant:
    type: application
    platform: macOS
    sources:
      - path: Sources
    resources:
      - path: Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.aorobator.adb-assistant
        INFOPLIST_FILE: Resources/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

## App Lifecycle

```swift
@main
struct ADBAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ADB Assistant") { ... }
            }
        }
    }
}
```

## Common Patterns

- Use `@StateObject` for model classes
- Use `@Published` for observable objects
- Put long-running work in `Task { @MainActor in }`
- Use `Process` for subprocess execution
- Handle `Pipe` for streaming output
