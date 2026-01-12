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
        
        // Enable shake gesture if configured
        if configuration.enableShakeGesture {
            shakeGestureDetector.enable()
        }
        
        logger.info("InnerLoop initialized with environment: \(configuration.environment)")
    }
    
    /// Convenience method to log debug messages
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug(message, file: file, function: function, line: line)
    }
    
    /// Convenience method to log info messages
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info(message, file: file, function: function, line: line)
    }
    
    /// Convenience method to log warning messages
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning(message, file: file, function: function, line: line)
    }
    
    /// Convenience method to log error messages
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(message, file: file, function: function, line: line)
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
