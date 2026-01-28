# ADB Assistant - Product Spec

> **A native macOS logcat viewer that doesn't suck.**  
> Version: 1.0 (MVP focused on logcat usability)  
> Last updated: January 28, 2026

---

## Vision

Replace Android Studio's logcat for 90% of debugging workflows. Fast, focused, native. You open it, pick your app, and read logs that are actually readable.

**One sentence:** Pidcat with a GUI, native on Mac, with the UX polish of Dash or Proxyman.

---

## Core Principles

1. **Package-first, not PID-first** — Solve the PID tracking problem pidcat solved
2. **Signal over noise** — Smart defaults that filter out system spam
3. **Scannable** — Visual patterns > reading every line
4. **Keyboard-driven** — Everything accessible without touching the mouse
5. **Reliable** — Never silently fail, never lose logs, never crash
6. **Fast** — Instant response, even at high log volume

---

## User Stories

### Primary User
Android developer who wants to debug their app without opening Android Studio.

### Key Workflows

**W1: Quick Debug Session**
> "My app crashed. I want to see what happened."
1. Open ADB Assistant
2. Device auto-detected, app auto-selected (last used or foreground)
3. See colored logs filtered to my package
4. Crash stack trace is visible, clickable

**W2: Hunting a Bug**
> "Something's wrong but I don't know where. I need to search."
1. Logs streaming for my app
2. Type search term, see highlighted matches instantly
3. Jump between matches with keyboard (F3/Shift+F3)
4. Find the problem

**W3: Reading JSON Responses**
> "My API returned something weird. Let me see the response."
1. Spot a log line with JSON
2. Click or keyboard shortcut to expand
3. See pretty-printed, syntax-highlighted JSON
4. Actually read it without going to an external tool

**W4: Sharing Logs**
> "Hey teammate, look at this weird behavior."
1. Select relevant log lines
2. Copy or export
3. Paste in Slack with formatting preserved

---

## Information Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  🔲 ADB Assistant                               − □ ×              │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 📱 Pixel 7 Pro  ▼ │ 📦 com.reddit.frontpage  ▼ │ ▶ ⏸ 🗑️    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 🔍 Search...                    │ V D I W E │ Regex ☐ │   │
│  └─────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  15:42:01.234  D  OkHttp       ← GET /api/feed                     │
│  15:42:01.456  D  OkHttp       → 200 OK (234ms)                    │
│  15:42:01.567  I  FeedRepo     Loaded 25 items                     │
│  15:42:01.678  W  ImageLoader  Cache miss for avatar_123.jpg       │
│  15:42:01.789  E  CrashHandler ══════════════════════════════════  │
│                                 │ NullPointerException             │
│                                 │   at FeedAdapter.bind(line:45)   │
│                                 │   at RecyclerView.onBind(...)    │
│                                 ╰─────────────────────────────────  │
│                                                                     │
│                                                    [▼ 12 new logs] │
├─────────────────────────────────────────────────────────────────────┤
│  Lines: 1,234 │ Showing: 892 │ 3 errors │ Streaming ● │ 15:42:05   │
└─────────────────────────────────────────────────────────────────────┘
```

### Zones

| Zone | Purpose |
|------|---------|
| **Device/Package Bar** | Select what you're debugging |
| **Filter Bar** | Search + level toggles |
| **Log View** | The main event — virtualized, colored, scannable |
| **Status Bar** | Stats, connection status, timestamp |

---

## Feature Spec

### F1: Device & Package Selection

**Device Picker**
- Auto-detect connected devices via `adb devices`
- Show device name + model (not just serial)
- Indicator: 🟢 connected, 🟡 unauthorized, 🔴 offline
- Remember last selected device

**Package Picker**
- List installed debuggable packages
- Autocomplete as you type
- "Current foreground app" option
- Recently used packages at top
- Remember last selected package

**Auto-Selection Intelligence**
- If only one device, select it
- If only one debuggable package, select it
- If previously used combo available, restore it

### F2: Log Display

**Core Rendering**
- Virtualized list (only render visible + buffer)
- Monospace font (SF Mono)
- Fixed-width columns: Time | Level | Tag | Message
- Alternating row backgrounds (subtle)

**Column Layout**
```
│ 15:42:01.234 │ D │ OkHttp          │ ← GET /api/feed         │
│ Time         │Lvl│ Tag (truncate)  │ Message (flexible)      │
│ 12 chars     │ 1 │ 16 chars max    │ Rest of width           │
```

**Log Levels — Color Coding**

| Level | Gutter | Text | Background |
|-------|--------|------|------------|
| V | Gray | Gray | None |
| D | Blue | Default | None |
| I | Green | Default | None |
| W | Orange | Orange | Subtle yellow |
| E | Red | Red | Subtle red |
| F | Magenta | White | Red |

**Visual Enhancements**
- **Tag coloring**: Consistent color per tag (hash-based)
- **Time gaps**: Bold separator when gap > 1 second
- **Process markers**: `═══ PROCESS STARTED ═══` / `═══ PROCESS DIED ═══`
- **Stack traces**: Boxed/indented, collapsible

### F3: Streaming Behavior

**Live Tail Mode** (Default)
- Auto-scroll to bottom as new logs arrive
- Visual indicator: 🟢 "Live" in status bar

**Paused Mode** (Auto-triggered)
- User scrolls up → auto-pause
- Floating pill: "[▼ 47 new logs]" — click to resume
- Visual indicator: ⏸️ "Paused" in status bar

**Buffer Management**
- Circular buffer: 50,000 entries default
- Configurable in preferences (10k - 500k)
- Oldest entries dropped when full
- "Buffer wrapped" indicator when it happens

### F4: Filtering

**Level Filters** (Always Visible)
- Toggle buttons: `V` `D` `I` `W` `E`
- Multiple can be active
- Click = toggle single, Cmd+Click = solo
- Default: D I W E (Verbose off)

**Text Search**
- Single search field with instant results
- Highlights matches in yellow
- Match count: "23 matches"
- Navigate: F3 / Shift+F3 (or ⌘G / ⇧⌘G)
- Clear: Esc or ✕ button

**Tag Filter** (In search bar or separate)
- Type `tag:OkHttp` in search
- Or dropdown multi-select for tags
- Include + exclude (`-tag:Choreographer`)

**Search Options**
- Case sensitive toggle (default: off)
- Regex toggle (default: off)
- Scope: Visible / All Buffered

### F5: JSON Handling ⭐

**This is a key differentiator — JSON in logs is awful everywhere else.**

**Auto-Detection**
- Detect JSON in log messages (starts with `{` or `[`)
- Show collapse indicator: `▶ { ... }` 

**Inline Expansion**
- Click or ⌘+Enter to expand
- Pretty-printed with syntax highlighting
- Indented below the log line, same gutter color
- Collapse with click or Esc

**JSON Features**
- Syntax highlighting (keys, strings, numbers, booleans)
- Copy formatted JSON (right-click or ⌘C when expanded)
- Handle escaped JSON (double-encoded) — auto-unescape

**Example**
```
│ 15:42:01.456 │ D │ API     │ ▶ Response: {"user":{"id":123,"name... │
                              ╰─────────────────────────────────────────
                                {
                                  "user": {
                                    "id": 123,
                                    "name": "Andrew",
                                    "email": "a@example.com"
                                  },
                                  "token": "abc..."
                                }
                              ─────────────────────────────────────────╯
```

### F6: Keyboard Navigation

**Essential Shortcuts**

| Shortcut | Action |
|----------|--------|
| ⌘K | Clear log view |
| ⌘F | Focus search field |
| ⌘G / F3 | Next match |
| ⇧⌘G / ⇧F3 | Previous match |
| Esc | Clear search / collapse JSON / exit mode |
| ⌘↓ | Jump to bottom (resume live) |
| ⌘↑ | Jump to top |
| Space | Page down |
| ⇧Space | Page up |
| ⌘C | Copy selected lines |
| ⌘A | Select all visible (filtered) |
| ⌘E | Export selection |
| ⌘, | Preferences |
| ⌘1-5 | Toggle log levels (V/D/I/W/E) |
| ⌘R | Reconnect to device |
| ⌘L | Focus package picker |
| ⌘D | Focus device picker |

**Navigation**
- Arrow keys: move selection
- Enter: expand/collapse current line (if JSON/stacktrace)
- [ / ] : Jump to previous/next error

### F7: Selection & Copy

**Line Selection**
- Click to select single line
- Shift+Click for range
- Cmd+Click for multi-select
- Drag to select range

**Copy Behavior**
- ⌘C copies selected lines
- Format options in preferences:
  - Plain text (default)
  - With ANSI colors
  - Markdown (for pasting in GitHub/Slack)
  - JSON (structured export)

**Right-Click Context Menu**
- Copy
- Copy as Markdown
- Filter to this tag
- Exclude this tag
- Google this error
- Copy stack trace

### F8: Status Bar

**Left Section**
- Total lines in buffer
- Filtered lines visible
- Error count (clickable → jump to first error)

**Center Section**
- Connection status: 🟢 Streaming / ⏸️ Paused / 🔴 Disconnected
- Reconnect button when disconnected

**Right Section**
- Current timestamp
- FPS indicator (debug mode only)

---

## Non-Goals (v1)

- Multiple device support (tabs) — v2
- Wireless ADB pairing — v2
- Scrcpy integration — v2
- APK installation — v2
- Shell command execution — v2
- Log persistence/sessions — v2
- Crash reporting integration — v2
- Team sharing features — v2

---

## Technical Architecture

### Stack
- **Language**: Swift
- **UI**: SwiftUI (macOS 13+)
- **Log parsing**: Background thread with batched updates
- **ADB communication**: Process spawning (`adb logcat -v threadtime`)
- **Buffer**: Circular buffer with configurable size

### Performance Requirements
- Handle 10,000 logs/second without dropping frames
- < 50ms latency from log emission to display
- Smooth 60fps scrolling with 100k+ buffered entries
- < 100MB memory for 50k log entries

### Data Flow
```
ADB Process → Background Parser → Circular Buffer → Main Thread (debounced) → SwiftUI View
     ↓              ↓                    ↓                    ↓
  Raw text    Structured LogEntry    Ring buffer        Virtual list
                                    (50k default)      (visible only)
```

### Key Components

```swift
// Core data model
struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let tag: String
    let pid: Int
    let tid: Int
    let message: String
    let isJSON: Bool
    let rawLine: String
}

// Buffer manager
class LogBuffer: ObservableObject {
    @Published var entries: [LogEntry]
    let maxSize: Int
    
    func append(_ entry: LogEntry)
    func clear()
    func filter(predicate: (LogEntry) -> Bool) -> [LogEntry]
}

// ADB connection manager
class ADBManager: ObservableObject {
    @Published var devices: [Device]
    @Published var isConnected: Bool
    
    func startLogcat(device: Device, package: String) -> AsyncStream<LogEntry>
    func stopLogcat()
}
```

---

## Design Language

### Typography
- **Log content**: SF Mono, 12pt (configurable 10-16)
- **UI elements**: SF Pro
- **Tags**: SF Mono, slightly smaller

### Spacing
- Row height: 20px (compact) / 24px (comfortable)
- Gutter width: 8px (for level indicator)
- Column padding: 8px

### Colors
Follow system dark/light mode. Error red, warning orange, etc. should meet WCAG contrast requirements in both modes.

### Window
- Default size: 900 x 600
- Minimum: 600 x 400
- Remember size/position
- Support full-screen

---

## Success Metrics

1. **Daily active usage** — Do developers keep it open?
2. **Session length** — Are they debugging with it?
3. **Feature usage** — JSON expansion, search, level filters
4. **Performance** — No dropped frames at high volume
5. **Reliability** — Zero crashes, zero silent failures

---

## Open Questions

1. **Timestamp format**: Relative ("2s ago") vs absolute (15:42:01)? Toggle?
2. **Tag truncation**: Hard limit (16 chars) or flexible with tooltip?
3. **Multi-line messages**: Expand inline or tooltip/modal?
4. **Search scope**: Default to visible or all buffered?
5. **Buffer full behavior**: Drop oldest (FIFO) or pause and warn?

---

## Appendix: Research Sources

Research conducted by parallel agents (Claude Opus + Codex):
- `/research/existing-tools.md` — Android Studio, pidcat, MatLog, LogNote analysis
- `/research/log-viewer-ux.md` — Patterns from Datadog, Splunk, Grafana, Papertrail
- `/research/mac-native-patterns.md` — Apple HIG, Console.app, SwiftUI patterns

Key insights synthesized:
- **pidcat's core insight**: Filter by package, not PID
- **Biggest pain point**: JSON is unreadable in all existing tools
- **Console.app pattern**: Pause on scroll, floating resume button
- **Pro app UX**: Keyboard-driven, information-dense, customizable

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-28 | 0.1 | Initial spec |
