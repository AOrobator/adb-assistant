import XCTest
@testable import ADBAssistant

final class LogParserTests: XCTestCase {
    
    func testParseValidLogLine() {
        let line = "01-28 15:42:01.234  1234  5678 D TestTag: This is a test message"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.level, .debug)
        XCTAssertEqual(entry?.tag, "TestTag")
        XCTAssertEqual(entry?.pid, 1234)
        XCTAssertEqual(entry?.tid, 5678)
        XCTAssertEqual(entry?.message, "This is a test message")
    }
    
    func testParseInfoLevel() {
        let line = "01-28 15:42:01.234  1234  5678 I InfoTag: Info message"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.level, .info)
    }
    
    func testParseErrorLevel() {
        let line = "01-28 15:42:01.234  1234  5678 E ErrorTag: Error message"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.level, .error)
    }
    
    func testParseWarningLevel() {
        let line = "01-28 15:42:01.234  1234  5678 W WarningTag: Warning message"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.level, .warning)
    }
    
    func testParseVerboseLevel() {
        let line = "01-28 15:42:01.234  1234  5678 V VerboseTag: Verbose message"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.level, .verbose)
    }
    
    func testParseFatalLevel() {
        let line = "01-28 15:42:01.234  1234  5678 F FatalTag: Fatal message"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.level, .fatal)
    }
    
    func testParseInvalidLine() {
        let line = "This is not a valid log line"
        
        let entry = LogParser.parseLine(line)
        
        // Should fallback to raw parsing
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.message, line)
    }
    
    func testParseEmptyLine() {
        let line = ""
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertNil(entry)
    }
    
    func testParseMultipleLines() {
        let text = """
        01-28 15:42:01.234  1234  5678 D Tag1: Message 1
        01-28 15:42:01.235  1234  5678 I Tag2: Message 2
        01-28 15:42:01.236  1234  5678 E Tag3: Message 3
        """
        
        let entries = LogParser.parseLines(text)
        
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].message, "Message 1")
        XCTAssertEqual(entries[1].message, "Message 2")
        XCTAssertEqual(entries[2].message, "Message 3")
    }
    
    func testParseMessageWithSpecialCharacters() {
        let line = "01-28 15:42:01.234  1234  5678 D Tag: Message with {special} [chars]"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.message, "Message with {special} [chars]")
    }
    
    func testParseMessageWithJSON() {
        let line = "01-28 15:42:01.234  1234  5678 D Tag: Response: {\"key\": \"value\"}"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertTrue(entry?.containsJSON ?? false)
    }

    func testParseLineWithInvalidDateFallsBackToRaw() {
        let line = "99-99 99:99:99.999  1234  5678 D Tag: Bad date"
        
        let entry = LogParser.parseLine(line)
        
        XCTAssertEqual(entry?.tag, "Unknown")
        XCTAssertEqual(entry?.message, line)
    }

    func testParseLogcatBeginningLine() {
        let line = "--------- beginning of main"
        let entry = LogParser.parseLine(line)
        XCTAssertEqual(entry?.tag, "Logcat")
        XCTAssertEqual(entry?.message, line)
    }
}
