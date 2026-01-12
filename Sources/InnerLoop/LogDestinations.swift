import Foundation

/// Remote log destination that sends logs to a server
public class RemoteLogDestination: LogDestination {
    private let endpoint: URL
    private let customHeaders: [String: String]
    private let queue = DispatchQueue(label: "com.innerloop.remotelogger", qos: .utility)
    private let minimumLevel: LogLevel
    
    public init(endpoint: URL, customHeaders: [String: String] = [:], minimumLevel: LogLevel = .info) {
        self.endpoint = endpoint
        self.customHeaders = customHeaders
        self.minimumLevel = minimumLevel
    }
    
    public func write(message: String, level: LogLevel, timestamp: Date, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let logEntry: [String: Any] = [
                "message": message,
                "level": level.description,
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "file": (file as NSString).lastPathComponent,
                "function": function,
                "line": line
            ]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: logEntry)
                
                var request = URLRequest(url: self.endpoint)
                request.httpMethod = "POST"
                request.httpBody = jsonData
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Add custom headers
                for (key, value) in self.customHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                
                let task = URLSession.shared.dataTask(with: request) { _, response, error in
                    if let error = error {
                        // Use stderr for internal errors to avoid circular dependency
                        fputs("InnerLoop: Failed to send log to remote: \(error.localizedDescription)\n", stderr)
                    } else if let httpResponse = response as? HTTPURLResponse,
                              !(200...299).contains(httpResponse.statusCode) {
                        fputs("InnerLoop: Remote log returned status code: \(httpResponse.statusCode)\n", stderr)
                    }
                }
                task.resume()
            } catch {
                fputs("InnerLoop: Failed to encode log entry: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}

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
    
    public func write(message: String, level: LogLevel, timestamp: Date, file: String, function: String, line: Int) {
        queue.async { [weak self] in
            guard let self = self, let fileHandle = self.fileHandle else { return }
            
            let timeString = self.dateFormatter.string(from: timestamp)
            let filename = (file as NSString).lastPathComponent
            let logLine = "[\(timeString)] [\(level.description)] [\(filename):\(line)] \(function) - \(message)\n"
            
            if let data = logLine.data(using: .utf8) {
                fileHandle.write(data)
            }
        }
    }
}
