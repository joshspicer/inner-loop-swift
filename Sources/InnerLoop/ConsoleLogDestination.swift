import Foundation

/// Console log destination
public class ConsoleLogDestination: LogDestination {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    public init() {}

    public func write(message: String, level: LogLevel, category: String?, timestamp: Date, file: String, function: String, line: Int) {
        let timeString = dateFormatter.string(from: timestamp)
        let filename = (file as NSString).lastPathComponent
        let categoryStr = category.map { "[\($0)] " } ?? ""
        print("[\(timeString)] [\(level.description)] \(categoryStr)[\(filename):\(line)] \(function) - \(message)")
    }
}
