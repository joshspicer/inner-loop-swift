import XCTest
@testable import InnerLoop

final class MetadataUtilTests: XCTestCase {
    
    func testBuildMetadataWithEmptyConfiguration() {
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret"
        )
        
        let metadata = MetadataUtil.buildMetadata(from: config)
        
        // Should be empty when no metadata provided
        XCTAssertEqual(metadata.count, 0)
    }
    
    func testBuildMetadataWithStringValues() {
        let testMetadata: [String: Any] = [
            "userId": "12345",
            "sessionId": "abc-def-ghi",
            "deviceType": "iPhone"
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: testMetadata
        )
        
        let metadata = MetadataUtil.buildMetadata(from: config)
        
        XCTAssertEqual(metadata.count, 3)
        XCTAssertEqual(metadata["userId"], "12345")
        XCTAssertEqual(metadata["sessionId"], "abc-def-ghi")
        XCTAssertEqual(metadata["deviceType"], "iPhone")
    }
    
    func testBuildMetadataWithMixedTypes() {
        let testMetadata: [String: Any] = [
            "stringValue": "test",
            "intValue": 42,
            "boolValue": true,
            "doubleValue": 3.14
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: testMetadata
        )
        
        let metadata = MetadataUtil.buildMetadata(from: config)
        
        XCTAssertEqual(metadata.count, 4)
        XCTAssertEqual(metadata["stringValue"], "test")
        XCTAssertEqual(metadata["intValue"], "42")
        XCTAssertEqual(metadata["boolValue"], "true")
        XCTAssertEqual(metadata["doubleValue"], "3.14")
    }
    
    func testBuildMetadataWithAdditionalInfo() {
        let configMetadata: [String: Any] = [
            "appName": "TestApp",
            "version": "1.0"
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: configMetadata
        )
        
        let additionalInfo = [
            "errorCode": "E001",
            "timestamp": "2024-01-01"
        ]
        
        let metadata = MetadataUtil.buildMetadata(from: config, additionalInfo: additionalInfo)
        
        // Should include both config metadata and additional info
        XCTAssertEqual(metadata.count, 4)
        XCTAssertEqual(metadata["appName"], "TestApp")
        XCTAssertEqual(metadata["version"], "1.0")
        XCTAssertEqual(metadata["errorCode"], "E001")
        XCTAssertEqual(metadata["timestamp"], "2024-01-01")
    }
    
    func testConfigMetadataOverridesAdditionalInfo() {
        let configMetadata: [String: Any] = [
            "environment": "development",
            "userId": "original"
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: configMetadata
        )
        
        // Additional info with overlapping key - should be overridden by config
        let additionalInfo = [
            "userId": "override"
        ]
        
        let metadata = MetadataUtil.buildMetadata(from: config, additionalInfo: additionalInfo)
        
        // Config metadata takes precedence and overrides additional info
        // (additionalInfo is processed first, then config metadata overwrites)
        XCTAssertEqual(metadata["userId"], "original")
        XCTAssertEqual(metadata["environment"], "development")
    }
    
    func testBuildMetadataWithCustomStringConvertible() {
        // Date conforms to CustomStringConvertible
        let date = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        
        let configMetadata: [String: Any] = [
            "timestamp": date
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: configMetadata
        )
        
        let metadata = MetadataUtil.buildMetadata(from: config)
        
        XCTAssertEqual(metadata.count, 1)
        XCTAssertNotNil(metadata["timestamp"])
        XCTAssertFalse(metadata["timestamp"]!.isEmpty)
    }
    
    func testBuildMetadataWithComplexTypes() {
        let configMetadata: [String: Any] = [
            "simpleString": "value",
            "number": 100,
            "array": [1, 2, 3], // Will be converted to string
            "dictionary": ["key": "value"] // Will be converted to string
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: configMetadata
        )
        
        let metadata = MetadataUtil.buildMetadata(from: config)
        
        XCTAssertEqual(metadata.count, 4)
        XCTAssertEqual(metadata["simpleString"], "value")
        XCTAssertEqual(metadata["number"], "100")
        XCTAssertNotNil(metadata["array"]) // Should be stringified
        XCTAssertNotNil(metadata["dictionary"]) // Should be stringified
    }
    
    func testBuildMetadataEmptyAdditionalInfo() {
        let configMetadata: [String: Any] = [
            "key1": "value1",
            "key2": "value2"
        ]
        
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: configMetadata
        )
        
        let metadata = MetadataUtil.buildMetadata(from: config, additionalInfo: [:])
        
        XCTAssertEqual(metadata.count, 2)
        XCTAssertEqual(metadata["key1"], "value1")
        XCTAssertEqual(metadata["key2"], "value2")
    }
    
    func testBuildMetadataOnlyAdditionalInfo() {
        let config = InnerLoopConfiguration(
            appId: "test-app",
            sharedSecret: "test-secret",
            metadata: [:] // Empty config metadata
        )
        
        let additionalInfo = [
            "extra1": "value1",
            "extra2": "value2"
        ]
        
        let metadata = MetadataUtil.buildMetadata(from: config, additionalInfo: additionalInfo)
        
        XCTAssertEqual(metadata.count, 2)
        XCTAssertEqual(metadata["extra1"], "value1")
        XCTAssertEqual(metadata["extra2"], "value2")
    }
}
