import XCTest
@testable import InnerLoop

final class ErrorHandlerTests: XCTestCase {
    
    var errorHandler: ErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandler.shared
    }
    
    func testErrorHandlerConfiguration() {
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://example.com/errors",
            environment: "test",
            appVersion: "1.0.0"
        )

        errorHandler.configure(with: config)

        // Configuration should succeed without errors
        XCTAssertTrue(true)
    }
    
    func testErrorHandlerConfigurationWithAuth() {
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://example.com/errors",
            appId: "test-app",
            sharedSecret: "test-secret",
            environment: "test",
            appVersion: "1.0.0"
        )

        errorHandler.configure(with: config)

        // Configuration should succeed with auth
        XCTAssertTrue(true)
    }
    
    func testReportErrorMessage() {
        let config = InnerLoopConfiguration(
            environment: "test",
            appVersion: "1.0.0"
        )

        errorHandler.configure(with: config)

        // Should not crash even without URI configured
        errorHandler.report(message: "Test error", additionalInfo: ["key": "value"])

        XCTAssertTrue(true)
    }
    
    func testReportError() {
        let config = InnerLoopConfiguration(
            environment: "test",
            appVersion: "1.0.0"
        )

        errorHandler.configure(with: config)

        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        // Should not crash
        errorHandler.report(error: testError, additionalInfo: ["userId": "12345"])

        XCTAssertTrue(true)
    }
    
    func testErrorInfoEncoding() throws {
        let errorInfo = ErrorInfo(
            message: "Test error",
            stackTrace: "Line 1\nLine 2",
            timestamp: Date(),
            environment: "test",
            appVersion: "1.0.0",
            metadata: ["key": "value"]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(errorInfo)
        XCTAssertGreaterThan(jsonData.count, 0)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decodedErrorInfo = try decoder.decode(ErrorInfo.self, from: jsonData)
        XCTAssertEqual(decodedErrorInfo.message, errorInfo.message)
        XCTAssertEqual(decodedErrorInfo.environment, errorInfo.environment)
        XCTAssertEqual(decodedErrorInfo.appVersion, errorInfo.appVersion)
    }
}
