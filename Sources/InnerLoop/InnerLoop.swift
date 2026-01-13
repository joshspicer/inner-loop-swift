import UIKit

/// Main InnerLoop class for easy integration
public class InnerLoop {
    public static let shared = InnerLoop()
    
    private var configuration: InnerLoopConfiguration?
    
    /// Logger instance
    public var logger: Logger {
        return Logger.shared
    }
    
    /// Error handler instance
    public var errorHandler: ErrorHandler {
        return ErrorHandler.shared
    }
    
    /// Shake gesture detector instance
    public var shakeGestureDetector: ShakeGestureDetector {
        return ShakeGestureDetector.shared
    }
    
    private init() {}
    
    /// Initialize InnerLoop with configuration
    /// - Parameter configuration: InnerLoopConfiguration object
    public func initialize(with configuration: InnerLoopConfiguration) {
        self.configuration = configuration

        // Configure error handler
        errorHandler.configure(with: configuration)

        // Configure log batcher
        LogBatcher.shared.configure(
            with: configuration,
            maxBufferSize: configuration.maxBufferSize,
            batchInterval: configuration.batchInterval
        )

        // Enable shake gesture if configured
        if configuration.enableShakeGesture {
            shakeGestureDetector.enable()
        }

        logger.info("InnerLoop initialized with environment: \(configuration.environment)", category: "InnerLoop")
    }
    
    /// Convenience method to log debug messages
    public func debug(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug(message, category: category, file: file, function: function, line: line)
    }
    
    /// Convenience method to log debug messages with category as first parameter
    public func debug(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug(category, message, file: file, function: function, line: line)
    }
    
    /// Convenience method to log info messages
    public func info(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info(message, category: category, file: file, function: function, line: line)
    }
    
    /// Convenience method to log info messages with category as first parameter
    public func info(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info(category, message, file: file, function: function, line: line)
    }
    
    /// Convenience method to log warning messages
    public func warning(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning(message, category: category, file: file, function: function, line: line)
    }
    
    /// Convenience method to log warning messages with category as first parameter
    public func warning(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning(category, message, file: file, function: function, line: line)
    }
    
    /// Convenience method to log error messages
    public func error(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(message, category: category, file: file, function: function, line: line)
    }
    
    /// Convenience method to log error messages with category as first parameter
    public func error(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(category, message, file: file, function: function, line: line)
    }
    
    /// Report an error
    public func reportError(_ error: Error, additionalInfo: [String: String] = [:]) {
        errorHandler.report(error: error, additionalInfo: additionalInfo)
    }
    
    /// Report an error with a custom message
    public func reportError(message: String, additionalInfo: [String: String] = [:]) {
        errorHandler.report(message: message, additionalInfo: additionalInfo)
    }
}

/// UIWindow extension to handle shake gestures
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        InnerLoop.shared.shakeGestureDetector.handleMotion(motion, with: event)
    }
}
