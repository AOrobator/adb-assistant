import XCTest
@testable import ADBAssistant

final class JSONDetectorAdditionalTests: XCTestCase {
    func testExtractJSONReturnsNilWhenUnmatchedBrace() {
        let text = "Broken: {\"key\": 1"
        XCTAssertNil(JSONDetector.extractJSON(from: text))
        XCTAssertFalse(JSONDetector.containsJSON(text))
    }

    func testContainsJSONIgnoresBracesInStrings() {
        let text = "Message: {\"text\": \"value with } brace\"}"
        XCTAssertTrue(JSONDetector.containsJSON(text))
    }

    func testExtractJSONArrayWhenNoObjectPresent() {
        let text = "Array only: [1, 2, 3]"
        XCTAssertEqual(JSONDetector.extractJSON(from: text), "[1, 2, 3]")
    }
}
