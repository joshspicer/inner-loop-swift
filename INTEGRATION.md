# InnerLoop Integration Guide

This guide will help you integrate InnerLoop into your iOS project quickly.

## Table of Contents
- [5-Minute Quick Start](#5-minute-quick-start)
- [UIKit Integration](#uikit-integration)
- [SwiftUI Integration](#swiftui-integration)
- [Testing on Real Devices](#testing-on-real-devices)
- [LLM-Assisted Development](#llm-assisted-development)

## 5-Minute Quick Start

### Step 1: Add InnerLoop to Your Project

**Using Swift Package Manager in Xcode:**
1. Open your project in Xcode
2. File → Add Package Dependencies
3. Enter: `https://github.com/joshspicer/inner-loop-swift.git`
4. Click "Add Package"

### Step 2: Initialize InnerLoop

In your app's entry point:

```swift
import InnerLoop

// In AppDelegate (UIKit)
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let config = InnerLoopConfiguration(
        errorReportingURI: "https://your-server.com/api/errors",
        enableShakeGesture: true,
        environment: "development"
    )
    InnerLoop.shared.initialize(with: config)
    return true
}

// Or in App struct (SwiftUI)
@main
struct MyApp: App {
    init() {
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://your-server.com/api/errors",
            enableShakeGesture: true,
            environment: "development"
        )
        InnerLoop.shared.initialize(with: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 3: Start Logging

```swift
import InnerLoop

// Anywhere in your code
InnerLoop.shared.info("User logged in")
InnerLoop.shared.error("Failed to fetch data")

// Report errors
do {
    try riskyOperation()
} catch {
    InnerLoop.shared.reportError(error)
}
```

### Step 4: Test Shake Gesture

Run your app on a device and shake it to see the debug menu!

## UIKit Integration

### Complete AppDelegate Setup

```swift
import UIKit
import InnerLoop

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        configureInnerLoop()
        
        return true
    }
    
    private func configureInnerLoop() {
        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        // Create configuration
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://your-server.com/api/errors",
            enableShakeGesture: true,
            customHeaders: [
                "X-API-Key": "your-api-key",
                "X-App-Platform": "iOS"
            ],
            environment: isDebug() ? "development" : "production",
            appVersion: appVersion,
            metadata: [
                "deviceModel": UIDevice.current.model,
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            ]
        )
        
        // Initialize InnerLoop
        InnerLoop.shared.initialize(with: config)
        
        // Configure advanced logging
        setupAdvancedLogging()
        
        // Log app start
        InnerLoop.shared.info("Application started")
    }
    
    private func setupAdvancedLogging() {
        // Add file logging for persistence
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsURL.appendingPathComponent("app.log")
        let fileDestination = FileLogDestination(fileURL: logFileURL)
        InnerLoop.shared.logger.addDestination(fileDestination)
        
        // Only show info and above in production
        #if !DEBUG
        InnerLoop.shared.logger.setMinimumLevel(.info)
        #endif
    }
    
    private func isDebug() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
```

### ViewController Usage

```swift
import UIKit
import InnerLoop

class MyViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        InnerLoop.shared.debug("MyViewController loaded")
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        InnerLoop.shared.info("MyViewController appeared")
    }
    
    private func setupUI() {
        // Your UI setup
    }
    
    @IBAction func performAction(_ sender: UIButton) {
        InnerLoop.shared.info("User tapped action button")
        
        performNetworkRequest { result in
            switch result {
            case .success(let data):
                InnerLoop.shared.info("Network request succeeded with \(data.count) items")
            case .failure(let error):
                InnerLoop.shared.reportError(error, additionalInfo: [
                    "screen": "MyViewController",
                    "action": "performAction"
                ])
            }
        }
    }
    
    private func performNetworkRequest(completion: @escaping (Result<[String], Error>) -> Void) {
        // Your networking code
    }
}
```

## SwiftUI Integration

### Complete App Setup

```swift
import SwiftUI
import InnerLoop

@main
struct MyApp: App {
    
    init() {
        configureInnerLoop()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    InnerLoop.shared.debug("ContentView appeared")
                }
        }
    }
    
    private func configureInnerLoop() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        let config = InnerLoopConfiguration(
            errorReportingURI: "https://your-server.com/api/errors",
            enableShakeGesture: true,
            environment: isDebug() ? "development" : "production",
            appVersion: appVersion
        )
        
        InnerLoop.shared.initialize(with: config)
        
        // Set minimum log level
        #if !DEBUG
        InnerLoop.shared.logger.setMinimumLevel(.info)
        #endif
        
        InnerLoop.shared.info("App initialized")
    }
    
    private func isDebug() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
```

### View Usage

```swift
import SwiftUI
import InnerLoop

struct ContentView: View {
    @State private var items: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    List(items, id: \.self) { item in
                        Text(item)
                    }
                }
            }
            .navigationTitle("Items")
            .toolbar {
                Button("Refresh") {
                    loadData()
                }
            }
        }
        .onAppear {
            InnerLoop.shared.debug("ContentView appeared")
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        
        InnerLoop.shared.info("Starting data load")
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Simulate success/failure
            let success = Bool.random()
            
            if success {
                items = ["Item 1", "Item 2", "Item 3"]
                InnerLoop.shared.info("Data loaded successfully: \(items.count) items")
            } else {
                let error = NSError(domain: "DataError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to load data"])
                errorMessage = error.localizedDescription
                
                InnerLoop.shared.reportError(error, additionalInfo: [
                    "screen": "ContentView",
                    "action": "loadData"
                ])
            }
            
            isLoading = false
        }
    }
}
```

## Testing on Real Devices

### Setup for Real Device Testing

1. **Configure Remote Logging:**
```swift
// Set up a server endpoint to receive logs
if let logEndpoint = URL(string: "https://your-server.com/api/logs") {
    let remoteDestination = RemoteLogDestination(
        endpoint: logEndpoint,
        customHeaders: ["Authorization": "Bearer your-token"],
        minimumLevel: .info  // Only send important logs
    )
    InnerLoop.shared.logger.addDestination(remoteDestination)
}
```

2. **Add Device Information:**
```swift
let config = InnerLoopConfiguration(
    errorReportingURI: "https://your-server.com/api/errors",
    enableShakeGesture: true,
    environment: "development",
    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
    metadata: [
        "deviceModel": UIDevice.current.model,
        "deviceName": UIDevice.current.name,
        "systemVersion": UIDevice.current.systemVersion,
        "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    ]
)
```

3. **Use Shake Gesture for Debugging:**
   - Run your app on a device
   - Shake the device to open the debug menu
   - Select "Test Error Reporting" to verify your setup

## LLM-Assisted Development

InnerLoop is designed to work seamlessly with LLM-assisted development workflows:

### 1. Automatic Error Context

Errors reported through InnerLoop include:
- Full stack traces
- Environment information
- Device metadata
- Custom context you provide

This gives your LLM all the information it needs to help debug issues.

### 2. Structured Logging

Logs include:
- Timestamp
- Log level
- File and line number
- Function name

This makes it easy for LLMs to understand code flow and identify issues.

### 3. Real-Time Feedback

Set up a server endpoint to receive logs and errors in real-time:

```swift
let config = InnerLoopConfiguration(
    errorReportingURI: "https://your-llm-server.com/api/errors",
    enableShakeGesture: true
)
```

Your LLM can then:
- Monitor errors as they happen
- Suggest fixes based on stack traces
- Identify patterns in logs
- Provide real-time debugging assistance

### 4. Custom Metadata

Add context that helps your LLM understand the situation:

```swift
InnerLoop.shared.reportError(error, additionalInfo: [
    "userId": currentUser.id,
    "screen": "LoginViewController",
    "action": "authenticateUser",
    "attemptNumber": "\(loginAttempts)",
    "networkStatus": networkReachability.status
])
```

### Example: LLM Integration Server

Here's a simple example of what your server endpoint might do:

```javascript
// Node.js example
app.post('/api/errors', (req, res) => {
    const errorData = req.body;
    
    // Forward to your LLM for analysis
    const llmPrompt = `
    An error occurred in the iOS app:
    Message: ${errorData.message}
    Stack Trace: ${errorData.stackTrace}
    Environment: ${errorData.environment}
    Metadata: ${JSON.stringify(errorData.metadata)}
    
    Please analyze this error and suggest a fix.
    `;
    
    // Send to LLM API
    // ... your LLM integration code
    
    res.status(200).json({ status: 'received' });
});
```

## Best Practices

### 1. Use Appropriate Log Levels

```swift
// Debug: Detailed information for debugging
InnerLoop.shared.debug("Cache hit for key: \(key)")

// Info: General informational messages
InnerLoop.shared.info("User logged in: \(username)")

// Warning: Something unexpected but handled
InnerLoop.shared.warning("API rate limit approaching")

// Error: Something went wrong
InnerLoop.shared.error("Failed to save data: \(error)")
```

### 2. Add Context to Errors

Always include relevant context when reporting errors:

```swift
InnerLoop.shared.reportError(error, additionalInfo: [
    "userId": user.id,
    "operation": "checkout",
    "cartTotal": "\(cart.total)",
    "paymentMethod": paymentMethod.type
])
```

### 3. Configure for Different Environments

```swift
let config = InnerLoopConfiguration(
    errorReportingURI: environment.errorReportingURL,
    enableShakeGesture: environment == .development,
    environment: environment.name
)
```

### 4. Use File Logging for Debugging

File logs persist across app sessions and can be retrieved later:

```swift
let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let logFileURL = documentsURL.appendingPathComponent("app.log")
let fileDestination = FileLogDestination(fileURL: logFileURL)
InnerLoop.shared.logger.addDestination(fileDestination)
```

## Troubleshooting

### Shake Gesture Not Working

Make sure you've enabled shake gestures in your configuration:
```swift
let config = InnerLoopConfiguration(enableShakeGesture: true)
```

### Logs Not Appearing

Check your minimum log level:
```swift
InnerLoop.shared.logger.setMinimumLevel(.debug)
```

### Errors Not Being Reported

Verify your error reporting URI is correct and the server is accessible:
```swift
let config = InnerLoopConfiguration(
    errorReportingURI: "https://your-server.com/api/errors"  // Check this URL
)
```

## Next Steps

- Read the [full documentation](README.md)
- Check out [usage examples](Examples/UsageExamples.swift)
- Integrate with your LLM workflow
- Customize the debug menu for your needs

## Support

For issues or questions, please open an issue on GitHub.
