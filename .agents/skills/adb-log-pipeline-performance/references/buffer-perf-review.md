# ADB LogBuffer Performance Review

**Date:** 2025-01-29  
**Reviewer:** Zed (subagent: perf-buffer)  
**Files:** ADBManager.swift, LogBuffer.swift

---

## Executive Summary

The log streaming pipeline has **7 significant performance issues** that compound under load. The most critical: batching logic that defeats its own purpose, aggressive polling, and O(n) operations on every update. Under high log volume (1000+ lines/sec), these will cause UI stuttering, memory pressure, and potential data loss.

---

## Issue #1: Batching Defeated by Individual Sends

**Severity:** 🔴 CRITICAL  
**Location:** ADBManager log streaming handler

```swift
// Batches 50 entries, then... sends them one at a time
await MainActor.run {
    for entry in batch {
        self.logSubject.send(entry)  // ← Each send triggers subscriber updates!
    }
}
```

**Problem:** The code batches 50 entries to reduce main thread hops, then immediately defeats that by calling `send()` 50 times in a loop. Each `send()` triggers Combine subscribers, potentially causing 50 separate UI updates.

**Fix:**
```swift
// Option A: Send batch as single event
await MainActor.run {
    self.logSubject.send(batch)  // Change subject type to PassthroughSubject<[LogEntry], Never>
}

// Option B: Use Combine's collect() operator on subscriber side
logSubject
    .collect(.byTime(RunLoop.main, .milliseconds(16)))  // ~60fps batching
    .sink { entries in /* handle batch */ }
```

---

## Issue #2: Aggressive Device Polling (0.5s)

**Severity:** 🟠 HIGH  
**Location:** ADBManager refresh timer

```swift
refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { ... }
```

**Problem:** 
- `adb devices` takes 50-200ms typically
- Polling every 500ms means 10-40% of time spent in device queries
- Creates background task churn (2 tasks/second)
- USB device changes are rare—polling this often is wasteful

**Fix:**
```swift
// Increase interval to 2-3 seconds
refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { ... }

// Better: Use event-driven detection
// macOS: IOKit notifications for USB
// Or: adb track-devices (persistent connection, push notifications)
```

---

## Issue #3: Task.detached Ordering Issues

**Severity:** 🟠 HIGH  
**Location:** ADBManager readability handler

```swift
outputPipe.fileHandleForReading.readabilityHandler = { handle in
    Task.detached(priority: .userInitiated) { ... }
}
```

**Problem:** Each data chunk spawns an independent detached task. If chunk N+1 arrives before chunk N finishes processing, logs may appear out of order. Under high throughput, this creates a task explosion.

**Fix:**
```swift
// Use an AsyncStream or serial actor
actor LogProcessor {
    func process(_ data: Data) async {
        // Serial processing guaranteed
    }
}

// Or use AsyncStream for backpressure
let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
outputPipe.fileHandleForReading.readabilityHandler = { handle in
    continuation.yield(handle.availableData)
}
```

---

## Issue #4: Timer Scheduled from Wrong Thread

**Severity:** 🟠 HIGH  
**Location:** LogBuffer.append()

```swift
public func append(_ entry: LogEntry) {
    // Called from background thread via MainActor.run callback
    if batchTimer == nil {
        batchTimer = Timer.scheduledTimer(...)  // ← Timers need a RunLoop!
    }
}
```

**Problem:** `Timer.scheduledTimer` requires the current thread to have an active RunLoop. Background threads from Task.detached don't have one by default. The timer may never fire.

**Fix:**
```swift
// Ensure timer is created on main thread
if batchTimer == nil {
    DispatchQueue.main.async {
        self.batchTimer = Timer.scheduledTimer(...)
    }
}

// Better: Use DispatchSourceTimer (thread-agnostic)
private var batchTimer: DispatchSourceTimer?

func scheduleBatchFlush() {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + batchInterval)
    timer.setEventHandler { [weak self] in self?.flushBatch() }
    timer.resume()
    batchTimer = timer
}
```

---

## Issue #5: O(n) Array Recreation on Every Flush

**Severity:** 🟡 MEDIUM  
**Location:** LogBuffer.updateEntries()

```swift
private func updateEntries() {
    let orderedEntries: [LogEntry]
    if isFull {
        // Creates TWO intermediate arrays, then concatenates
        orderedEntries = Array(buffer[writeIndex...] + buffer[..<writeIndex])
    } else {
        orderedEntries = buffer  // COW copy on mutation
    }
    entries = orderedEntries  // Full reassignment
    updateFilteredEntries()   // Re-filters ALL entries
}
```

**Problem:** Every flush (potentially 60x/second) creates new arrays and re-filters everything. With 10,000 entry buffer: 10K allocations + 10K filter comparisons per flush.

**Fix:**
```swift
// Use lazy/incremental approach
private func updateEntries() {
    // Only append new entries to existing array
    let newEntries = recentlyFlushedEntries
    entries.append(contentsOf: newEntries)
    
    // Trim from front if over capacity
    if entries.count > maxCapacity {
        entries.removeFirst(entries.count - maxCapacity)
    }
    
    // Incremental filter update
    updateFilteredEntries(newOnly: newEntries)
}

// Or use a proper circular buffer view type that doesn't require copying
struct CircularBufferView<T>: RandomAccessCollection {
    // Provides O(1) access without array recreation
}
```

---

## Issue #6: Unbounded pendingEntries Growth

**Severity:** 🟡 MEDIUM  
**Location:** LogBuffer.append() when paused

```swift
if isPaused {
    pendingEntries.append(entry)  // No limit!
    newLogCount = pendingEntries.count
    return
}
```

**Problem:** If user pauses during high log volume, `pendingEntries` grows unbounded. At 10K logs/sec, this consumes ~10MB/sec of memory. App will eventually crash or be killed by OS.

**Fix:**
```swift
if isPaused {
    if pendingEntries.count < maxPendingEntries {
        pendingEntries.append(entry)
    } else {
        droppedWhilePaused += 1  // Track for UI indicator
    }
    newLogCount = pendingEntries.count
    return
}
```

---

## Issue #7: Thread Safety on batchBuffer

**Severity:** 🟡 MEDIUM  
**Location:** LogBuffer.append() and flushBatch()

```swift
public func append(_ entry: LogEntry) {
    batchBuffer.append(entry)  // Thread A
    if batchBuffer.count >= batchSize {
        flushBatch()  // Reads batchBuffer
    }
}

private func flushBatch() {
    // Uses batchBuffer - what if append() is called concurrently?
}
```

**Problem:** If `append()` is called from multiple threads (which can happen via the detached tasks), `batchBuffer` access is unsynchronized. This causes crashes or data corruption.

**Fix:**
```swift
// Option A: Make LogBuffer an actor
actor LogBuffer {
    public func append(_ entry: LogEntry) { ... }
}

// Option B: Use a lock
private let lock = NSLock()

public func append(_ entry: LogEntry) {
    lock.withLock {
        batchBuffer.append(entry)
        if batchBuffer.count >= batchSize {
            flushBatch()
        }
    }
}
```

---

## Summary Table

| Issue | Severity | Impact | Effort to Fix |
|-------|----------|--------|---------------|
| #1 Batching defeated | 🔴 Critical | 50x unnecessary UI updates | Low |
| #2 Aggressive polling | 🟠 High | CPU waste, battery drain | Low |
| #3 Task ordering | 🟠 High | Out-of-order logs | Medium |
| #4 Timer thread | 🟠 High | Batch never flushes | Low |
| #5 O(n) array ops | 🟡 Medium | UI stuttering | Medium |
| #6 Unbounded pending | 🟡 Medium | Memory exhaustion | Low |
| #7 Thread safety | 🟡 Medium | Crashes, corruption | Medium |

---

## Recommended Priority

1. **Fix #1 first** — Biggest impact, easiest fix. Change subject to batch type.
2. **Fix #4 next** — Timer may be silently broken. Quick fix.
3. **Fix #7** — Data corruption is unacceptable. Actor conversion recommended.
4. **Fix #3** — Serial processing prevents ordering bugs.
5. **Fix #2, #5, #6** — Optimization polish.

---

## Architectural Suggestion

Consider restructuring as a pipeline:

```
FileHandle → AsyncStream<Data> → LogParser (actor) → LogBuffer (actor) → UI
                                      ↓
                              Serial, backpressure-aware
```

This eliminates threading issues by design and provides natural backpressure when UI can't keep up.
