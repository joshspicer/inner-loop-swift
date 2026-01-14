import XCTest
@testable import InnerLoop

final class LogBatcherTests: XCTestCase {
    
    var logBatcher: LogBatcher!
    var testConfig: InnerLoopConfiguration!
    
    override func setUp() {
        super.setUp()
        logBatcher = LogBatcher.shared
        testConfig = InnerLoopConfiguration(
            errorReportingURI: "https://example.com/api/errors",
            appId: "test-app",
            sharedSecret: "test-secret",
            environment: "test",
            appVersion: "1.0.0"
        )
        
        // Clear any existing buffer
        logBatcher.clearBuffer()
        
        // Give async operation time to complete
        let clearExpectation = expectation(description: "Buffer cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            clearExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
    
    override func tearDown() {
        logBatcher.clearBuffer()
        super.tearDown()
    }
    
    func testLogBatcherConfiguration() {
        logBatcher.configure(with: testConfig, maxBufferSize: 500, batchInterval: 60)
        
        // Configuration should succeed without errors
        XCTAssertTrue(true)
    }
    
    func testAddLogEntry() {
        logBatcher.configure(with: testConfig)
        
        logBatcher.addLog(
            message: "Test log message",
            level: .info,
            category: "Test",
            timestamp: Date(),
            file: "TestFile.swift",
            function: "testFunction",
            line: 42
        )
        
        // Give async operation time to complete
        let expectation = self.expectation(description: "Log added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        let bufferSize = logBatcher.getBufferSize()
        XCTAssertEqual(bufferSize, 1)
    }
    
    func testGetBufferSize() {
        logBatcher.configure(with: testConfig)
        
        // Initially should be 0
        XCTAssertEqual(logBatcher.getBufferSize(), 0)
        
        // Add a log
        logBatcher.addLog(
            message: "Test message",
            level: .debug,
            category: nil,
            timestamp: Date(),
            file: "Test.swift",
            function: "test",
            line: 1
        )
        
        let expectation = self.expectation(description: "Log added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(logBatcher.getBufferSize(), 1)
    }
    
    func testGetLogs() {
        logBatcher.configure(with: testConfig)
        
        let testMessage = "Test log for retrieval"
        logBatcher.addLog(
            message: testMessage,
            level: .warning,
            category: "TestCategory",
            timestamp: Date(),
            file: "TestFile.swift",
            function: "testFunc",
            line: 10
        )
        
        let expectation = self.expectation(description: "Log added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        let logs = logBatcher.getLogs()
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.message, testMessage)
        XCTAssertEqual(logs.first?.level, "WARNING")
        XCTAssertEqual(logs.first?.category, "TestCategory")
    }
    
    func testClearBuffer() {
        logBatcher.configure(with: testConfig)
        
        // Add some logs
        for i in 1...5 {
            logBatcher.addLog(
                message: "Log \(i)",
                level: .info,
                category: nil,
                timestamp: Date(),
                file: "Test.swift",
                function: "test",
                line: i
            )
        }
        
        let addExpectation = expectation(description: "Logs added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            addExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(logBatcher.getBufferSize(), 5)
        
        // Clear buffer
        logBatcher.clearBuffer()
        
        let clearExpectation = expectation(description: "Buffer cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            clearExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(logBatcher.getBufferSize(), 0)
    }
    
    func testMultipleLogEntries() {
        logBatcher.configure(with: testConfig, maxBufferSize: 100)
        
        let logCount = 10
        for i in 1...logCount {
            logBatcher.addLog(
                message: "Log entry \(i)",
                level: .debug,
                category: "Test",
                timestamp: Date(),
                file: "TestFile.swift",
                function: "testFunction",
                line: i
            )
        }
        
        let expectation = self.expectation(description: "Logs added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(logBatcher.getBufferSize(), logCount)
        
        let logs = logBatcher.getLogs()
        XCTAssertEqual(logs.count, logCount)
    }
    
    func testLogEntryFormat() {
        logBatcher.configure(with: testConfig)
        
        let timestamp = Date()
        let testMessage = "Formatted log message"
        let testFile = "/path/to/TestFile.swift"
        
        logBatcher.addLog(
            message: testMessage,
            level: .error,
            category: "ErrorCategory",
            timestamp: timestamp,
            file: testFile,
            function: "testMethod",
            line: 99
        )
        
        let expectation = self.expectation(description: "Log added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        let logs = logBatcher.getLogs()
        guard let log = logs.first else {
            XCTFail("No log entry found")
            return
        }
        
        XCTAssertEqual(log.message, testMessage)
        XCTAssertEqual(log.level, "ERROR")
        XCTAssertEqual(log.category, "ErrorCategory")
        XCTAssertEqual(log.file, "TestFile.swift") // Should extract just filename
        XCTAssertEqual(log.function, "testMethod")
        XCTAssertEqual(log.line, 99)
    }
    
    func testLogEntryCodable() throws {
        let timestamp = Date()
        let logEntry = LogEntry(
            message: "Test message",
            level: "INFO",
            category: "Test",
            timestamp: timestamp,
            file: "Test.swift",
            function: "testFunc",
            line: 42
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(logEntry)
        XCTAssertGreaterThan(jsonData.count, 0)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decodedEntry = try decoder.decode(LogEntry.self, from: jsonData)
        XCTAssertEqual(decodedEntry.message, logEntry.message)
        XCTAssertEqual(decodedEntry.level, logEntry.level)
        XCTAssertEqual(decodedEntry.category, logEntry.category)
        XCTAssertEqual(decodedEntry.file, logEntry.file)
        XCTAssertEqual(decodedEntry.function, logEntry.function)
        XCTAssertEqual(decodedEntry.line, logEntry.line)
    }
    
    func testLogBatchCodable() throws {
        let timestamp = Date()
        let logEntry = LogEntry(
            message: "Batch test",
            level: "DEBUG",
            category: nil,
            timestamp: timestamp,
            file: "Test.swift",
            function: "test",
            line: 1
        )
        
        let batch = LogBatch(
            logs: [logEntry],
            userMessage: "Test batch message",
            timestamp: timestamp,
            environment: "test",
            appVersion: "1.0.0",
            metadata: ["device": "iPhone"]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(batch)
        XCTAssertGreaterThan(jsonData.count, 0)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decodedBatch = try decoder.decode(LogBatch.self, from: jsonData)
        XCTAssertEqual(decodedBatch.logs.count, 1)
        XCTAssertEqual(decodedBatch.userMessage, batch.userMessage)
        XCTAssertEqual(decodedBatch.environment, batch.environment)
        XCTAssertEqual(decodedBatch.appVersion, batch.appVersion)
        XCTAssertEqual(decodedBatch.metadata["device"], "iPhone")
    }
    
    func testSendBatchWithoutConfiguration() {
        // Don't configure logBatcher
        logBatcher.addLog(
            message: "Test",
            level: .info,
            category: nil,
            timestamp: Date(),
            file: "Test.swift",
            function: "test",
            line: 1
        )
        
        let expectation = self.expectation(description: "Log added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Should not crash when trying to send without configuration
        logBatcher.sendBatch(userMessage: "Test message")
        
        let sendExpectation = expectation(description: "Send attempted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sendExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(true)
    }
}
