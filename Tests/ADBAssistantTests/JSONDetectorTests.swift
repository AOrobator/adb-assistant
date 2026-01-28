import XCTest
@testable import ADBAssistant

final class JSONDetectorTests: XCTestCase {
    
    func testContainsJSONObject() {
        let text = "Response: {\"name\": \"test\", \"value\": 123}"
        
        XCTAssertTrue(JSONDetector.containsJSON(text))
    }
    
    func testContainsJSONArray() {
        let text = "Items: [1, 2, 3, 4, 5]"
        
        XCTAssertTrue(JSONDetector.containsJSON(text))
    }
    
    func testContainsNestedJSON() {
        let text = "Data: {\"user\": {\"id\": 1, \"name\": \"John\"}}"
        
        XCTAssertTrue(JSONDetector.containsJSON(text))
    }
    
    func testNoJSON() {
        let text = "This is just a plain text message"
        
        XCTAssertFalse(JSONDetector.containsJSON(text))
    }
    
    func testInvalidJSON() {
        let text = "Invalid: {name: test, value: 123}"
        
        XCTAssertFalse(JSONDetector.containsJSON(text))
    }
    
    func testExtractJSONObject() {
        let text = "Response: {\"key\": \"value\"}"
        
        let json = JSONDetector.extractJSON(from: text)
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json, "{\"key\": \"value\"}")
    }
    
    func testExtractJSONArray() {
        let text = "Items: [1, 2, 3]"
        
        let json = JSONDetector.extractJSON(from: text)
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json, "[1, 2, 3]")
    }
    
    func testPrettyPrintJSON() {
        let jsonString = "{\"name\":\"test\",\"value\":123}"
        
        let pretty = JSONDetector.prettyPrintJSON(jsonString)
        
        XCTAssertNotNil(pretty)
        XCTAssertTrue(pretty?.contains("\n") ?? false)
        XCTAssertTrue(pretty?.contains("\"name\"") ?? false)
    }
    
    func testPrettyPrintInvalidJSON() {
        let jsonString = "not valid json"
        
        let pretty = JSONDetector.prettyPrintJSON(jsonString)
        
        XCTAssertNil(pretty)
    }
    
    func testJSONWithEscapedQuotes() {
        let text = "Message: {\"content\": \"He said \\\"hello\\\"\"}"
        
        XCTAssertTrue(JSONDetector.containsJSON(text))
    }
    
    func testMultipleJSONObjects() {
        let text = "First: {\"a\": 1} Second: {\"b\": 2}"
        
        // Should find the first JSON object
        let json = JSONDetector.extractJSON(from: text)
        XCTAssertNotNil(json)
    }
}
