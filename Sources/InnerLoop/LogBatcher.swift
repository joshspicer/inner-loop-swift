import Foundation

/// Batches logs and sends them periodically or on demand
public class LogBatcher {
    public static let shared = LogBatcher()

    private var configuration: InnerLoopConfiguration?
    private var logBuffer: [LogEntry] = []
    private let queue = DispatchQueue(label: "com.innerloop.logbatcher", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var maxBufferSize: Int = 1000
    private var batchInterval: TimeInterval = 300 // 5 minutes

    private init() {}

    /// Configure the log batcher
    public func configure(with configuration: InnerLoopConfiguration, maxBufferSize: Int = 1000, batchInterval: TimeInterval = 300) {
        self.configuration = configuration
        self.maxBufferSize = maxBufferSize
        self.batchInterval = batchInterval
        startTimer()
    }

    /// Add a log entry to the buffer
    public func addLog(message: String, level: LogLevel, category: String?, timestamp: Date, file: String, function: String, line: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let entry = LogEntry(
                message: message,
                level: level.description,
                category: category,
                timestamp: timestamp,
                file: (file as NSString).lastPathComponent,
                function: function,
                line: line
            )

            self.logBuffer.append(entry)

            // Send batch if buffer is full
            if self.logBuffer.count >= self.maxBufferSize {
                self.sendBatchInternal(userMessage: nil)
            }
        }
    }

    /// Send all buffered logs with optional user message
    public func sendBatch(userMessage: String? = nil) {
        queue.async { [weak self] in
            self?.sendBatchInternal(userMessage: userMessage)
        }
    }

    /// Get current buffer size
    public func getBufferSize() -> Int {
        var size = 0
        queue.sync {
            size = logBuffer.count
        }
        return size
    }

    /// Clear the buffer
    public func clearBuffer() {
        queue.async { [weak self] in
            self?.logBuffer.removeAll()
        }
    }

    private func startTimer() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.timer?.cancel()
            self.timer = DispatchSource.makeTimerSource(queue: self.queue)
            self.timer?.schedule(deadline: .now() + self.batchInterval, repeating: self.batchInterval)
            self.timer?.setEventHandler { [weak self] in
                self?.sendBatchInternal(userMessage: nil)
            }
            self.timer?.resume()
        }
    }

    private func sendBatchInternal(userMessage: String?) {
        guard let configuration = configuration else {
            return
        }

        // Only send if we have logs or a user message
        guard !logBuffer.isEmpty || userMessage != nil else {
            return
        }

        guard let urlString = configuration.errorReportingURI,
              let baseURL = URL(string: urlString) else {
            return
        }

        // Build batch endpoint URL
        let batchURL = baseURL.deletingLastPathComponent().appendingPathComponent("batch")

        let metadata = MetadataUtil.buildMetadata(from: configuration)

        let batch = LogBatch(
            logs: logBuffer,
            userMessage: userMessage,
            timestamp: Date(),
            environment: configuration.environment,
            appVersion: configuration.appVersion,
            metadata: metadata
        )

        // Clear buffer
        let logsCount = logBuffer.count
        logBuffer.removeAll()

        // Send batch
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(batch)

            var request = URLRequest(url: batchURL)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Add custom headers
            request.setValue(configuration.appId, forHTTPHeaderField: "X-App-Id")
            request.setValue(configuration.sharedSecret, forHTTPHeaderField: "X-Shared-Secret")
            for (key, value) in configuration.customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    fputs("InnerLoop: Failed to send log batch: \(error.localizedDescription)\n", stderr)
                } else if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        fputs("InnerLoop: Log batch sent successfully (\(logsCount) logs)\n", stderr)
                    } else {
                        fputs("InnerLoop: Log batch returned status code: \(httpResponse.statusCode)\n", stderr)
                    }
                }
            }
            task.resume()
        } catch {
            fputs("InnerLoop: Failed to encode log batch: \(error.localizedDescription)\n", stderr)
        }
    }

    deinit {
        timer?.cancel()
    }
}
