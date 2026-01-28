---
name: macos-performance
description: Trigger when working with high-throughput macOS apps, SwiftUI performance, threading, or when the app becomes unresponsive. Critical for log streaming and real-time data apps.
---

# macOS Performance & Threading Best Practices

## The Golden Rule: Never Block the Main Thread

The main thread (aka UI thread) handles:
- User input (mouse, keyboard, trackpad)
- Window rendering and updates
- SwiftUI view lifecycle

**Blocking the main thread = spinning beach ball = bad user experience**

## High-Throughput App Patterns

### 1. Data Ingestion (Background)

❌ **Bad:** Processing data on main thread
```swift
// DON'T: Blocking main thread
func processLogs(_ logs: [String]) {
    for log in logs {  // Blocks UI during processing
        parseAndStore(log)
    }
}
```

✅ **Good:** Background processing with batched UI updates
```swift
// DO: Process on background, batch updates to main
func processLogs(_ logs: [String]) {
    Task.detached(priority: .userInitiated) {
        var batch: [LogEntry] = []
        for log in logs {
            if let entry = parse(log) {
                batch.append(entry)
                if batch.count >= 100 {
                    await MainActor.run {
                        self.appendBatch(batch)
                    }
                    batch.removeAll(keepingCapacity: true)
                }
            }
        }
        // Final batch
        if !batch.isEmpty {
            await MainActor.run {
                self.appendBatch(batch)
            }
        }
    }
}
```

### 2. Timer-Based Polling

❌ **Bad:** Timer firing on main thread
```swift
// DON'T: Timer on main thread blocks UI
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    // Heavy work here = beach ball
}
```

✅ **Good:** Timer on background, results to main
```swift
// DO: Use background queue for timer
let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
    Task.detached(priority: .background) {
        let result = await doWork()
        await MainActor.run {
            self.updateUI(result)
        }
    }
}
RunLoop.current.add(timer, forMode: .common)
```

### 3. Process/Subprocess Management

❌ **Bad:** Reading process output synchronously
```swift
// DON'T: Synchronous read blocks
let data = pipe.fileHandleForReading.readDataToEndOfFile()
```

✅ **Good:** Asynchronous streaming with handler
```swift
// DO: Use readabilityHandler for streaming
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    // Process on background
    Task.detached(priority: .userInitiated) {
        let entries = parseBatch(data)
        await MainActor.run {
            self.appendEntries(entries)
        }
    }
}
```

### 4. SwiftUI List Performance

❌ **Bad:** Updating list with every single item
```swift
// DON'T: Individual updates cause thrashing
ForEach(entries) { entry in
    // Each new entry triggers full list re-render
}
```

✅ **Good:** Batched updates, debounced
```swift
// DO: Batch updates and throttle
class LogBuffer: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    private var pendingEntries: [LogEntry] = []
    private var updateTimer: Timer?
    
    func append(_ entry: LogEntry) {
        pendingEntries.append(entry)
        
        // Throttle UI updates to 60fps max
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: false) { [weak self] _ in
                self?.flushPendingEntries()
            }
        }
    }
    
    private func flushPendingEntries() {
        let batch = pendingEntries
        pendingEntries.removeAll(keepingCapacity: true)
        updateTimer = nil
        
        // Single UI update with batch
        entries.append(contentsOf: batch)
        
        // Trim if needed (on background)
        if entries.count > maxSize {
            Task.detached {
                await MainActor.run {
                    self.entries.removeFirst(self.entries.count - self.maxSize)
                }
            }
        }
    }
}
```

### 5. Regex Performance

❌ **Bad:** Creating regex on every call
```swift
// DON'T: Compiling regex every time
func parse(_ line: String) {
    let regex = try! NSRegularExpression(pattern: "...")  // Expensive!
}
```

✅ **Good:** Static regex, compiled once
```swift
// DO: Static compiled regex
private static let logRegex: NSRegularExpression = {
    let pattern = "..."
    return try! NSRegularExpression(pattern: pattern)
}()

func parse(_ line: String) {
    // Use Self.logRegex - already compiled
}
```

### 6. String Processing

❌ **Bad:** Repeated string operations
```swift
// DON'T: Multiple passes over string
let trimmed = line.trimmingCharacters(in: .whitespaces)
let lower = trimmed.lowercased()
let components = lower.components(separatedBy: " ")
```

✅ **Good:** Minimal string operations
```swift
// DO: Single pass where possible
func parseLine(_ line: String) {
    // Work with original string, use indices
    let start = line.startIndex
    let end = line.endIndex
    // Parse directly without creating new strings
}
```

### 7. Memory Management

❌ **Bad:** Retaining large buffers indefinitely
```swift
// DON'T: Unbounded growth
var allLogs: [LogEntry] = []  // Grows forever = memory leak
```

✅ **Good:** Circular buffer with fixed size
```swift
// DO: Fixed-size circular buffer
class CircularBuffer<T> {
    private var buffer: [T?]
    private var writeIndex = 0
    private let maxSize: Int
    
    func append(_ item: T) {
        buffer[writeIndex] = item
        writeIndex = (writeIndex + 1) % maxSize
    }
    
    var entries: [T] {
        // Return contiguous array without reallocation
        buffer.compactMap { $0 }
    }
}
```

### 8. Combine/Publisher Performance

❌ **Bad:** Creating publishers frequently
```swift
// DON'T: New publisher per event
func stream() -> AnyPublisher<LogEntry, Never> {
    return subject.eraseToAnyPublisher()  // Creates new type erasure
}
```

✅ **Good:** Pre-created publisher
```swift
// DO: Single type-erased publisher
private let logSubject = PassthroughSubject<LogEntry, Never>()
private lazy var logStream: AnyPublisher<LogEntry, Never> = {
    logSubject.eraseToAnyPublisher()
}()
```

## Performance Checklist

- [ ] No synchronous I/O on main thread
- [ ] No heavy computation on main thread
- [ ] UI updates batched and throttled (max 60fps)
- [ ] Regex patterns compiled once (static)
- [ ] String operations minimized
- [ ] Memory bounded (circular buffers)
- [ ] Publishers pre-created, not per-call
- [ ] Background tasks use appropriate priority:
  - `.userInitiated` - user is waiting (parsing)
  - `.utility` - ongoing work (streaming)
  - `.background` - maintenance (cleanup)

## Debugging Performance

1. **Instruments > Time Profiler** - Find main thread blocks
2. **Instruments > Allocations** - Find memory bloat
3. **Xcode Debug Navigator** - CPU/Memory usage
4. **Signposts** - Measure operation duration:
```swift
import os.signpost

let log = OSLog(subsystem: "com.app", category: "Performance")
os_signpost(.begin, log: log, name: "ParseBatch")
// ... work ...
os_signpost(.end, log: log, name: "ParseBatch")
```

## High-Throughput Specifics

For log streaming (10,000+ lines/second):
- Parse on background, never main
- Batch UI updates (every 16ms = 60fps)
- Use `Deque` from Swift Collections for O(1) append/remove
- Consider Metal/Compute for massive parallel processing
- Profile with real device load, not just tests
