import Foundation

/// Represents a single log entry from ADB logcat
public struct LogEntry: Identifiable, Equatable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let tag: String
    public let pid: Int
    public let tid: Int
    public let message: String
    public let rawLine: String
    
    /// Computed property to detect if message contains JSON
    public var containsJSON: Bool {
        JSONDetector.containsJSON(message)
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        level: LogLevel,
        tag: String,
        pid: Int,
        tid: Int,
        message: String,
        rawLine: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.tag = tag
        self.pid = pid
        self.tid = tid
        self.message = message
        self.rawLine = rawLine
    }
}

/// Log levels matching Android's logcat
public enum LogLevel: Int, CaseIterable, Codable, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case fatal = 5
    case silent = 6
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Character representation used by logcat
    public var character: String {
        switch self {
        case .verbose: return "V"
        case .debug: return "D"
        case .info: return "I"
        case .warning: return "W"
        case .error: return "E"
        case .fatal: return "F"
        case .silent: return "S"
        }
    }
    
    /// Parse from logcat character
    public init?(character: Character) {
        switch character {
        case "V": self = .verbose
        case "D": self = .debug
        case "I": self = .info
        case "W": self = .warning
        case "E": self = .error
        case "F": self = .fatal
        case "S": self = .silent
        default: return nil
        }
    }
}

/// Device information
public struct Device: Identifiable, Equatable, Codable {
    public let id: String
    public let serial: String
    public let model: String?
    public let status: DeviceStatus
    
    public init(serial: String, model: String? = nil, status: DeviceStatus = .unknown) {
        self.id = serial
        self.serial = serial
        self.model = model
        self.status = status
    }
}

public enum DeviceStatus: String, Codable {
    case connected = "device"
    case offline = "offline"
    case unauthorized = "unauthorized"
    case unknown = "unknown"
}
