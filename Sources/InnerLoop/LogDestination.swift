import Foundation

/// Protocol for log destinations
public protocol LogDestination {
    func write(message: String, level: LogLevel, timestamp: Date, file: String, function: String, line: Int)
}
