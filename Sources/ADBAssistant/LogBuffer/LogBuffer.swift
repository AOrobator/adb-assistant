import Foundation
import Combine

/// Thread-safe circular buffer for log entries
@MainActor
public class LogBuffer: ObservableObject {
    
    @Published public private(set) var entries: [LogEntry] = []
    @Published public private(set) var filteredEntries: [LogEntry] = []
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var newLogCount: Int = 0
    
    public let maxSize: Int
    
    private var buffer: [LogEntry] = []
    private var writeIndex: Int = 0
    private var isFull: Bool = false
    private var filter: LogFilter = LogFilter()
    private var pendingEntries: [LogEntry] = []
    
    public init(maxSize: Int = 50000) {
        self.maxSize = maxSize
    }
    
    // MARK: - Buffer Operations
    
    /// Appends a log entry to the buffer
    public func append(_ entry: LogEntry) {
        if isPaused {
            pendingEntries.append(entry)
            newLogCount = pendingEntries.count
            return
        }
        
        // Add to circular buffer
        if buffer.count < maxSize {
            buffer.append(entry)
        } else {
            buffer[writeIndex] = entry
        }
        
        writeIndex = (writeIndex + 1) % maxSize
        if writeIndex == 0 {
            isFull = true
        }
        
        // Update published entries
        updateEntries()
    }
    
    /// Appends multiple entries
    public func append(_ newEntries: [LogEntry]) {
        for entry in newEntries {
            append(entry)
        }
    }
    
    /// Clears the buffer
    public func clear() {
        buffer.removeAll()
        writeIndex = 0
        isFull = false
        pendingEntries.removeAll()
        newLogCount = 0
        updateEntries()
    }
    
    // MARK: - Pause/Resume
    
    /// Pauses log streaming
    public func pause() {
        isPaused = true
    }
    
    /// Resumes log streaming and applies pending entries
    public func resume() {
        isPaused = false
        
        // Apply pending entries
        for entry in pendingEntries {
            append(entry)
        }
        pendingEntries.removeAll()
        newLogCount = 0
    }
    
    // MARK: - Filtering
    
    /// Updates the filter and refreshes displayed entries
    public func setFilter(_ newFilter: LogFilter) {
        filter = newFilter
        updateFilteredEntries()
    }
    
    /// Gets entries matching the current filter
    private func updateEntries() {
        // Get entries in chronological order
        let orderedEntries: [LogEntry]
        if isFull {
            orderedEntries = Array(buffer[writeIndex...] + buffer[..<writeIndex])
        } else {
            orderedEntries = buffer
        }
        
        entries = orderedEntries
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
        isFull ? maxSize : buffer.count
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
