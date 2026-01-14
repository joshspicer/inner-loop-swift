import Foundation

/// Configuration for InnerLoop
public struct InnerLoopConfiguration {
    /// The URI endpoint where errors and exceptions should be reported
    public var errorReportingURI: String?

    /// The URI endpoint where log batches should be sent (optional, defaults to derived from errorReportingURI)
    public var batchReportingURI: String?

    /// Application identifier (e.g., bundle ID for iOS apps) - optional
    public var appId: String?

    /// Shared secret for authentication with the server - optional
    public var sharedSecret: String?

    /// Enable device shake gesture for debugging
    public var enableShakeGesture: Bool

    /// Custom headers to include in error reports
    public var customHeaders: [String: String]

    /// Environment identifier (e.g., "development", "staging", "production")
    public var environment: String

    /// Application version
    public var appVersion: String?

    /// Additional metadata to include in error reports
    public var metadata: [String: Any]

    /// Maximum number of logs to buffer before sending (default: 1000)
    public var maxBufferSize: Int

    /// Time interval in seconds between automatic batch sends (default: 300 = 5 minutes)
    public var batchInterval: TimeInterval

    public init(
        errorReportingURI: String? = nil,
        batchReportingURI: String? = nil,
        appId: String? = nil,
        sharedSecret: String? = nil,
        enableShakeGesture: Bool = true,
        customHeaders: [String: String] = [:],
        environment: String = "development",
        appVersion: String? = nil,
        metadata: [String: Any] = [:],
        maxBufferSize: Int = 1000,
        batchInterval: TimeInterval = 300
    ) {
        self.errorReportingURI = errorReportingURI
        self.batchReportingURI = batchReportingURI
        self.appId = appId
        self.sharedSecret = sharedSecret
        self.enableShakeGesture = enableShakeGesture
        self.customHeaders = customHeaders
        self.environment = environment
        self.appVersion = appVersion
        self.metadata = metadata
        self.maxBufferSize = maxBufferSize
        self.batchInterval = batchInterval
    }
}
