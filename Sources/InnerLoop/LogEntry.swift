import Foundation

/// Individual log entry
public struct LogEntry: Codable {
    public let message: String
    public let level: String
    public let category: String?
    public let timestamp: Date
    public let file: String
    public let function: String
    public let line: Int

    enum CodingKeys: String, CodingKey {
        case message, level, category, timestamp, file, function, line
    }
}
