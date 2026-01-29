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

        XCTAssertEqual(buffer.filteredEntries.count, 1)
        XCTAssertEqual(buffer.filteredEntries.first?.message, "Hello")
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
