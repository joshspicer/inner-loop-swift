import XCTest
@testable import InnerLoop

final class LoggerTests: XCTestCase {
    
    var logger: Logger!
    var testDestination: TestLogDestination!
    
    override func setUp() {
        super.setUp()
        logger = Logger.shared
        testDestination = TestLogDestination()
        
        // Use expectation to wait for configuration to complete
        let configExpectation = expectation(description: "Configuration complete")
        logger.configure(destinations: [testDestination], minimumLevel: .debug)
        
        // Give async operation time to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            configExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testLogLevelComparison() {
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }
    
    func testLogLevelDescription() {
        XCTAssertEqual(LogLevel.debug.description, "DEBUG")
        XCTAssertEqual(LogLevel.info.description, "INFO")
        XCTAssertEqual(LogLevel.warning.description, "WARNING")
        XCTAssertEqual(LogLevel.error.description, "ERROR")
    }
    
    func testDebugLogging() {
        logger.debug("Test debug message")
        
        // Give async operation time to complete
        let expectation = self.expectation(description: "Log written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(testDestination.lastLevel, .debug)
        XCTAssertEqual(testDestination.lastMessage, "Test debug message")
    }
    
    func testInfoLogging() {
        logger.info("Test info message")
        
        let expectation = self.expectation(description: "Log written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(testDestination.lastLevel, .info)
        XCTAssertEqual(testDestination.lastMessage, "Test info message")
    }
    
    func testWarningLogging() {
        logger.warning("Test warning message")
        
        let expectation = self.expectation(description: "Log written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(testDestination.lastLevel, .warning)
        XCTAssertEqual(testDestination.lastMessage, "Test warning message")
    }
    
    func testErrorLogging() {
        logger.error("Test error message")
        
        let expectation = self.expectation(description: "Log written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(testDestination.lastLevel, .error)
        XCTAssertEqual(testDestination.lastMessage, "Test error message")
    }
    
    func testMinimumLogLevel() {
        let setLevelExpectation = expectation(description: "Set level complete")
        logger.setMinimumLevel(.warning)
        
        // Wait for async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            setLevelExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        
        let expectation = self.expectation(description: "Log written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Only warning should have been logged
        XCTAssertEqual(testDestination.lastLevel, .warning)
        XCTAssertEqual(testDestination.lastMessage, "Warning message")
    }
    
    func testAddDestination() {
        let secondDestination = TestLogDestination()
        
        let addDestExpectation = expectation(description: "Add destination complete")
        logger.addDestination(secondDestination)
        
        // Wait for async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addDestExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        logger.info("Test message")
        
        let expectation = self.expectation(description: "Log written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Both destinations should have received the log
        XCTAssertEqual(testDestination.lastMessage, "Test message")
        XCTAssertEqual(secondDestination.lastMessage, "Test message")
    }
}

// Test log destination for testing
class TestLogDestination: LogDestination {
    var lastMessage: String?
    var lastLevel: LogLevel?
    var lastCategory: String?
    var lastTimestamp: Date?
    var lastFile: String?
    var lastFunction: String?
    var lastLine: Int?
    var writeCount = 0
    
    func write(message: String, level: LogLevel, category: String?, timestamp: Date, file: String, function: String, line: Int) {
        lastMessage = message
        lastLevel = level
        lastCategory = category
        lastTimestamp = timestamp
        lastFile = file
        lastFunction = function
        lastLine = line
        writeCount += 1
    }
}
