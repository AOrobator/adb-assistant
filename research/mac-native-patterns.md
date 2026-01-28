# Mac-Native App Design Patterns for Developer Tools

Research on what makes a Mac app feel truly native and professional, with focus on developer/pro tools.

---

## 1. Apple Human Interface Guidelines for Pro/Developer Apps

### Core Principles

**Flexibility & Power**
- Pro apps should provide **multiple ways to accomplish tasks**: menus, keyboard shortcuts, toolbars, contextual menus
- Support both mouse-driven and keyboard-centric workflows
- Allow extensive customization without sacrificing discoverability

**Information Density**
- Pro users tolerate (and prefer) denser UIs than consumer apps
- Use smaller control sizes (`.small`, `.mini` in SwiftUI)
- Provide inspector panels and sidebars for detailed information
- Multi-column layouts are expected (NavigationSplitView)

**Consistency with Platform Conventions**
- Use standard macOS patterns: sidebars on left, inspectors on right
- Respect system accent colors and dark/light mode
- Follow standard window behaviors (resizing, full-screen, tabs)
- Menu bar integration is mandatory for Mac apps

### Window Design

**Multi-Window Architecture**
```swift
// macOS apps should support multiple windows
WindowGroup {
    ContentView()
}
.commands {
    // Add standard command groups
    CommandGroup(after: .newItem) { /* custom commands */ }
}
```

**Standard Layouts**
- **Three-column**: Sidebar → List → Detail (like Xcode, Finder)
- **Two-column**: Sidebar → Content (like Terminal preferences)
- **Single-window with tabs**: Like Safari, Terminal

**Toolbar Patterns**
```swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        Button(action: run) { Label("Run", systemImage: "play.fill") }
    }
    ToolbarItemGroup(placement: .navigation) {
        Button(action: back) { Label("Back", systemImage: "chevron.left") }
    }
}
```

### Visual Design

**Typography**
- Use SF Mono for code/logs (monospaced)
- SF Pro for UI elements
- System fonts respect user accessibility settings

**Colors**
- Semantic colors: `.primary`, `.secondary`, `.accentColor`
- Adaptive colors that work in light/dark mode
- Translucent sidebars (`.listStyle(.sidebar)`)

**Vibrancy & Materials**
- Use `.background(.ultraThinMaterial)` for overlays
- Sidebar translucency indicates window focus state

---

## 2. Terminal, Console.app, and Xcode Log Patterns

### Terminal.app

**Character Grid Architecture**
- Uses a virtual terminal emulator with character-cell grid
- Buffer-based: maintains scrollback buffer separate from visible area
- Supports ANSI escape codes for colors and formatting

**Performance Techniques**
- Only renders visible lines
- Uses Core Text for efficient text rendering
- Batches output updates to prevent UI thrashing
- Scrollback buffer can be millions of lines

**Key Behaviors**
- Scroll to bottom on new output (unless user scrolled up)
- "Scroll to bottom" button appears when viewing history
- Selection persists across scroll operations
- Copy preserves ANSI formatting optionally

### Console.app

**Streaming Log Architecture**
- Uses Unified Logging System (os_log)
- Virtual list: only materializes visible rows
- Filtering happens at query level, not view level
- Supports live streaming with pause capability

**UI Patterns**
- Timestamp column with relative/absolute toggle
- Process/subsystem filtering in sidebar
- Search with scope (visible, all, time range)
- Color-coding by log level (error=red, warning=yellow)
- Monospaced font for log content

**Performance**
- Lazy loading with estimated row heights
- Background thread for log parsing
- Debounced search input
- Virtual scrolling (only renders ~visible + buffer rows)

### Xcode Debug Console

**Mixed Content Handling**
- Interleaves stdout, stderr, and debugger output
- Different styling for each source
- Collapsible sections for repeated output
- Inline variable inspection

**Streaming Behavior**
- Auto-scrolls during active debugging
- Pauses auto-scroll when user interacts
- "Jump to bottom" indicator
- Preserves scroll position on app state changes

---

## 3. SwiftUI Patterns for High-Performance List/Text Views

### List vs LazyVStack vs ScrollView + ForEach

| Pattern | Use Case | Performance |
|---------|----------|-------------|
| `List` | Standard lists with selection, swipe actions | Good, lazy by default |
| `LazyVStack` + `ScrollView` | Custom styling, no List chrome | Good, requires manual ID |
| `Table` | Multi-column data (macOS) | Excellent for tabular data |
| `ForEach` in `VStack` | Small, static collections | Poor for large datasets |

### Optimizing for Large Datasets

**Use Identifiable + Stable IDs**
```swift
struct LogEntry: Identifiable {
    let id: UUID  // Stable ID for diffing
    let timestamp: Date
    let message: String
    let level: LogLevel
}
```

**Lazy Loading with LazyVStack**
```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: 2) {
        ForEach(logEntries) { entry in
            LogEntryRow(entry: entry)
                .id(entry.id)  // Critical for performance
        }
    }
}
```

**Table for Tabular Log Data (macOS)**
```swift
Table(logEntries, selection: $selection, sortOrder: $sortOrder) {
    TableColumn("Time", value: \.timestamp) { entry in
        Text(entry.timestamp, style: .time)
            .font(.system(.caption, design: .monospaced))
    }
    .width(min: 60, max: 100)
    
    TableColumn("Level", value: \.level.rawValue) { entry in
        LogLevelBadge(level: entry.level)
    }
    .width(60)
    
    TableColumn("Message", value: \.message)
}
```

### Scroll Position Management

**Auto-scroll to Bottom (Chat/Log Pattern)**
```swift
@State private var scrollPosition = ScrollPosition(edge: .bottom)
@State private var userScrolledUp = false

ScrollView {
    LazyVStack { /* content */ }
}
.scrollPosition($scrollPosition)
.defaultScrollAnchor(.bottom)  // Start at bottom
.onChange(of: logEntries.count) { 
    if !userScrolledUp {
        scrollPosition.scrollTo(edge: .bottom)
    }
}
```

**Programmatic Scrolling (iOS 18+)**
```swift
// Scroll to specific item
scrollPosition.scrollTo(id: entry.id)

// Scroll to edge
scrollPosition.scrollTo(edge: .bottom)

// Scroll to coordinate
scrollPosition.scrollTo(x: 0, y: 500)
```

**Legacy ScrollViewReader Pattern**
```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack {
            ForEach(entries) { entry in
                LogRow(entry: entry)
                    .id(entry.id)
            }
        }
    }
    .onChange(of: entries.count) {
        withAnimation {
            proxy.scrollTo(entries.last?.id, anchor: .bottom)
        }
    }
}
```

### Text Rendering for Logs

**Attributed Strings for Syntax Highlighting**
```swift
struct LogMessageView: View {
    let message: String
    
    var body: some View {
        Text(attributedMessage)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
    }
    
    var attributedMessage: AttributedString {
        var result = AttributedString(message)
        // Apply highlighting rules
        // Timestamps, log levels, error keywords, etc.
        return result
    }
}
```

**Selection Support**
```swift
Text(logContent)
    .textSelection(.enabled)  // Allow copy/paste
    .font(.system(.body, design: .monospaced))
```

### Performance Tips

1. **Avoid expensive operations in view body**
   - Pre-compute attributed strings
   - Cache formatted timestamps
   
2. **Use `@StateObject` for data models**
   ```swift
   @StateObject private var logStore = LogStore()
   ```

3. **Debounce rapid updates**
   ```swift
   logStore.$entries
       .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
       .sink { /* update UI */ }
   ```

4. **Background thread parsing**
   ```swift
   Task.detached(priority: .userInitiated) {
       let parsed = parseLogEntries(rawData)
       await MainActor.run {
           self.entries = parsed
       }
   }
   ```

---

## 4. Keyboard Shortcuts and Power-User Patterns

### Standard macOS Shortcuts

**Universal Shortcuts (Must Support)**
| Shortcut | Action |
|----------|--------|
| ⌘C/⌘V/⌘X | Copy/Paste/Cut |
| ⌘Z/⇧⌘Z | Undo/Redo |
| ⌘A | Select All |
| ⌘F | Find |
| ⌘G/⇧⌘G | Find Next/Previous |
| ⌘W | Close Window/Tab |
| ⌘Q | Quit |
| ⌘, | Preferences |
| ⌘N | New |
| ⌘O | Open |
| ⌘S | Save |

**Developer Tool Conventions**
| Shortcut | Action (Convention) |
|----------|---------------------|
| ⌘R | Run/Refresh |
| ⌘B | Build |
| ⌘K | Clear console/output |
| ⌘L | Go to line |
| ⌘/ | Toggle comment |
| ⌘[ / ⌘] | Indent/Outdent |
| ⌘↵ | Execute/Submit |
| ⌘1-9 | Navigate to pane/tab |
| ⌃Tab | Next tab |
| ⇧⌃Tab | Previous tab |

### SwiftUI Keyboard Shortcut Implementation

**Basic Shortcuts**
```swift
Button("Run") { executeCommand() }
    .keyboardShortcut("r", modifiers: .command)

Button("Clear") { clearOutput() }
    .keyboardShortcut("k", modifiers: .command)
```

**Semantic Shortcuts**
```swift
// Default action (Return key)
Button("Execute") { execute() }
    .keyboardShortcut(.defaultAction)

// Cancel action (Escape key)
Button("Cancel") { cancel() }
    .keyboardShortcut(.cancelAction)
```

**Complex Modifier Combinations**
```swift
Button("Debug") { startDebug() }
    .keyboardShortcut("d", modifiers: [.command, .shift])
```

### Menu Bar Commands

```swift
@main
struct ADBAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // Standard Edit menu additions
            CommandGroup(after: .textEditing) {
                Button("Clear Output") { clearOutput() }
                    .keyboardShortcut("k", modifiers: .command)
            }
            
            // Custom menu
            CommandMenu("Device") {
                Button("Connect...") { showConnect() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Restart ADB") { restartADB() }
            }
        }
    }
}
```

### Focus Management

**Focusable Views**
```swift
@FocusState private var isInputFocused: Bool

TextField("Command", text: $command)
    .focused($isInputFocused)
    .onSubmit { executeCommand() }

// Programmatically focus
Button("New Command") {
    isInputFocused = true
}
```

**Global Keyboard Handlers**
```swift
.onKeyPress(.return, modifiers: .command) {
    executeCommand()
    return .handled
}

.onKeyPress(characters: .alphanumerics) { press in
    if press.modifiers.contains(.command) {
        return .ignored  // Let system handle
    }
    // Handle typing
    return .handled
}
```

---

## 5. Well-Designed Native Mac Developer Utilities

### Exemplary Apps to Study

**1. Dash (Documentation Browser)**
- Instant search with keyboard navigation
- Sidebar with collapsible categories
- Docset management
- Global hotkey to show/hide
- Snippet management with expansion

**2. Proxyman (HTTP Debugging)**
- Three-column layout (sources → requests → details)
- Real-time streaming with filters
- Syntax highlighting for JSON/XML
- Keyboard-driven navigation
- Breakpoint/modify request capability

**3. Tower (Git Client)**
- Sidebar for repositories
- Multi-pane detail views
- Drag-and-drop branch management
- Inline diff viewing
- Keyboard shortcuts for common actions

**4. TablePlus (Database Client)**
- Tab-based interface for connections
- Inline editing in table views
- SQL editor with autocomplete
- Structure/data/query mode tabs
- Dark/light theme support

**5. Paw/RapidAPI (API Testing)**
- Request builder with tabs
- Environment variable management
- Code generation
- Response visualization

**6. iTerm2 (Terminal Emulator)**
- Split panes
- Search with highlighting
- Triggers and automation
- Profile management
- Hotkey window

### Common Patterns in These Apps

**Navigation**
- Sidebar with sections/groups
- Tab bar for open items
- Breadcrumb navigation
- Quick switcher (⌘P / ⌘T style)

**Content Display**
- Master-detail layout
- Inspectors for properties
- Tabbed detail views
- Contextual toolbars

**Data Management**
- Search/filter always visible
- Sort by clicking column headers
- Selection with keyboard navigation
- Drag-and-drop support

**Status & Feedback**
- Status bar at bottom
- Activity indicators for background tasks
- Non-modal notifications
- Badge indicators

---

## 6. Implementation Checklist for Native Feel

### Essential Features

- [ ] Menu bar with standard items (File, Edit, View, Window, Help)
- [ ] Keyboard shortcuts for all common actions
- [ ] Dark mode support
- [ ] Respect system accent color
- [ ] Window resizing and state restoration
- [ ] Full-screen support
- [ ] Touch Bar support (if applicable)
- [ ] Standard text editing behaviors (undo, redo, select all)

### Pro/Developer App Features

- [ ] Customizable toolbar
- [ ] Sidebar with collapsible sections
- [ ] Inspector panel (toggle-able)
- [ ] Search with filters/scopes
- [ ] Status bar with activity info
- [ ] Tab support for multiple documents
- [ ] Split view support
- [ ] Quick switcher (⌘P style)

### Performance Requirements

- [ ] < 100ms response for UI interactions
- [ ] Lazy loading for large datasets
- [ ] Background processing for heavy operations
- [ ] Smooth scrolling (60fps)
- [ ] Responsive during data loading

### Accessibility

- [ ] VoiceOver support
- [ ] Keyboard navigation for all features
- [ ] Sufficient color contrast
- [ ] Respect reduced motion settings
- [ ] Dynamic Type support

---

## 7. Code Patterns for ADB Assistant

### Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Toolbar                                 │
│  [Device: Pixel 6] [Connect] [▶ Run] [⏹ Stop] [🔍 Search]   │
├──────────────┬──────────────────────────────────────────────┤
│              │                                               │
│   Sidebar    │              Main Content                     │
│              │                                               │
│  ▼ Devices   │  ┌──────────────────────────────────────┐    │
│    Pixel 6   │  │                                      │    │
│    Emulator  │  │         Log/Output View              │    │
│              │  │      (LazyVStack + ScrollView)       │    │
│  ▼ History   │  │                                      │    │
│    adb shell │  │                                      │    │
│    adb logc  │  │                                      │    │
│              │  └──────────────────────────────────────┘    │
│  ▼ Saved     │  ┌──────────────────────────────────────┐    │
│    cmd1      │  │  Command Input                       │    │
│    cmd2      │  │  [$ adb shell                    ⏎]  │    │
│              │  └──────────────────────────────────────┘    │
├──────────────┴──────────────────────────────────────────────┤
│  Status: Connected to Pixel 6 │ Lines: 1,234 │ Filter: All  │
└─────────────────────────────────────────────────────────────┘
```

### Key SwiftUI Components

```swift
struct ContentView: View {
    @StateObject private var adbManager = ADBManager()
    @State private var selectedDevice: Device?
    
    var body: some View {
        NavigationSplitView {
            Sidebar(
                devices: adbManager.devices,
                selection: $selectedDevice
            )
            .listStyle(.sidebar)
        } detail: {
            if let device = selectedDevice {
                DeviceDetailView(device: device)
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $searchText)
        .toolbar { /* toolbar items */ }
        .commands { /* menu commands */ }
    }
}
```

---

## Sources

- Apple Human Interface Guidelines (developer.apple.com)
- Hacking with Swift - SwiftUI tutorials
- Analysis of Terminal.app, Console.app, Xcode behaviors
- Study of popular Mac developer tools (Dash, Proxyman, Tower, TablePlus, iTerm2)
