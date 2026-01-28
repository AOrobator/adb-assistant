import Foundation

/// Utility for detecting and extracting JSON from log messages
public struct JSONDetector {
    
    /// Checks if a string contains valid JSON
    public static func containsJSON(_ text: String) -> Bool {
        guard let jsonRange = findJSONRange(in: text) else {
            return false
        }
        
        let substring = String(text[jsonRange])
        return isValidJSON(substring)
    }
    
    /// Extracts JSON from a string if present
    public static func extractJSON(from text: String) -> String? {
        guard let jsonRange = findJSONRange(in: text) else {
            return nil
        }
        
        let substring = String(text[jsonRange])
        guard isValidJSON(substring) else {
            return nil
        }
        
        return substring
    }
    
    /// Pretty prints JSON if valid
    public static func prettyPrintJSON(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            )
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// Finds the range of JSON in a string (object or array)
    private static func findJSONRange(in text: String) -> Range<String.Index>? {
        // Look for JSON object start
        if let objectStart = text.firstIndex(of: "{"),
           let objectEnd = findMatchingBrace(in: text, from: objectStart, open: "{", close: "}") {
            return objectStart..<text.index(after: objectEnd)
        }
        
        // Look for JSON array start
        if let arrayStart = text.firstIndex(of: "["),
           let arrayEnd = findMatchingBrace(in: text, from: arrayStart, open: "[", close: "]") {
            return arrayStart..<text.index(after: arrayEnd)
        }
        
        return nil
    }
    
    /// Finds the matching closing brace/bracket
    private static func findMatchingBrace(
        in text: String,
        from start: String.Index,
        open: Character,
        close: Character
    ) -> String.Index? {
        var depth = 1
        var index = text.index(after: start)
        var inString = false
        var escaped = false
        
        while index < text.endIndex {
            let char = text[index]
            
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == open {
                    depth += 1
                } else if char == close {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            
            index = text.index(after: index)
        }
        
        return nil
    }
    
    /// Validates if a string is valid JSON
    private static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else {
            return false
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
}
