# InnerLoop

A generic Swift library for iOS development that makes it easy to test on real devices, forward logs, and handle errors with LLM-assisted development workflows.

## Features

- 📝 **Generic Logger**: Flexible logging system with multiple destinations (console, file, remote server)
- 🐛 **Error Handler**: Automatic error catching and reporting to configurable endpoints
- 🔄 **Device Shake Debugging**: Built-in debug menu triggered by device shake
- 🚀 **Easy Integration**: Simple API for quick setup in any iOS project
- 🎯 **Configurable**: Non-hardcoded URIs and customizable settings

## Installation

### Swift Package Manager

Add InnerLoop to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/joshspicer/inner-loop-swift.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/joshspicer/inner-loop-swift.git`

## Quick Start

### Basic Setup

```swift
import InnerLoop

// In your AppDelegate or App struct
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Configure InnerLoop
    let config = InnerLoopConfiguration(
        errorReportingURI: "https://your-server.com/api/errors",
        enableShakeGesture: true,
        environment: "development",
        appVersion: "1.0.0"
    )
    
    InnerLoop.shared.initialize(with: config)
    
    return true
}
```

### Using the Logger

```swift
import InnerLoop

// Simple logging
InnerLoop.shared.info("App started successfully")
InnerLoop.shared.debug("User ID: \(userId)")
InnerLoop.shared.warning("Low memory warning")
InnerLoop.shared.error("Failed to load data")

// Or use the logger directly
let logger = InnerLoop.shared.logger
logger.info("This is an info message")
```

### Error Reporting

```swift
import InnerLoop

// Report an error
do {
    try somethingThatMightFail()
} catch {
    InnerLoop.shared.reportError(error)
}

// Report with additional context
InnerLoop.shared.reportError(
    error, 
    additionalInfo: ["userId": "12345", "action": "login"]
)

// Report custom error message
InnerLoop.shared.reportError(
    message: "Custom error occurred",
    additionalInfo: ["context": "payment processing"]
)
```

### Device Shake Debugging

The library automatically enables shake gesture debugging. When you shake the device:
- A debug menu appears with options
- View logs, test error reporting, and more
- Customize by implementing `ShakeGestureDelegate`:

```swift
import InnerLoop

class MyDebugHandler: ShakeGestureDelegate {
    func didDetectShakeGesture() {
        // Custom debug actions
        print("Shake detected! Opening custom debug view...")
    }
}

// Set custom delegate
InnerLoop.shared.shakeGestureDetector.delegate = MyDebugHandler()
```

## Advanced Usage

### Custom Log Destinations

```swift
import InnerLoop

// Add remote logging
if let logEndpoint = URL(string: "https://your-server.com/api/logs") {
    let remoteDestination = RemoteLogDestination(
        endpoint: logEndpoint,
        minimumLevel: .warning  // Only send warnings and errors
    )
    InnerLoop.shared.logger.addDestination(remoteDestination)
}

// Add file logging
let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let logFileURL = documentsURL.appendingPathComponent("app.log")
let fileDestination = FileLogDestination(fileURL: logFileURL)
InnerLoop.shared.logger.addDestination(fileDestination)
```

### Custom Log Destination

Create your own log destination:

```swift
import InnerLoop

class CustomLogDestination: LogDestination {
    func write(message: String, level: LogLevel, timestamp: Date, file: String, function: String, line: Int) {
        // Your custom logging logic
        // e.g., send to analytics, store in database, etc.
    }
}

InnerLoop.shared.logger.addDestination(CustomLogDestination())
```

### Configuration Options

```swift
let config = InnerLoopConfiguration(
    errorReportingURI: "https://api.example.com/errors",  // Optional: where to send errors
    enableShakeGesture: true,                              // Enable/disable shake debugging
    customHeaders: ["Authorization": "Bearer token"],      // Custom headers for API calls
    environment: "production",                             // Environment identifier
    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
    metadata: ["deviceId": UIDevice.current.identifierForVendor?.uuidString ?? ""]
)
```

### Log Levels

Control which logs are displayed:

```swift
// Only show warnings and errors
InnerLoop.shared.logger.setMinimumLevel(.warning)

// Show all logs (default)
InnerLoop.shared.logger.setMinimumLevel(.debug)
```

## API Reference

### InnerLoop

- `initialize(with:)` - Initialize the library with configuration
- `debug(_:)` - Log debug message
- `info(_:)` - Log info message
- `warning(_:)` - Log warning message
- `error(_:)` - Log error message
- `reportError(_:additionalInfo:)` - Report an error
- `logger` - Access the Logger instance
- `errorHandler` - Access the ErrorHandler instance
- `shakeGestureDetector` - Access the ShakeGestureDetector instance

### Logger

- `configure(destinations:minimumLevel:)` - Configure logger with custom destinations
- `addDestination(_:)` - Add a log destination
- `setMinimumLevel(_:)` - Set minimum log level
- `debug(_:)`, `info(_:)`, `warning(_:)`, `error(_:)` - Logging methods

### LogLevel

- `.debug` - Debug information
- `.info` - General information
- `.warning` - Warning messages
- `.error` - Error messages

## Requirements

- iOS 13.0+
- Swift 5.9+

## License

MIT License - feel free to use in your projects!

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.