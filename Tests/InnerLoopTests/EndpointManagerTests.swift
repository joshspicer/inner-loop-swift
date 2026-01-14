import XCTest
@testable import InnerLoop

final class EndpointManagerTests: XCTestCase {
    
    var endpointManager: EndpointManager!
    
    override func setUp() {
        super.setUp()
        endpointManager = EndpointManager.shared
        
        // Reset to defaults before each test
        endpointManager.resetToDefaults()
    }
    
    override func tearDown() {
        // Clean up after each test
        endpointManager.resetToDefaults()
        super.tearDown()
    }
    
    func testDefaultValues() {
        XCTAssertEqual(endpointManager.host, EndpointManager.defaultHost)
        XCTAssertEqual(endpointManager.port, EndpointManager.defaultPort)
        XCTAssertFalse(endpointManager.isEnabled)
        XCTAssertFalse(endpointManager.useHTTPS)
    }
    
    func testSetEndpoint() {
        let testHost = "192.168.1.100"
        let testPort = 8080
        
        endpointManager.setEndpoint(host: testHost, port: testPort)
        
        XCTAssertEqual(endpointManager.host, testHost)
        XCTAssertEqual(endpointManager.port, testPort)
    }
    
    func testSetEndpointFromString() {
        let endpointString = "10.0.0.5:9000"
        
        endpointManager.setEndpoint(from: endpointString)
        
        XCTAssertEqual(endpointManager.host, "10.0.0.5")
        XCTAssertEqual(endpointManager.port, 9000)
    }
    
    func testSetEndpointFromStringHostOnly() {
        let hostOnly = "192.168.1.50"
        
        endpointManager.setEndpoint(from: hostOnly)
        
        XCTAssertEqual(endpointManager.host, hostOnly)
        XCTAssertEqual(endpointManager.port, EndpointManager.defaultPort)
    }
    
    func testEnableRemoteLogging() {
        XCTAssertFalse(endpointManager.isEnabled)
        
        endpointManager.isEnabled = true
        
        XCTAssertTrue(endpointManager.isEnabled)
    }
    
    func testUseHTTPS() {
        XCTAssertFalse(endpointManager.useHTTPS)
        
        endpointManager.useHTTPS = true
        
        XCTAssertTrue(endpointManager.useHTTPS)
        XCTAssertEqual(endpointManager.scheme, "https")
    }
    
    func testScheme() {
        // Default should be http
        XCTAssertEqual(endpointManager.scheme, "http")
        
        // Change to https
        endpointManager.useHTTPS = true
        XCTAssertEqual(endpointManager.scheme, "https")
        
        // Change back to http
        endpointManager.useHTTPS = false
        XCTAssertEqual(endpointManager.scheme, "http")
    }
    
    func testBaseURLWhenDisabled() {
        endpointManager.isEnabled = false
        endpointManager.host = "example.com"
        endpointManager.port = 8080
        
        XCTAssertNil(endpointManager.baseURL)
    }
    
    func testBaseURLWhenEnabled() {
        endpointManager.isEnabled = true
        endpointManager.host = "example.com"
        endpointManager.port = 8080
        endpointManager.useHTTPS = false
        
        guard let url = endpointManager.baseURL else {
            XCTFail("Base URL should not be nil when enabled")
            return
        }
        
        XCTAssertEqual(url.absoluteString, "http://example.com:8080")
    }
    
    func testBaseURLWithHTTPS() {
        endpointManager.isEnabled = true
        endpointManager.host = "secure.example.com"
        endpointManager.port = 443
        endpointManager.useHTTPS = true
        
        guard let url = endpointManager.baseURL else {
            XCTFail("Base URL should not be nil when enabled")
            return
        }
        
        XCTAssertEqual(url.absoluteString, "https://secure.example.com:443")
    }
    
    func testBatchURL() {
        endpointManager.isEnabled = true
        endpointManager.host = "api.example.com"
        endpointManager.port = 7990
        
        guard let batchURL = endpointManager.batchURL else {
            XCTFail("Batch URL should not be nil when enabled")
            return
        }
        
        XCTAssertTrue(batchURL.absoluteString.contains("/api/batch"))
        XCTAssertTrue(batchURL.absoluteString.hasPrefix("http://api.example.com:7990"))
    }
    
    func testErrorURL() {
        endpointManager.isEnabled = true
        endpointManager.host = "api.example.com"
        endpointManager.port = 7990
        
        guard let errorURL = endpointManager.errorURL else {
            XCTFail("Error URL should not be nil when enabled")
            return
        }
        
        XCTAssertTrue(errorURL.absoluteString.contains("/api/errors"))
        XCTAssertTrue(errorURL.absoluteString.hasPrefix("http://api.example.com:7990"))
    }
    
    func testEndpointString() {
        endpointManager.host = "localhost"
        endpointManager.port = 7990
        endpointManager.useHTTPS = false
        
        XCTAssertEqual(endpointManager.endpointString, "http://localhost:7990")
        
        endpointManager.useHTTPS = true
        XCTAssertEqual(endpointManager.endpointString, "https://localhost:7990")
    }
    
    func testResetToDefaults() {
        // Change values
        endpointManager.host = "custom.host.com"
        endpointManager.port = 9999
        endpointManager.isEnabled = true
        endpointManager.useHTTPS = true
        
        // Reset
        endpointManager.resetToDefaults()
        
        // Verify defaults are restored
        XCTAssertEqual(endpointManager.host, EndpointManager.defaultHost)
        XCTAssertEqual(endpointManager.port, EndpointManager.defaultPort)
        XCTAssertFalse(endpointManager.isEnabled)
        XCTAssertEqual(endpointManager.useHTTPS, EndpointManager.defaultUseHTTPS)
    }
    
    func testGetCommonEndpoints() {
        let commonEndpoints = endpointManager.getCommonEndpoints()
        
        XCTAssertGreaterThan(commonEndpoints.count, 0)
        
        // Check that localhost is in the list
        let hasLocalhost = commonEndpoints.contains { $0.host == "localhost" }
        XCTAssertTrue(hasLocalhost)
        
        // Verify structure of endpoints
        for endpoint in commonEndpoints {
            XCTAssertFalse(endpoint.name.isEmpty)
            XCTAssertFalse(endpoint.host.isEmpty)
            XCTAssertGreaterThan(endpoint.port, 0)
        }
    }
    
    func testPersistence() {
        // Set custom values
        let customHost = "persistent.test.com"
        let customPort = 12345
        
        endpointManager.host = customHost
        endpointManager.port = customPort
        endpointManager.isEnabled = true
        endpointManager.useHTTPS = true
        
        // Values should persist (using UserDefaults)
        XCTAssertEqual(endpointManager.host, customHost)
        XCTAssertEqual(endpointManager.port, customPort)
        XCTAssertTrue(endpointManager.isEnabled)
        XCTAssertTrue(endpointManager.useHTTPS)
    }
    
    func testOnEndpointChangedCallback() {
        let expectation = self.expectation(description: "Endpoint changed callback")
        var callbackInvoked = false
        
        endpointManager.onEndpointChanged = {
            callbackInvoked = true
            expectation.fulfill()
        }
        
        // Trigger a change
        endpointManager.host = "changed.com"
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(callbackInvoked)
    }
}
