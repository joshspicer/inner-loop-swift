import InnerLoop
import UIKit

// MARK: - Example 1: Basic Setup in AppDelegate

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure InnerLoop with your settings
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://your-api.com/errors",
            enableShakeGesture: true,
            customHeaders: ["X-API-Key": "your-api-key"],
            environment: "development",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            metadata: [
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "",
                "deviceModel": UIDevice.current.model
            ]
        )
        
        InnerLoop.shared.initialize(with: config)
        
        // Log app startup
        InnerLoop.shared.info("Application started")
        
        return true
    }
}

// MARK: - Example 2: Using Logger in a View Controller

class MyViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Simple logging
        InnerLoop.shared.debug("MyViewController loaded")
        
        // Log user actions
        setupUI()
    }
    
    private func setupUI() {
        InnerLoop.shared.info("Setting up UI components")
        
        // Your UI setup code...
    }
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        InnerLoop.shared.info("Button tapped by user")
        
        // Simulate an operation that might fail
        performNetworkRequest()
    }
    
    private func performNetworkRequest() {
        // Simulate network request
        let url = URL(string: "https://api.example.com/data")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                // Report the error automatically
                InnerLoop.shared.reportError(error, additionalInfo: [
                    "endpoint": url.absoluteString,
                    "userId": "12345"
                ])
                
                InnerLoop.shared.error("Network request failed: \(error.localizedDescription)")
            } else {
                InnerLoop.shared.info("Network request succeeded")
            }
        }.resume()
    }
}

// MARK: - Example 3: Custom Shake Gesture Handler

class CustomDebugHandler: ShakeGestureDelegate {
    func didDetectShakeGesture() {
        // Show custom debug UI
        print("Shake detected! Showing custom debug menu...")
        
        // You can present your own debug view controller here
        let debugVC = DebugViewController()
        
        if let topVC = getTopViewController() {
            topVC.present(debugVC, animated: true)
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootViewController)
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }
        
        if let navigationController = viewController as? UINavigationController,
           let topViewController = navigationController.topViewController {
            return findTopViewController(from: topViewController)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return findTopViewController(from: selected)
        }
        
        return viewController
    }
}

class DebugViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Debug Menu"
        
        // Add your debug UI here
    }
}

// MARK: - Example 4: Advanced Logger Configuration

class AdvancedLoggingExample {
    
    func setupAdvancedLogging() {
        let logger = InnerLoop.shared.logger
        
        // Add file logging
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsURL.appendingPathComponent("app.log")
        let fileDestination = FileLogDestination(fileURL: logFileURL)
        logger.addDestination(fileDestination)
        
        // Add remote logging (only for warnings and errors)
        if let logEndpoint = URL(string: "https://your-api.com/logs") {
            let remoteDestination = RemoteLogDestination(
                endpoint: logEndpoint,
                customHeaders: ["Authorization": "Bearer your-token"],
                minimumLevel: .warning
            )
            logger.addDestination(remoteDestination)
        }
        
        // Set minimum log level for production
        #if DEBUG
        logger.setMinimumLevel(.debug)
        #else
        logger.setMinimumLevel(.info)
        #endif
    }
}

// MARK: - Example 5: Error Handling in a Data Manager

class DataManager {
    
    func fetchData(completion: @escaping (Result<[String], Error>) -> Void) {
        InnerLoop.shared.info("Fetching data from API")
        
        // Simulate API call
        let url = URL(string: "https://api.example.com/data")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                // Report error with context
                InnerLoop.shared.reportError(error, additionalInfo: [
                    "operation": "fetchData",
                    "endpoint": url.absoluteString
                ])
                
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                InnerLoop.shared.reportError(error)
                completion(.failure(error))
                return
            }
            
            do {
                // Parse data
                let result = try JSONDecoder().decode([String].self, from: data)
                InnerLoop.shared.info("Successfully fetched \(result.count) items")
                completion(.success(result))
            } catch {
                InnerLoop.shared.reportError(error, additionalInfo: [
                    "operation": "parseData",
                    "dataSize": "\(data.count)"
                ])
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Example 6: SwiftUI Integration

import SwiftUI

@main
struct MyApp: App {
    
    init() {
        // Configure InnerLoop for SwiftUI app
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://your-api.com/errors",
            enableShakeGesture: true,
            environment: "development",
            appVersion: "1.0.0"
        )
        
        InnerLoop.shared.initialize(with: config)
        
        // Set custom shake gesture handler
        InnerLoop.shared.shakeGestureDetector.delegate = CustomDebugHandler()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
            
            Button("Test Error Reporting") {
                InnerLoop.shared.info("Button tapped")
                
                // Simulate an error
                let error = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "This is a test error"])
                InnerLoop.shared.reportError(error)
            }
        }
        .onAppear {
            InnerLoop.shared.debug("ContentView appeared")
        }
    }
}

// MARK: - Example 7: Custom Log Destination

class AnalyticsLogDestination: LogDestination {
    func write(message: String, level: LogLevel, timestamp: Date, file: String, function: String, line: Int) {
        // Send important logs to your analytics service
        guard level >= .warning else { return }
        
        // Your analytics SDK call
        // Analytics.track("Log", properties: [
        //     "level": level.description,
        //     "message": message,
        //     "file": file,
        //     "line": line
        // ])
        
        print("Analytics: [\(level.description)] \(message)")
    }
}

// Setup custom destination
func setupCustomDestination() {
    InnerLoop.shared.logger.addDestination(AnalyticsLogDestination())
}
