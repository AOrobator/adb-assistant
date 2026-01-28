import XCTest
@testable import ADBAssistant

@MainActor
final class LogBufferTests: XCTestCase {
    
    func testAppendEntry() async {
        let buffer = LogBuffer(maxSize: 100)
        let entry = createLogEntry(message: "Test message")
        
        buffer.append(entry)
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        XCTAssertEqual(buffer.totalCount, 1)
        XCTAssertEqual(buffer.entries.count, 1)
    }
    
    func testCircularBuffer() async {
        let buffer = LogBuffer(maxSize: 3)
        
        buffer.append(createLogEntry(message: "1"))
        buffer.append(createLogEntry(message: "2"))
        buffer.append(createLogEntry(message: "3"))
        buffer.append(createLogEntry(message: "4"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        XCTAssertEqual(buffer.totalCount, 3)
        XCTAssertEqual(buffer.entries.first?.message, "2")
        XCTAssertEqual(buffer.entries.last?.message, "4")
    }
    
    func testClear() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(message: "1"))
        buffer.append(createLogEntry(message: "2"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        buffer.clear()
        
        XCTAssertEqual(buffer.totalCount, 0)
        XCTAssertEqual(buffer.entries.count, 0)
    }
    
    func testPauseAndResume() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(message: "1"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        buffer.pause()
        buffer.append(createLogEntry(message: "2"))
        buffer.append(createLogEntry(message: "3"))
        
        XCTAssertTrue(buffer.isPaused)
        XCTAssertEqual(buffer.newLogCount, 2)
        XCTAssertEqual(buffer.totalCount, 1)
        
        buffer.resume()
        
        // Wait for batch to flush after resume
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        XCTAssertFalse(buffer.isPaused)
        XCTAssertEqual(buffer.newLogCount, 0)
        XCTAssertEqual(buffer.totalCount, 3)
    }
    
    func testLevelFilter() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(level: .debug, message: "Debug"))
        buffer.append(createLogEntry(level: .info, message: "Info"))
        buffer.append(createLogEntry(level: .error, message: "Error"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        var filter = LogFilter()
        filter.minLevel = .info
        buffer.setFilter(filter)
        
        XCTAssertEqual(buffer.filteredEntries.count, 2)
    }
    
    func testTagFilter() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(tag: "Tag1", message: "1"))
        buffer.append(createLogEntry(tag: "Tag2", message: "2"))
        buffer.append(createLogEntry(tag: "Tag1", message: "3"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        var filter = LogFilter()
        filter.tags = ["Tag1"]
        buffer.setFilter(filter)
        
        XCTAssertEqual(buffer.filteredEntries.count, 2)
    }
    
    func testExcludeTagFilter() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(tag: "Tag1", message: "1"))
        buffer.append(createLogEntry(tag: "Tag2", message: "2"))
        buffer.append(createLogEntry(tag: "Tag3", message: "3"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        var filter = LogFilter()
        filter.excludeTags = ["Tag2"]
        buffer.setFilter(filter)
        
        XCTAssertEqual(buffer.filteredEntries.count, 2)
    }
    
    func testSearch() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(message: "Hello world"))
        buffer.append(createLogEntry(message: "Goodbye world"))
        buffer.append(createLogEntry(message: "Hello universe"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        let results = buffer.search("Hello")
        
        XCTAssertEqual(results.count, 2)
    }
    
    func testCountByLevel() async {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(level: .debug, message: "1"))
        buffer.append(createLogEntry(level: .debug, message: "2"))
        buffer.append(createLogEntry(level: .error, message: "3"))
        
        // Wait for batch to flush
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        let counts = buffer.countByLevel()
        
        XCTAssertEqual(counts[.debug], 2)
        XCTAssertEqual(counts[.error], 1)
    }
    
    // MARK: - Helpers
    
    private func createLogEntry(
        level: LogLevel = .info,
        tag: String = "Test",
        message: String
    ) -> LogEntry {
        LogEntry(
            timestamp: Date(),
            level: level,
            tag: tag,
            pid: 1234,
            tid: 5678,
            message: message,
            rawLine: ""
        )
    }
}
