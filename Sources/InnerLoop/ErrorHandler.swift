import Foundation

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
        
        let metadata = MetadataUtil.buildMetadata(from: configuration, additionalInfo: additionalInfo)
        
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
        
        // Determine the URL to use (EndpointManager takes precedence)
        let reportURL: URL?
        if EndpointManager.shared.isEnabled, let dynamicURL = EndpointManager.shared.errorURL {
            reportURL = dynamicURL
        } else if let urlString = configuration.errorReportingURI {
            reportURL = URL(string: urlString)
        } else {
            reportURL = nil
        }
        
        // Send to remote endpoint if configured
        if let url = reportURL {
            var headers = configuration.customHeaders
            if let appId = configuration.appId {
                headers["X-App-Id"] = appId
            }
            if let sharedSecret = configuration.sharedSecret {
                headers["X-Shared-Secret"] = sharedSecret
            }
            sendErrorReport(errorInfo: errorInfo, to: url, headers: headers)
        }
    }
    
    /// Report an error with a custom message
    public func report(message: String, additionalInfo: [String: String] = [:]) {
        guard let configuration = configuration else {
            fputs("InnerLoop: ErrorHandler not configured. Call configure(with:) before reporting errors.\n", stderr)
            return
        }
        
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        
        let metadata = MetadataUtil.buildMetadata(from: configuration, additionalInfo: additionalInfo)
        
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
        
        // Determine the URL to use (EndpointManager takes precedence)
        let reportURL: URL?
        if EndpointManager.shared.isEnabled, let dynamicURL = EndpointManager.shared.errorURL {
            reportURL = dynamicURL
        } else if let urlString = configuration.errorReportingURI {
            reportURL = URL(string: urlString)
        } else {
            reportURL = nil
        }
        
        // Send to remote endpoint if configured
        if let url = reportURL {
            var headers = configuration.customHeaders
            if let appId = configuration.appId {
                headers["X-App-Id"] = appId
            }
            if let sharedSecret = configuration.sharedSecret {
                headers["X-Shared-Secret"] = sharedSecret
            }
            sendErrorReport(errorInfo: errorInfo, to: url, headers: headers)
        }
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
