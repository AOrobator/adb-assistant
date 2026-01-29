import XCTest
@testable import ADBAssistant

final class LogStreamParserTests: XCTestCase {
    func testParseEmptyDataReturnsEmpty() {
        var parser = LogStreamParser()
        let entries = parser.parse(Data())
        XCTAssertTrue(entries.isEmpty)
    }

    func testParseFullLinesInSingleChunk() {
        var parser = LogStreamParser()
        let chunk = "01-28 15:42:01.234  1234  5678 D Tag: Hello\n01-28 15:42:01.235  1234  5678 I Tag: World\n"
        let entries = parser.parse(Data(chunk.utf8))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.message, "Hello")
        XCTAssertEqual(entries.last?.message, "World")
    }

    func testParsePartialLineAcrossChunks() {
        var parser = LogStreamParser()
        let part1 = "01-28 15:42:01.234  1234  5678 D Tag: Hel"
        let part2 = "lo\n01-28 15:42:01.235  1234  5678 I Tag: Done\n"

        let entries1 = parser.parse(Data(part1.utf8))
        XCTAssertTrue(entries1.isEmpty)

        let entries2 = parser.parse(Data(part2.utf8))
        XCTAssertEqual(entries2.count, 2)
        XCTAssertEqual(entries2.first?.message, "Hello")
        XCTAssertEqual(entries2.last?.message, "Done")
    }

    func testParseTrailingNewlineClearsPending() {
        var parser = LogStreamParser()
        let chunk = "01-28 15:42:01.234  1234  5678 W Tag: Done\n"
        let entries = parser.parse(Data(chunk.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.level, .warning)

        let empty = parser.parse(Data("\n".utf8))
        XCTAssertTrue(empty.isEmpty)
    }
}
