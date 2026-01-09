import XCTest
@testable import InnerLoop

final class ConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = InnerLoopConfiguration()
        
        XCTAssertNil(config.errorReportingURI)
        XCTAssertTrue(config.enableShakeGesture)
        XCTAssertEqual(config.customHeaders.count, 0)
        XCTAssertEqual(config.environment, "development")
        XCTAssertNil(config.appVersion)
        XCTAssertEqual(config.metadata.count, 0)
    }
    
    func testCustomConfiguration() {
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://example.com/errors",
            enableShakeGesture: false,
            customHeaders: ["Authorization": "Bearer token"],
            environment: "production",
            appVersion: "1.0.0",
            metadata: ["userId": "12345"]
        )
        
        XCTAssertEqual(config.errorReportingURI, "https://example.com/errors")
        XCTAssertFalse(config.enableShakeGesture)
        XCTAssertEqual(config.customHeaders["Authorization"], "Bearer token")
        XCTAssertEqual(config.environment, "production")
        XCTAssertEqual(config.appVersion, "1.0.0")
        XCTAssertEqual(config.metadata["userId"] as? String, "12345")
    }
}
