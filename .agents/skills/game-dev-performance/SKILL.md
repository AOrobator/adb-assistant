# Game Dev Performance Patterns for High-Throughput UI

Borrowing best practices from the gaming industry for handling high-frequency updates in real-time applications.

## Core Principles from Game Development

### 1. Frame Budgeting (16.67ms for 60fps)
```swift
// Never exceed your frame budget
// If processing takes longer, defer to next frame
let frameTime: TimeInterval = 1.0 / 60.0  // 16.67ms

func update(currentTime: TimeInterval) {
    let deltaTime = currentTime - lastUpdateTime
    guard deltaTime >= frameTime else { return }
    
    // Do work
    processPendingUpdates()
    lastUpdateTime = currentTime
}
```

### 2. Double/Triple Buffering
```swift
// Avoid tearing and stuttering by buffering updates
class BufferedLogBuffer {
    private var writeBuffer: [LogEntry] = []
    private var readBuffer: [LogEntry] = []
    private let lock = NSLock()
    
    func append(_ entry: LogEntry) {
        lock.lock()
        writeBuffer.append(entry)
        lock.unlock()
    }
    
    func swapBuffers() -> [LogEntry] {
        lock.lock()
        (readBuffer, writeBuffer) = (writeBuffer, readBuffer)
        writeBuffer.removeAll(keepingCapacity: true)
        lock.unlock()
        return readBuffer
    }
}
```

### 3. Object Pooling
```swift
// Reuse objects instead of allocating
class LogEntryPool {
    private var available: [LogEntry] = []
    private let maxSize = 1000
    
    func acquire() -> LogEntry {
        return available.popLast() ?? LogEntry()
    }
    
    func release(_ entry: LogEntry) {
        guard available.count < maxSize else { return }
        // Reset state
        available.append(entry)
    }
}
```

### 4. Update Loops vs Event-Driven
```swift
// Game-style update loop instead of reactive updates
class GameLoop {
    private var displayLink: CADisplayLink?
    private var pendingUpdates: [LogEntry] = []
    private let updateQueue = DispatchQueue(label: "updates")
    
    func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func tick() {
        // Process all pending updates once per frame
        let updates = updateQueue.sync { pendingUpdates }
        pendingUpdates.removeAll()
        
        // Batch update UI
        updateUI(with: updates)
    }
}
```

### 5. Level of Detail (LOD)
```swift
// Reduce detail when overwhelmed
class LODManager {
    var currentLOD: LOD = .full
    
    enum LOD {
        case full      // Show everything
        case reduced   // Skip every other entry
        case minimal   // Show only errors/warnings
        case paused    // Stop updates entirely
    }
    
    func adjustLOD(basedOn fps: Double) {
        if fps < 30 { currentLOD = .minimal }
        else if fps < 45 { currentLOD = .reduced }
        else { currentLOD = .full }
    }
}
```

### 6. Culling
```swift
// Don't render what's not visible
struct ViewCulling {
    let visibleRange: ClosedRange<Int>
    
    func shouldRender(index: Int) -> Bool {
        return visibleRange.contains(index)
    }
    
    func cull<T>(_ items: [T]) -> [T] {
        let start = max(0, visibleRange.lowerBound)
        let end = min(items.count - 1, visibleRange.upperBound)
        guard start <= end else { return [] }
        return Array(items[start...end])
    }
}
```

### 7. Fixed Time Step
```swift
// Consistent updates regardless of frame rate
class FixedTimeStep {
    let fixedDelta: TimeInterval = 1.0 / 60.0
    var accumulator: TimeInterval = 0
    var lastTime: TimeInterval = 0
    
    func update(currentTime: TimeInterval) {
        let delta = currentTime - lastTime
        lastTime = currentTime
        accumulator += delta
        
        while accumulator >= fixedDelta {
            fixedUpdate()
            accumulator -= fixedDelta
        }
    }
    
    func fixedUpdate() {
        // Process at fixed rate
    }
}
```

### 8. Job System
```swift
// Parallelize work across cores
class JobSystem {
    let queue = OperationQueue()
    
    func dispatch<T>(_ jobs: [() -> T], completion: @escaping ([T]) -> Void) {
        let operations = jobs.map { job in
            BlockOperation { job() }
        }
        
        let finish = BlockOperation {
            // Collect results
        }
        
        operations.forEach { finish.addDependency($0) }
        queue.addOperations(operations + [finish], waitUntilFinished: false)
    }
}
```

## Applying to Log Viewers

### Problem: High-volume log streaming

**Game Dev Solution:**
1. **Render thread** (Main): Only render visible rows
2. **Update thread** (Background): Parse and buffer logs
3. **Swap buffers** at frame boundary
4. **LOD**: Reduce to error-only when overwhelmed
5. **Culling**: Virtual scrolling with fixed row heights

### Implementation Pattern
```swift
class GameStyleLogViewer: ObservableObject {
    // Triple buffering
    private var backBuffer: [LogEntry] = []
    private var middleBuffer: [LogEntry] = []
    @Published private(set) var frontBuffer: [LogEntry] = []
    
    // Frame timing
    private var lastFrameTime: TimeInterval = 0
    private let targetFrameTime: TimeInterval = 1.0 / 60.0
    
    // LOD
    private var currentLOD: LOD = .full
    private var frameCounter = 0
    
    func receiveLog(_ entry: LogEntry) {
        // Add to back buffer (thread-safe)
        backBuffer.append(entry)
    }
    
    func tick(currentTime: TimeInterval) {
        let delta = currentTime - lastFrameTime
        guard delta >= targetFrameTime else { return }
        
        // Swap buffers
        (middleBuffer, backBuffer) = (backBuffer, middleBuffer)
        backBuffer.removeAll(keepingCapacity: true)
        
        // Apply LOD
        let toProcess = applyLOD(middleBuffer)
        
        // Update front buffer on main thread
        frontBuffer.append(contentsOf: toProcess)
        
        // Trim if needed
        if frontBuffer.count > maxEntries {
            frontBuffer.removeFirst(frontBuffer.count - maxEntries)
        }
        
        lastFrameTime = currentTime
        frameCounter += 1
    }
    
    private func applyLOD(_ entries: [LogEntry]) -> [LogEntry] {
        switch currentLOD {
        case .full: return entries
        case .reduced: return entries.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
        case .minimal: return entries.filter { $0.level >= .error }
        }
    }
}
```

## Key Takeaways

1. **Predictable timing** > Reactive updates
2. **Batch everything** > Individual updates
3. **Buffer swaps** > Direct mutation
4. **LOD degradation** > Dropping frames
5. **Culling** > Rendering everything
6. **Object pools** > Allocations
7. **Fixed time steps** > Variable delta
