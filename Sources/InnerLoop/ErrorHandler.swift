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

/// Error handler for catching and reporting errors
public class ErrorHandler {
    public static let shared = ErrorHandler()
    
    private var configuration: InnerLoopConfiguration?
    private let queue = DispatchQueue(label: "com.innerloop.errorhandler", qos: .utility)
    
    private init() {}
    
    /// Configure the error handler
    public func configure(with configuration: InnerLoopConfiguration) {
        self.configuration = configuration
    }
    
    /// Report an error
    public func report(error: Error, additionalInfo: [String: String] = [:]) {
        guard let configuration = configuration else {
            fputs("InnerLoop: ErrorHandler not configured. Call configure(with:) before reporting errors.\n", stderr)
            return
        }
        
        let errorMessage = error.localizedDescription
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        
        let metadata = buildMetadata(from: configuration, additionalInfo: additionalInfo)
        
        let errorInfo = ErrorInfo(
            message: errorMessage,
            stackTrace: stackTrace,
            timestamp: Date(),
            environment: configuration.environment,
            appVersion: configuration.appVersion,
            metadata: metadata
        )
        
        // Log to stderr to avoid circular dependency with Logger
        fputs("InnerLoop: Error reported: \(errorMessage)\n", stderr)
        
        // Send to remote endpoint if configured
        if let urlString = configuration.errorReportingURI,
           let url = URL(string: urlString) {
            sendErrorReport(errorInfo: errorInfo, to: url, headers: configuration.customHeaders)
        }
    }
    
    /// Report an error with a custom message
    public func report(message: String, additionalInfo: [String: String] = [:]) {
        guard let configuration = configuration else {
            fputs("InnerLoop: ErrorHandler not configured. Call configure(with:) before reporting errors.\n", stderr)
            return
        }
        
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        
        let metadata = buildMetadata(from: configuration, additionalInfo: additionalInfo)
        
        let errorInfo = ErrorInfo(
            message: message,
            stackTrace: stackTrace,
            timestamp: Date(),
            environment: configuration.environment,
            appVersion: configuration.appVersion,
            metadata: metadata
        )
        
        // Log to stderr to avoid circular dependency with Logger
        fputs("InnerLoop: Error reported: \(message)\n", stderr)
        
        // Send to remote endpoint if configured
        if let urlString = configuration.errorReportingURI,
           let url = URL(string: urlString) {
            sendErrorReport(errorInfo: errorInfo, to: url, headers: configuration.customHeaders)
        }
    }
    
    /// Build metadata dictionary from configuration and additional info
    private func buildMetadata(from configuration: InnerLoopConfiguration, additionalInfo: [String: String]) -> [String: String] {
        var metadata = additionalInfo
        
        for (key, value) in configuration.metadata {
            if let stringValue = value as? String {
                metadata[key] = stringValue
            } else if let customStringConvertible = value as? CustomStringConvertible {
                metadata[key] = customStringConvertible.description
            } else {
                metadata[key] = "\(value)"
            }
        }
        
        return metadata
    }
    
    private func sendErrorReport(errorInfo: ErrorInfo, to url: URL, headers: [String: String]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(errorInfo)
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = jsonData
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Add custom headers
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        fputs("InnerLoop: Failed to send error report: \(error.localizedDescription)\n", stderr)
                    } else if let httpResponse = response as? HTTPURLResponse {
                        if (200...299).contains(httpResponse.statusCode) {
                            fputs("InnerLoop: Error report sent successfully\n", stderr)
                        } else {
                            fputs("InnerLoop: Error report returned status code: \(httpResponse.statusCode)\n", stderr)
                        }
                    }
                }
                task.resume()
            } catch {
                fputs("InnerLoop: Failed to encode error report: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}
