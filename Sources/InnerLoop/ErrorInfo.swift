import Foundation

/// Error information structure
public struct ErrorInfo: Codable {
    public let message: String
    public let stackTrace: String?
    public let timestamp: Date
    public let environment: String
    public let appVersion: String?
    public let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case message, stackTrace, timestamp, environment, appVersion, metadata
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(stackTrace, forKey: .stackTrace)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(environment, forKey: .environment)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encode(metadata, forKey: .metadata)
    }
}
