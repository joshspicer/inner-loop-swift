import Foundation

/// Batch information for logs and errors
public struct LogBatch: Codable {
    public let logs: [LogEntry]
    public let userMessage: String?
    public let timestamp: Date
    public let environment: String
    public let appVersion: String?
    public let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case logs, userMessage, timestamp, environment, appVersion, metadata
    }
}
