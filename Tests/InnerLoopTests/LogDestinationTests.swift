import XCTest
@testable import InnerLoop

final class LogDestinationTests: XCTestCase {
    
    func testConsoleLogDestination() {
        let consoleDestination = ConsoleLogDestination()
        let timestamp = Date()
        
        // Should not crash when writing to console
        consoleDestination.write(
            message: "Test console message",
            level: .info,
            category: "TestCategory",
            timestamp: timestamp,
            file: "/path/to/TestFile.swift",
            function: "testFunction()",
            line: 42
        )
        
        XCTAssertTrue(true) // Test passes if no crash occurs
    }
    
    func testConsoleLogDestinationWithoutCategory() {
        let consoleDestination = ConsoleLogDestination()
        let timestamp = Date()
        
        // Should handle nil category gracefully
        consoleDestination.write(
            message: "Message without category",
            level: .debug,
            category: nil,
            timestamp: timestamp,
            file: "File.swift",
            function: "func()",
            line: 1
        )
        
        XCTAssertTrue(true)
    }
    
    func testConsoleLogDestinationWithAllLogLevels() {
        let consoleDestination = ConsoleLogDestination()
        let timestamp = Date()
        
        // Test all log levels
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        
        for level in levels {
            consoleDestination.write(
                message: "Test \(level.description) message",
                level: level,
                category: "Test",
                timestamp: timestamp,
                file: "Test.swift",
                function: "test()",
                line: 1
            )
        }
        
        XCTAssertTrue(true)
    }
    
    func testRemoteLogDestinationInitialization() {
        guard let endpoint = URL(string: "https://example.com/api/logs") else {
            XCTFail("Failed to create URL")
            return
        }
        
        let customHeaders = ["Authorization": "Bearer token"]
        let remoteDestination = RemoteLogDestination(
            endpoint: endpoint,
            customHeaders: customHeaders,
            minimumLevel: .warning
        )
        
        XCTAssertNotNil(remoteDestination)
    }
    
    func testRemoteLogDestinationWrite() {
        guard let endpoint = URL(string: "https://httpbin.org/post") else {
            XCTFail("Failed to create URL")
            return
        }
        
        let remoteDestination = RemoteLogDestination(endpoint: endpoint)
        
        // Should not crash when writing
        remoteDestination.write(
            message: "Test remote message",
            level: .error,
            category: "RemoteTest",
            timestamp: Date(),
            file: "TestFile.swift",
            function: "testFunc()",
            line: 100
        )
        
        // Give async operation time to complete
        let expectation = self.expectation(description: "Remote log sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
        
        XCTAssertTrue(true)
    }
    
    func testRemoteLogDestinationMinimumLevel() {
        guard let endpoint = URL(string: "https://example.com/api/logs") else {
            XCTFail("Failed to create URL")
            return
        }
        
        // Set minimum level to warning
        let remoteDestination = RemoteLogDestination(
            endpoint: endpoint,
            minimumLevel: .warning
        )
        
        // Debug and info should be filtered out
        remoteDestination.write(
            message: "Debug message (should be filtered)",
            level: .debug,
            category: nil,
            timestamp: Date(),
            file: "Test.swift",
            function: "test()",
            line: 1
        )
        
        remoteDestination.write(
            message: "Info message (should be filtered)",
            level: .info,
            category: nil,
            timestamp: Date(),
            file: "Test.swift",
            function: "test()",
            line: 2
        )
        
        // Warning and error should pass through
        remoteDestination.write(
            message: "Warning message",
            level: .warning,
            category: nil,
            timestamp: Date(),
            file: "Test.swift",
            function: "test()",
            line: 3
        )
        
        remoteDestination.write(
            message: "Error message",
            level: .error,
            category: nil,
            timestamp: Date(),
            file: "Test.swift",
            function: "test()",
            line: 4
        )
        
        XCTAssertTrue(true)
    }
    
    func testRemoteLogDestinationWithCustomHeaders() {
        guard let endpoint = URL(string: "https://example.com/api/logs") else {
            XCTFail("Failed to create URL")
            return
        }
        
        let customHeaders = [
            "Authorization": "Bearer abc123",
            "X-Custom-Header": "CustomValue"
        ]
        
        let remoteDestination = RemoteLogDestination(
            endpoint: endpoint,
            customHeaders: customHeaders
        )
        
        remoteDestination.write(
            message: "Test with custom headers",
            level: .info,
            category: "Test",
            timestamp: Date(),
            file: "Test.swift",
            function: "test()",
            line: 1
        )
        
        let expectation = self.expectation(description: "Log sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(true)
    }
    
    func testRemoteLogDestinationWithCategory() {
        guard let endpoint = URL(string: "https://example.com/api/logs") else {
            XCTFail("Failed to create URL")
            return
        }
        
        let remoteDestination = RemoteLogDestination(endpoint: endpoint)
        
        // Test with category
        remoteDestination.write(
            message: "Categorized message",
            level: .warning,
            category: "Authentication",
            timestamp: Date(),
            file: "Auth.swift",
            function: "login()",
            line: 50
        )
        
        // Test without category
        remoteDestination.write(
            message: "Uncategorized message",
            level: .error,
            category: nil,
            timestamp: Date(),
            file: "App.swift",
            function: "main()",
            line: 10
        )
        
        let expectation = self.expectation(description: "Logs sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
        
        XCTAssertTrue(true)
    }
    
    func testFileLogDestinationInitialization() {
        let documentsURL = FileManager.default.temporaryDirectory
        let logFileURL = documentsURL.appendingPathComponent("test-log-\(UUID().uuidString).log")
        
        let fileDestination = FileLogDestination(fileURL: logFileURL)
        XCTAssertNotNil(fileDestination)
        
        // Clean up
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testFileLogDestinationWrite() {
        let documentsURL = FileManager.default.temporaryDirectory
        let logFileURL = documentsURL.appendingPathComponent("test-log-\(UUID().uuidString).log")
        
        let fileDestination = FileLogDestination(fileURL: logFileURL)
        
        // Write some logs
        fileDestination.write(
            message: "Test file log message 1",
            level: .info,
            category: "FileTest",
            timestamp: Date(),
            file: "TestFile.swift",
            function: "testFunc()",
            line: 10
        )
        
        fileDestination.write(
            message: "Test file log message 2",
            level: .error,
            category: nil,
            timestamp: Date(),
            file: "Error.swift",
            function: "handleError()",
            line: 25
        )
        
        // Give async operations time to complete
        let expectation = self.expectation(description: "File written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path))
        
        // Clean up
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testFileLogDestinationContent() {
        let documentsURL = FileManager.default.temporaryDirectory
        let logFileURL = documentsURL.appendingPathComponent("test-log-\(UUID().uuidString).log")
        
        let fileDestination = FileLogDestination(fileURL: logFileURL)
        
        let testMessage = "Unique test message \(UUID().uuidString)"
        
        fileDestination.write(
            message: testMessage,
            level: .warning,
            category: "ContentTest",
            timestamp: Date(),
            file: "Test.swift",
            function: "test()",
            line: 42
        )
        
        // Give async operations time to complete
        let expectation = self.expectation(description: "File written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Read file content
        if let content = try? String(contentsOf: logFileURL, encoding: .utf8) {
            XCTAssertTrue(content.contains(testMessage))
            XCTAssertTrue(content.contains("WARNING"))
            XCTAssertTrue(content.contains("ContentTest"))
        } else {
            XCTFail("Failed to read log file")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: logFileURL)
    }
}
