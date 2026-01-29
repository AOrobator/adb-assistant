import Foundation

/// Parses ADB logcat output into structured LogEntry objects
public struct LogParser {
    
    /// Date formatter for logcat timestamps
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Parses a single logcat line in threadtime,uid format
    /// Format: MM-DD HH:MM:SS.mmm UID PID TID L TAG: message
    public static func parseLine(_ line: String) -> LogEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Handle "--------- beginning of ..." lines as special marker entries
        if trimmed.hasPrefix("---------") {
            return LogEntry(
                timestamp: Date(),
                level: .info,
                tag: "Logcat",
                uid: 0,
                pid: 0,
                tid: 0,
                message: trimmed,
                rawLine: trimmed
            )
        }

        // Try to parse threadtime,uid format: "01-28 15:42:01.234 10286  1234  5678 D Tag: message"
        // Format: DATE TIME UID PID TID LEVEL TAG: MESSAGE
        let pattern = "^(\\d{2}-\\d{2})\\s+(\\d{2}:\\d{2}:\\d{2}\\.\\d{3})\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+([VDIWEFS])\\s+([^:]+):\\s*(.*)$"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) else {
            // Fallback: try to parse as raw message
            return parseRawLine(trimmed)
        }

        let dateString = extractString(from: trimmed, range: match.range(at: 1)) + " " +
                        extractString(from: trimmed, range: match.range(at: 2))
        let uidString = extractString(from: trimmed, range: match.range(at: 3))
        let pidString = extractString(from: trimmed, range: match.range(at: 4))
        let tidString = extractString(from: trimmed, range: match.range(at: 5))
        let levelChar = extractString(from: trimmed, range: match.range(at: 6))
        let tag = extractString(from: trimmed, range: match.range(at: 7))
        let message = extractString(from: trimmed, range: match.range(at: 8))

        guard let timestamp = dateFormatter.date(from: dateString),
              let uid = Int(uidString),
              let pid = Int(pidString),
              let tid = Int(tidString),
              let level = LogLevel(character: levelChar.first ?? "V") else {
            return parseRawLine(trimmed)
        }

        return LogEntry(
            timestamp: timestamp,
            level: level,
            tag: tag,
            uid: uid,
            pid: pid,
            tid: tid,
            message: message,
            rawLine: trimmed
        )
    }
    
    /// Parses a raw line when structured parsing fails
    private static func parseRawLine(_ line: String) -> LogEntry {
        return LogEntry(
            timestamp: Date(),
            level: .info,
            tag: "Unknown",
            uid: 0,
            pid: 0,
            tid: 0,
            message: line,
            rawLine: line
        )
    }
    
    /// Extracts string from NSRange
    private static func extractString(from text: String, range: NSRange) -> String {
        guard let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }
    
    /// Parses multiple lines
    public static func parseLines(_ text: String) -> [LogEntry] {
        let lines = text.components(separatedBy: .newlines)
        return lines.compactMap { parseLine($0) }
    }
}
