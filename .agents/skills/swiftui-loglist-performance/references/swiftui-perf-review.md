# SwiftUI Performance Review: LogListView

**Date:** 2025-01-29  
**Reviewer:** Zed (Subagent)  
**File:** LogListView.swift

---

## Summary

Found **8 performance issues** ranging from Critical to Low severity. The most impactful problems are DateFormatter allocation in hot paths and unnecessary view re-renders from state management.

---

## Issues

### 🔴 CRITICAL: DateFormatter Created Every Render

**Location:** `LogRowView.formattedTime(_:)`

**Problem:**
```swift
private func formattedTime(_ date: Date) -> String {
    let formatter = DateFormatter()  // EXPENSIVE - created every call
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: date)
}
```

DateFormatter is one of the most expensive Foundation objects to create. This allocates a new instance **every time any row renders**, which happens during scrolling, selection changes, and any state update.

**Impact:** Severe frame drops during scrolling, especially with 100+ log entries.

**Fix:**
```swift
// Option 1: Static formatter (best)
private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
}()

private func formattedTime(_ date: Date) -> String {
    Self.timeFormatter.string(from: date)
}

// Option 2: Use ISO8601DateFormatter for even better performance
// Option 3: Cache formatted strings in LogEntry itself
```

---

### 🔴 CRITICAL: Hash Computed Every Render for Tag Colors

**Location:** `LogRowView.tagColor(for:)`

**Problem:**
```swift
private func tagColor(for tag: String) -> Color {
    var hash = 0
    for char in tag.utf8 {
        hash = (hash &* 31) &+ Int(char)
    }
    let hue = Double(abs(hash) % 360) / 360.0
    return Color(hue: hue, saturation: 0.7, brightness: 0.8)
}
```

While the hash itself is fast, this runs **every render** for **every visible row**. With 20 visible rows and 60fps scrolling, that's 1200 redundant calculations per second.

**Fix:**
```swift
// Option 1: Static cache dictionary
private static var tagColorCache: [String: Color] = [:]

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

// Option 2: Precompute in LogEntry model
// Option 3: Use an enum with known tag values
```

---

### 🟠 HIGH: EnvironmentObject Causes Full View Tree Re-render

**Location:** `LogListView`

**Problem:**
```swift
@EnvironmentObject var logBuffer: LogBuffer
```

When `logBuffer.filteredEntries` changes, **the entire LogListView body recomputes**, including all modifiers. Even if List virtualizes rows, the `ForEach` still iterates the entire array to diff.

**Impact:** Noticeable lag when log entries are added rapidly.

**Fix:**
```swift
// 1. Use @ObservedObject with explicit view model
@StateObject private var viewModel = LogListViewModel()

// 2. Or isolate the List in a child view that only observes what it needs
struct LogListContent: View {
    @ObservedObject var logBuffer: LogBuffer  // Scoped observation
    // ...
}

// 3. Consider using Combine to debounce rapid updates
logBuffer.$filteredEntries
    .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
```

---

### 🟠 HIGH: Closure Allocation in ForEach Loop

**Location:** `LogListView.body`

**Problem:**
```swift
ForEach(logBuffer.filteredEntries) { entry in
    LogRowView(
        entry: entry,
        isExpanded: expandedJSONEntries.contains(entry.id),
        onToggleJSON: {
            toggleJSON(for: entry)  // New closure allocated per row
        }
    )
}
```

A new closure is allocated for every row on every render. Closures that capture `entry` prevent potential optimizations.

**Fix:**
```swift
// Option 1: Pass entry.id and let child handle toggle
struct LogRowView: View {
    let entry: LogEntry
    let isExpanded: Bool
    let onToggleJSON: (UUID) -> Void  // Takes ID instead of capturing entry
    
    var body: some View {
        // ...
        Button { onToggleJSON(entry.id) } label: { ... }
    }
}

// Option 2: Use Binding directly
@Binding var expandedJSONEntries: Set<UUID>

// Option 3: Environment action
@Environment(\.toggleJSONAction) var toggleJSON
```

---

### 🟠 HIGH: onChange Triggers on Array Count, Not Identity

**Location:** `LogListView.body`

**Problem:**
```swift
.onChange(of: logBuffer.filteredEntries.count) { _ in
```

Triggers only on count change, missing when entries are replaced/updated with same count. Also, accessing `.count` still requires traversing the collection if it's not O(1).

**Fix:**
```swift
// Track a dedicated version/revision number
.onChange(of: logBuffer.entriesVersion) { _ in

// Or use the last entry's ID
.onChange(of: logBuffer.filteredEntries.last?.id) { newLastId in
    guard let id = newLastId else { return }
    // scroll logic
}
```

---

### 🟡 MEDIUM: Task Spawned Without Cancellation Handling

**Location:** `LogListView.body` onChange handler

**Problem:**
```swift
Task { @MainActor in
    try? await Task.sleep(nanoseconds: 10_000_000)
    if let lastEntry = logBuffer.filteredEntries.last {
        // ...
    }
}
```

Multiple rapid updates spawn multiple tasks. They don't cancel previous pending scrolls, potentially causing scroll fighting.

**Fix:**
```swift
// Store task reference and cancel previous
@State private var autoScrollTask: Task<Void, Never>?

// In onChange:
autoScrollTask?.cancel()
autoScrollTask = Task { @MainActor in
    try? await Task.sleep(nanoseconds: 10_000_000)
    guard !Task.isCancelled else { return }
    // scroll logic
}
```

---

### 🟡 MEDIUM: entryBackground Computed Every Render

**Location:** `LogListView.body`

**Problem:**
```swift
.background(entryBackground(for: entry))
```

Without seeing the implementation, this likely recomputes styling logic for every visible row on every render.

**Fix:**
```swift
// Cache in LogEntry or use computed property with memoization
extension LogEntry {
    var backgroundColor: Color {
        // Compute once, cache in model
    }
}

// Or use equatable conformance to skip re-renders
struct LogRowView: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry.id == rhs.entry.id && lhs.isExpanded == rhs.isExpanded
    }
}
```

---

### 🟢 LOW: expandedJSONEntries Set Lookup in Hot Path

**Location:** `LogListView.body`

**Problem:**
```swift
isExpanded: expandedJSONEntries.contains(entry.id)
```

Set lookup is O(1), but reading `@State` in a loop triggers dependency tracking for each row.

**Fix:**
```swift
// Pass the Set to child view, let it do the lookup
struct LogRowView: View {
    let expandedEntries: Set<UUID>
    
    var isExpanded: Bool {
        expandedEntries.contains(entry.id)
    }
}

// Or use EquatableView wrapper to prevent re-renders
```

---

## Recommended Architecture Changes

### 1. Extract Row to Equatable View

```swift
struct LogRowView: View, Equatable {
    let entry: LogEntry
    let isExpanded: Bool
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry.id == rhs.entry.id &&
        lhs.entry.timestamp == rhs.entry.timestamp &&
        lhs.isExpanded == rhs.isExpanded
    }
    
    var body: some View {
        // SwiftUI skips body if Equatable returns true
    }
}
```

### 2. Use LazyVStack for Custom Virtualization (if List perf insufficient)

```swift
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(logBuffer.filteredEntries) { entry in
            LogRowView(...)
                .id(entry.id)
        }
    }
}
```

### 3. Debounce Rapid Updates

```swift
class LogBuffer: ObservableObject {
    @Published var displayedEntries: [LogEntry] = []
    private var pendingEntries: [LogEntry] = []
    
    func addEntry(_ entry: LogEntry) {
        pendingEntries.append(entry)
        debounceFlush()
    }
    
    private func debounceFlush() {
        // Batch updates every 100ms
    }
}
```

---

## Priority Order for Fixes

1. **DateFormatter** — Immediate, biggest impact
2. **Tag color cache** — Immediate, easy win  
3. **Equatable LogRowView** — High impact on re-renders
4. **Closure allocation** — Medium effort, good payoff
5. **Task cancellation** — Prevents edge case bugs
6. **Architecture refactor** — Longer term improvement

---

## Testing Recommendations

1. Use Instruments → SwiftUI profiler to measure body evaluations
2. Add `let _ = Self._printChanges()` in body to log re-renders
3. Profile with 1000+ log entries to stress test
4. Test rapid log ingestion (100+ entries/second)
