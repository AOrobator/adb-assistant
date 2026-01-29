import Foundation
import Combine

/// Thread-safe buffer for log entries with batched UI updates
@MainActor
public class LogBuffer: ObservableObject {
    
    @Published public private(set) var entries: [LogEntry] = []
    @Published public private(set) var filteredEntries: [LogEntry] = []
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var newLogCount: Int = 0
    @Published public private(set) var droppedWhilePaused: Int = 0
    
    public let maxSize: Int
    
    private var filter: LogFilter = LogFilter()
    private var pendingEntries: [LogEntry] = []
    private let maxPendingEntries = 10_000
    
    // Batching for performance
    private var batchBuffer: [LogEntry] = []
    private var batchTimer: DispatchSourceTimer?
    private let batchInterval: TimeInterval = 1.0 / 60.0  // 60fps max
    private let batchSize = 100  // Max entries per batch
    
    public init(maxSize: Int = 50000) {
        self.maxSize = maxSize
    }
    
    // MARK: - Buffer Operations
    
    /// Appends a log entry to the buffer (batched for performance)
    public func append(_ entry: LogEntry) {
        appendEntries([entry])
    }
    
    /// Appends multiple entries efficiently
    public func append(_ newEntries: [LogEntry]) {
        appendEntries(newEntries)
    }
    
    /// Flushes pending batch to UI
    private func flushBatch() {
        guard !batchBuffer.isEmpty else {
            cancelBatchTimer()
            return
        }
        
        let batch = batchBuffer
        batchBuffer.removeAll(keepingCapacity: true)
        cancelBatchTimer()
        applyBatch(batch)
    }
    
    /// Clears the buffer
    public func clear() {
        flushBatch()  // Flush any pending first
        pendingEntries.removeAll()
        newLogCount = 0
        droppedWhilePaused = 0
        batchBuffer.removeAll()
        cancelBatchTimer()
        entries.removeAll()
        filteredEntries.removeAll()
    }
    
    // MARK: - Pause/Resume
    
    /// Pauses log streaming
    public func pause() {
        isPaused = true
    }
    
    /// Resumes log streaming and applies pending entries
    public func resume() {
        isPaused = false
        
        // Apply pending entries in batch
        let pending = pendingEntries
        pendingEntries.removeAll()
        newLogCount = 0
        droppedWhilePaused = 0
        
        appendEntries(pending)
    }
    
    // MARK: - Filtering
    
    /// Updates the filter and refreshes displayed entries
    public func setFilter(_ newFilter: LogFilter) {
        filter = newFilter
        updateFilteredEntries()
    }
    
    private func updateFilteredEntries() {
        filteredEntries = entries.filter { filter.matches($0) }
    }
    
    // MARK: - Search
    
    /// Searches for entries matching the query
    public func search(_ query: String, caseSensitive: Bool = false) -> [LogEntry] {
        let options: String.CompareOptions = caseSensitive ? [] : .caseInsensitive
        return entries.filter { entry in
            entry.message.range(of: query, options: options) != nil ||
            entry.tag.range(of: query, options: options) != nil
        }
    }
    
    // MARK: - Statistics
    
    /// Returns count of entries by level
    public func countByLevel() -> [LogLevel: Int] {
        var counts: [LogLevel: Int] = [:]
        for entry in entries {
            counts[entry.level, default: 0] += 1
        }
        return counts
    }
    
    /// Total buffered entries
    public var totalCount: Int {
        entries.count
    }

    // MARK: - Private Helpers
    
    private func appendEntries(_ newEntries: [LogEntry]) {
        guard !newEntries.isEmpty else { return }
        
        if isPaused {
            enqueuePending(newEntries)
            return
        }
        
        batchBuffer.append(contentsOf: newEntries)
        scheduleBatchFlush()
        
        if batchBuffer.count >= batchSize {
            flushBatch()
        }
    }
    
    private func enqueuePending(_ newEntries: [LogEntry]) {
        guard !newEntries.isEmpty else { return }
        
        let availableCapacity = max(0, maxPendingEntries - pendingEntries.count)
        if availableCapacity > 0 {
            let slice = newEntries.prefix(availableCapacity)
            pendingEntries.append(contentsOf: slice)
        }
        
        let dropped = newEntries.count - availableCapacity
        if dropped > 0 {
            droppedWhilePaused += dropped
        }
        
        newLogCount = pendingEntries.count
    }
    
    private func scheduleBatchFlush() {
        guard batchTimer == nil else { return }
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + batchInterval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.flushBatch()
            }
        }
        timer.resume()
        batchTimer = timer
    }
    
    private func cancelBatchTimer() {
        batchTimer?.cancel()
        batchTimer = nil
    }
    
    private func applyBatch(_ batch: [LogEntry]) {
        guard !batch.isEmpty else { return }
        
        entries.append(contentsOf: batch)
        
        var removedIDs = Set<UUID>()
        if entries.count > maxSize {
            let excess = entries.count - maxSize
            let removed = entries.prefix(excess)
            removedIDs = Set(removed.map { $0.id })
            entries.removeFirst(excess)
        }
        
        if !removedIDs.isEmpty {
            filteredEntries.removeAll { removedIDs.contains($0.id) }
        }
        
        let remainingBatch: [LogEntry]
        if removedIDs.isEmpty {
            remainingBatch = batch
        } else {
            remainingBatch = batch.filter { !removedIDs.contains($0.id) }
        }
        
        if !remainingBatch.isEmpty {
            let matching = remainingBatch.filter { filter.matches($0) }
            if !matching.isEmpty {
                filteredEntries.append(contentsOf: matching)
            }
        }
    }
}

/// Filter configuration for log entries
public struct LogFilter: Equatable {
    public var minLevel: LogLevel
    public var maxLevel: LogLevel
    public var tags: Set<String>
    public var excludeTags: Set<String>
    public var searchQuery: String?
    public var caseSensitive: Bool
    public var useRegex: Bool
    
    public init(
        minLevel: LogLevel = .verbose,
        maxLevel: LogLevel = .fatal,
        tags: Set<String> = [],
        excludeTags: Set<String> = [],
        searchQuery: String? = nil,
        caseSensitive: Bool = false,
        useRegex: Bool = false
    ) {
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.tags = tags
        self.excludeTags = excludeTags
        self.searchQuery = searchQuery
        self.caseSensitive = caseSensitive
        self.useRegex = useRegex
    }
    
    /// Checks if an entry matches the filter
    public func matches(_ entry: LogEntry) -> Bool {
        // Level filter
        guard entry.level >= minLevel && entry.level <= maxLevel else {
            return false
        }
        
        // Tag filter
        if !tags.isEmpty && !tags.contains(entry.tag) {
            return false
        }
        
        // Exclude tags
        if excludeTags.contains(entry.tag) {
            return false
        }
        
        // Search query
        if let query = searchQuery, !query.isEmpty {
            let options: String.CompareOptions = caseSensitive ? [] : .caseInsensitive
            
            if useRegex {
                // TODO: Implement regex matching
                return entry.message.range(of: query, options: options) != nil ||
                       entry.tag.range(of: query, options: options) != nil
            } else {
                return entry.message.range(of: query, options: options) != nil ||
                       entry.tag.range(of: query, options: options) != nil
            }
        }
        
        return true
    }
}
