import XCTest
@testable import InnerLoop

final class ConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = InnerLoopConfiguration()

        XCTAssertNil(config.errorReportingURI)
        XCTAssertNil(config.batchReportingURI)
        XCTAssertNil(config.appId)
        XCTAssertNil(config.sharedSecret)
        XCTAssertTrue(config.enableShakeGesture)
        XCTAssertEqual(config.customHeaders.count, 0)
        XCTAssertEqual(config.environment, "development")
        XCTAssertNil(config.appVersion)
        XCTAssertEqual(config.metadata.count, 0)
        XCTAssertEqual(config.maxBufferSize, 1000)
        XCTAssertEqual(config.batchInterval, 300)
    }
    
    func testCustomConfiguration() {
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://example.com/errors",
            batchReportingURI: "https://example.com/batch",
            appId: "test-app",
            sharedSecret: "test-secret",
            enableShakeGesture: false,
            customHeaders: ["Authorization": "Bearer token"],
            environment: "production",
            appVersion: "1.0.0",
            metadata: ["userId": "12345"],
            maxBufferSize: 2000,
            batchInterval: 600
        )

        XCTAssertEqual(config.errorReportingURI, "https://example.com/errors")
        XCTAssertEqual(config.batchReportingURI, "https://example.com/batch")
        XCTAssertEqual(config.appId, "test-app")
        XCTAssertEqual(config.sharedSecret, "test-secret")
        XCTAssertFalse(config.enableShakeGesture)
        XCTAssertEqual(config.customHeaders["Authorization"], "Bearer token")
        XCTAssertEqual(config.environment, "production")
        XCTAssertEqual(config.appVersion, "1.0.0")
        XCTAssertEqual(config.metadata["userId"] as? String, "12345")
        XCTAssertEqual(config.maxBufferSize, 2000)
        XCTAssertEqual(config.batchInterval, 600)
    }
    
    func testMinimalConfiguration() {
        // Test that only errorReportingURI is needed
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://example.com/errors"
        )
        
        XCTAssertEqual(config.errorReportingURI, "https://example.com/errors")
        XCTAssertNil(config.batchReportingURI)
        XCTAssertNil(config.appId)
        XCTAssertNil(config.sharedSecret)
        XCTAssertTrue(config.enableShakeGesture)
    }
    
    func testBatchReportingURIOnly() {
        // Test explicit batch URI without error URI
        let config = InnerLoopConfiguration(
            batchReportingURI: "https://example.com/api/batch"
        )
        
        XCTAssertNil(config.errorReportingURI)
        XCTAssertEqual(config.batchReportingURI, "https://example.com/api/batch")
    }
}
