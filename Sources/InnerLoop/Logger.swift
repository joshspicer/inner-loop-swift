import Foundation

/// Generic Logger for InnerLoop
public class Logger {
    public static let shared = Logger()
    
    private var destinations: [LogDestination] = []
    private var minimumLevel: LogLevel = .debug
    private let queue = DispatchQueue(label: "com.innerloop.logger", qos: .utility)
    
    private init() {
        // Default to console logging
        destinations.append(ConsoleLogDestination())
    }
    
    /// Configure the logger with custom destinations
    /// - Parameters:
    ///   - destinations: Array of log destinations
    ///   - minimumLevel: Minimum log level to output
    /// - Note: This method uses async dispatch and is thread-safe
    public func configure(destinations: [LogDestination], minimumLevel: LogLevel = .debug) {
        queue.async { [weak self] in
            self?.destinations = destinations
            self?.minimumLevel = minimumLevel
        }
    }
    
    /// Add a log destination
    /// - Parameter destination: The log destination to add
    /// - Note: This method uses async dispatch and is thread-safe
    public func addDestination(_ destination: LogDestination) {
        queue.async { [weak self] in
            self?.destinations.append(destination)
        }
    }
    
    /// Set minimum log level
    /// - Parameter level: The minimum log level to output
    /// - Note: This method uses async dispatch and is thread-safe
    public func setMinimumLevel(_ level: LogLevel) {
        queue.async { [weak self] in
            self?.minimumLevel = level
        }
    }
    
    /// Log a debug message
    public func debug(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log a debug message with category as first parameter (for backward compatibility)
    public func debug(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message
    public func info(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message with category as first parameter (for backward compatibility)
    public func info(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    public func warning(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message with category as first parameter (for backward compatibility)
    public func warning(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    public func error(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message with category as first parameter (for backward compatibility)
    public func error(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    private func log(message: String, level: LogLevel, category: String?, file: String, function: String, line: Int) {
        let timestamp = Date()

        queue.async { [weak self] in
            guard let self = self else { return }

            // Check minimum level on the serial queue to ensure thread safety
            guard level >= self.minimumLevel else { return }

            self.destinations.forEach { destination in
                destination.write(message: message, level: level, category: category, timestamp: timestamp, file: file, function: function, line: line)
            }

            // Add to batch buffer for all log levels to collect context
            LogBatcher.shared.addLog(message: message, level: level, category: category, timestamp: timestamp, file: file, function: function, line: line)
        }
    }
}
