import Foundation

/// File log destination that writes logs to a file
public class FileLogDestination: LogDestination {
    private let fileURL: URL
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.innerloop.filelogger", qos: .utility)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    public init(fileURL: URL) {
        self.fileURL = fileURL

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        self.fileHandle?.seekToEndOfFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    public func write(message: String, level: LogLevel, category: String?, timestamp: Date, file: String, function: String, line: Int) {
        queue.async { [weak self] in
            guard let self = self, let fileHandle = self.fileHandle else { return }

            let timeString = self.dateFormatter.string(from: timestamp)
            let filename = (file as NSString).lastPathComponent
            let categoryStr = category.map { "[\($0)] " } ?? ""
            let logLine = "[\(timeString)] [\(level.description)] \(categoryStr)[\(filename):\(line)] \(function) - \(message)\n"

            if let data = logLine.data(using: .utf8) {
                fileHandle.write(data)
            }
        }
    }
}
