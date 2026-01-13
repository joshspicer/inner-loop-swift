import Foundation

/// Manages the InnerLoop endpoint configuration with persistence
public class EndpointManager {
    public static let shared = EndpointManager()
    
    // MARK: - UserDefaults Keys
    
    private let endpointKey = "com.innerloop.endpoint"
    private let portKey = "com.innerloop.port"
    private let enabledKey = "com.innerloop.enabled"
    private let useHTTPSKey = "com.innerloop.useHTTPS"
    
    // MARK: - Default Values
    
    /// Default endpoint host (can be overridden)
    public static var defaultHost: String = "localhost"
    
    /// Default endpoint port
    public static var defaultPort: Int = 7990

    /// Default setting for whether to use HTTPS (set to false for local development)
    public static var defaultUseHTTPS: Bool = false

    /// Default path for log batches
    public static var batchPath: String = "/api/batch"
    
    /// Default path for error reports
    public static var errorPath: String = "/api/errors"
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    
    /// Whether remote logging is enabled
    public var isEnabled: Bool {
        get { userDefaults.object(forKey: enabledKey) as? Bool ?? false }
        set {
            userDefaults.set(newValue, forKey: enabledKey)
            notifyEndpointChanged()
        }
    }
    
    /// The current endpoint host (IP or hostname)
    public var host: String {
        get { userDefaults.string(forKey: endpointKey) ?? Self.defaultHost }
        set {
            userDefaults.set(newValue, forKey: endpointKey)
            notifyEndpointChanged()
        }
    }
    
    /// The current endpoint port
    public var port: Int {
        get { userDefaults.object(forKey: portKey) as? Int ?? Self.defaultPort }
        set {
            userDefaults.set(newValue, forKey: portKey)
            notifyEndpointChanged()
        }
    }

    /// Whether to use HTTPS instead of HTTP
    public var useHTTPS: Bool {
        get { userDefaults.object(forKey: useHTTPSKey) as? Bool ?? Self.defaultUseHTTPS }
        set {
            userDefaults.set(newValue, forKey: useHTTPSKey)
            notifyEndpointChanged()
        }
    }
    
    /// The URL scheme (http or https)
    public var scheme: String {
        useHTTPS ? "https" : "http"
    }
    
    /// The full base URL for the endpoint
    public var baseURL: URL? {
        guard isEnabled else { return nil }
        return URL(string: "\(scheme)://\(host):\(port)")
    }
    
    /// The full URL for log batch endpoint
    public var batchURL: URL? {
        baseURL?.appendingPathComponent(Self.batchPath)
    }
    
    /// The full URL for error reporting endpoint
    public var errorURL: URL? {
        baseURL?.appendingPathComponent(Self.errorPath)
    }
    
    /// String representation of the current endpoint
    public var endpointString: String {
        "\(scheme)://\(host):\(port)"
    }

    /// Callback when endpoint configuration changes
    public var onEndpointChanged: (() -> Void)?
    
    // MARK: - Initialization
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Public Methods
    
    /// Set the endpoint with host and port
    public func setEndpoint(host: String, port: Int) {
        self.host = host
        self.port = port
        Logger.shared.info("EndpointManager", "Endpoint set to \(host):\(port)")
    }
    
    /// Set the endpoint from a URL string (e.g., "192.168.1.100:8080")
    public func setEndpoint(from string: String) {
        let components = string.split(separator: ":")
        if components.count == 2,
           let portValue = Int(components[1]) {
            let hostValue = String(components[0])
            setEndpoint(host: hostValue, port: portValue)
        } else if components.count == 1 {
            // Just host, use default port
            setEndpoint(host: string, port: Self.defaultPort)
        }
    }
    
    /// Reset to default values
    public func resetToDefaults() {
        userDefaults.removeObject(forKey: endpointKey)
        userDefaults.removeObject(forKey: portKey)
        userDefaults.removeObject(forKey: enabledKey)
        userDefaults.removeObject(forKey: useHTTPSKey)
        notifyEndpointChanged()
        Logger.shared.info("EndpointManager", "Endpoint reset to defaults")
    }
    
    /// Get a list of common local network addresses to try
    public func getCommonEndpoints() -> [(name: String, host: String, port: Int)] {
        return [
            ("Localhost", "localhost", Self.defaultPort),
            ("Mac (Standard)", "192.168.1.1", Self.defaultPort),
            ("Local Network (.2)", "192.168.1.2", Self.defaultPort),
            ("Local Network (.100)", "192.168.1.100", Self.defaultPort),
            ("10.x Network", "10.0.0.1", Self.defaultPort),
        ]
    }
    
    // MARK: - Private Methods
    
    private func notifyEndpointChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onEndpointChanged?()
        }
    }
}
