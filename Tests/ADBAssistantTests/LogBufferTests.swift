import XCTest
@testable import ADBAssistant

@MainActor
final class LogBufferTests: XCTestCase {
    
    func testAppendEntry() {
        let buffer = LogBuffer(maxSize: 100)
        let entry = createLogEntry(message: "Test message")
        
        buffer.append(entry)
        
        XCTAssertEqual(buffer.totalCount, 1)
        XCTAssertEqual(buffer.entries.count, 1)
    }
    
    func testCircularBuffer() {
        let buffer = LogBuffer(maxSize: 3)
        
        buffer.append(createLogEntry(message: "1"))
        buffer.append(createLogEntry(message: "2"))
        buffer.append(createLogEntry(message: "3"))
        buffer.append(createLogEntry(message: "4"))
        
        XCTAssertEqual(buffer.totalCount, 3)
        XCTAssertEqual(buffer.entries.first?.message, "2")
        XCTAssertEqual(buffer.entries.last?.message, "4")
    }
    
    func testClear() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(message: "1"))
        buffer.append(createLogEntry(message: "2"))
        buffer.clear()
        
        XCTAssertEqual(buffer.totalCount, 0)
        XCTAssertEqual(buffer.entries.count, 0)
    }
    
    func testPauseAndResume() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(message: "1"))
        buffer.pause()
        buffer.append(createLogEntry(message: "2"))
        buffer.append(createLogEntry(message: "3"))
        
        XCTAssertTrue(buffer.isPaused)
        XCTAssertEqual(buffer.newLogCount, 2)
        XCTAssertEqual(buffer.totalCount, 1)
        
        buffer.resume()
        
        XCTAssertFalse(buffer.isPaused)
        XCTAssertEqual(buffer.newLogCount, 0)
        XCTAssertEqual(buffer.totalCount, 3)
    }
    
    func testLevelFilter() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(level: .debug, message: "Debug"))
        buffer.append(createLogEntry(level: .info, message: "Info"))
        buffer.append(createLogEntry(level: .error, message: "Error"))
        
        var filter = LogFilter()
        filter.minLevel = .info
        buffer.setFilter(filter)
        
        XCTAssertEqual(buffer.filteredEntries.count, 2)
    }
    
    func testTagFilter() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(tag: "Tag1", message: "1"))
        buffer.append(createLogEntry(tag: "Tag2", message: "2"))
        buffer.append(createLogEntry(tag: "Tag1", message: "3"))
        
        var filter = LogFilter()
        filter.tags = ["Tag1"]
        buffer.setFilter(filter)
        
        XCTAssertEqual(buffer.filteredEntries.count, 2)
    }
    
    func testExcludeTagFilter() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(tag: "Tag1", message: "1"))
        buffer.append(createLogEntry(tag: "Tag2", message: "2"))
        buffer.append(createLogEntry(tag: "Tag3", message: "3"))
        
        var filter = LogFilter()
        filter.excludeTags = ["Tag2"]
        buffer.setFilter(filter)
        
        XCTAssertEqual(buffer.filteredEntries.count, 2)
    }
    
    func testSearch() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(message: "Hello world"))
        buffer.append(createLogEntry(message: "Goodbye world"))
        buffer.append(createLogEntry(message: "Hello universe"))
        
        let results = buffer.search("Hello")
        
        XCTAssertEqual(results.count, 2)
    }
    
    func testCountByLevel() {
        let buffer = LogBuffer(maxSize: 100)
        
        buffer.append(createLogEntry(level: .debug, message: "1"))
        buffer.append(createLogEntry(level: .debug, message: "2"))
        buffer.append(createLogEntry(level: .error, message: "3"))
        
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
