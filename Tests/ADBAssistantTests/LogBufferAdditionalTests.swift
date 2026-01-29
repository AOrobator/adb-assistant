import XCTest
@testable import ADBAssistant

@MainActor
final class LogBufferAdditionalTests: XCTestCase {
    func testAppendEntriesArray() async {
        let buffer = LogBuffer(maxSize: 10)
        let entries = [
            makeEntry(message: "one"),
            makeEntry(message: "two")
        ]
        buffer.append(entries)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(buffer.entries.count, 2)
    }

    func testPausedDropsExcessEntries() {
        let buffer = LogBuffer(maxSize: 5)
        buffer.pause()

        let entries = (0..<10_005).map { index in
            makeEntry(message: "\(index)")
        }
        buffer.append(entries)

        XCTAssertEqual(buffer.newLogCount, 10_000)
        XCTAssertEqual(buffer.droppedWhilePaused, 5)
    }

    func testApplyBatchTrimsAndFilteredEntries() async {
        let buffer = LogBuffer(maxSize: 3)
        let entries = [
            makeEntry(message: "1"),
            makeEntry(message: "2"),
            makeEntry(message: "3"),
            makeEntry(message: "4")
        ]
        buffer.append(entries)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(buffer.entries.count, 3)
        XCTAssertEqual(buffer.entries.first?.message, "2")
    }

    func testFilterCaseSensitiveAndRegexBranch() async {
        let buffer = LogBuffer(maxSize: 10)
        buffer.append(makeEntry(message: "Hello"))
        buffer.append(makeEntry(message: "hello"))
        try? await Task.sleep(nanoseconds: 100_000_000)

        var filter = LogFilter()
        filter.searchQuery = "Hello"
        filter.caseSensitive = true
        filter.useRegex = true
        buffer.setFilter(filter)

        // Wait for async filter to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(buffer.filteredEntries.count, 1)
        XCTAssertEqual(buffer.filteredEntries.first?.message, "Hello")
    }

    // MARK: - Async Filter Tests

    func testIsFilteringStateTransitions() async {
        let buffer = LogBuffer(maxSize: 100)

        // Add entries
        for i in 0..<50 {
            buffer.append(makeEntry(message: "Message \(i)"))
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(buffer.isFiltering, "Should not be filtering initially")

        // Apply filter - isFiltering should become true
        var filter = LogFilter()
        filter.minLevel = .warning
        buffer.setFilter(filter)

        XCTAssertTrue(buffer.isFiltering, "Should be filtering immediately after setFilter")

        // Wait for filter to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(buffer.isFiltering, "Should not be filtering after completion")
    }

    func testRapidFilterChangesCancelPrevious() async {
        let buffer = LogBuffer(maxSize: 1000)

        // Add many entries to make filtering take some time
        for i in 0..<500 {
            buffer.append(makeEntry(level: i % 2 == 0 ? .debug : .error, message: "Message \(i)"))
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Rapidly change filters
        var filter1 = LogFilter()
        filter1.minLevel = .debug
        buffer.setFilter(filter1)

        var filter2 = LogFilter()
        filter2.minLevel = .info
        buffer.setFilter(filter2)

        var filter3 = LogFilter()
        filter3.minLevel = .error
        buffer.setFilter(filter3)

        // Wait for final filter to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Only the last filter should be applied (error level only)
        XCTAssertEqual(buffer.filteredEntries.count, 250, "Only error entries should remain")
        XCTAssertTrue(buffer.filteredEntries.allSatisfy { $0.level == .error })
        XCTAssertFalse(buffer.isFiltering)
    }

    func testClearCancelsFilterTask() async {
        let buffer = LogBuffer(maxSize: 100)

        for i in 0..<50 {
            buffer.append(makeEntry(message: "Message \(i)"))
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Start filtering
        var filter = LogFilter()
        filter.minLevel = .error
        buffer.setFilter(filter)

        // Clear immediately
        buffer.clear()

        XCTAssertFalse(buffer.isFiltering, "Clear should reset isFiltering")
        XCTAssertEqual(buffer.entries.count, 0)
        XCTAssertEqual(buffer.filteredEntries.count, 0)
    }

    func testFilteredEntriesEmptyAfterFilterWithNoMatches() async {
        let buffer = LogBuffer(maxSize: 100)

        // Add only debug entries
        for i in 0..<10 {
            buffer.append(makeEntry(level: .debug, message: "Debug \(i)"))
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Filter for errors only
        var filter = LogFilter()
        filter.minLevel = .error
        buffer.setFilter(filter)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(buffer.filteredEntries.count, 0)
        XCTAssertEqual(buffer.entries.count, 10, "Original entries should remain")
    }

    func testFilterPreservesEntryOrder() async {
        let buffer = LogBuffer(maxSize: 100)

        buffer.append(makeEntry(level: .error, message: "First"))
        buffer.append(makeEntry(level: .debug, message: "Second"))
        buffer.append(makeEntry(level: .error, message: "Third"))
        buffer.append(makeEntry(level: .debug, message: "Fourth"))
        buffer.append(makeEntry(level: .error, message: "Fifth"))

        try? await Task.sleep(nanoseconds: 100_000_000)

        var filter = LogFilter()
        filter.minLevel = .error
        buffer.setFilter(filter)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(buffer.filteredEntries.count, 3)
        XCTAssertEqual(buffer.filteredEntries[0].message, "First")
        XCTAssertEqual(buffer.filteredEntries[1].message, "Third")
        XCTAssertEqual(buffer.filteredEntries[2].message, "Fifth")
    }

    private func makeEntry(
        level: LogLevel = .info,
        tag: String = "Test",
        message: String
    ) -> LogEntry {
        LogEntry(
            timestamp: Date(),
            level: level,
            tag: tag,
            pid: 1,
            tid: 1,
            message: message,
            rawLine: ""
        )
    }
}
