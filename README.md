# InnerLoop

A generic Swift library for iOS development that makes it easy to test on real devices, forward logs, and handle errors with LLM-assisted development workflows.

## Features

- 📝 **Generic Logger**: Flexible logging system with multiple destinations (console, file, remote server)
- 🐛 **Error Handler**: Automatic error catching and reporting to configurable endpoints
- 📦 **Log Batching**: Efficiently collects and batches logs before sending to reduce network overhead
- 🔄 **Device Shake Debugging**: Built-in debug menu triggered by device shake - add your own context messages
- 🤖 **LLM Integration**: Backend service with AI-powered error analysis using OpenAI or Anthropic
- 🐳 **Dockerized Service**: Easy-to-deploy backend service for receiving and analyzing logs
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

### Backend Service Setup

First, set up the InnerLoop service to receive and analyze logs:

```bash
cd service
cp .env.example .env
# Edit .env to add your LLM API keys (optional)

# Start with Docker Compose
docker-compose up -d
```

The service will be available at `http://localhost:7990`. See [service/README.md](service/README.md) for full documentation.

### iOS Library Setup

```swift
import InnerLoop

// In your AppDelegate or App struct
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Configure InnerLoop
    let config = InnerLoopConfiguration(
        errorReportingURI: "http://localhost:7990/api/errors",
        enableShakeGesture: true,
        environment: "development",
        appVersion: "1.0.0",
        maxBufferSize: 1000,    // Buffer up to 1000 logs
        batchInterval: 300       // Send logs every 5 minutes
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

The library automatically enables shake gesture debugging. When you shake the device, a debug menu appears with these options:

- **Send Logs with Message**: Add your own description of what went wrong and send buffered logs
- **Send Logs**: Send all buffered logs immediately without a message
- **View Buffer Size**: See how many logs are currently buffered
- **Test Error Reporting**: Test that error reporting is working correctly

This is perfect for TestFlight builds - when users encounter an issue, they can shake the device, describe what happened in their own words, and send all the context you need to debug the issue!

#### Custom Shake Behavior

Customize by implementing `ShakeGestureDelegate`:

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

### Log Batching

InnerLoop automatically batches all logs (at all levels) to provide rich context when issues occur. Logs are buffered in memory and sent:

- **Automatically** every 5 minutes (configurable)
- **Automatically** when the buffer reaches 1000 logs (configurable)
- **Manually** when the user shakes the device and chooses to send logs
- **On demand** by calling `LogBatcher.shared.sendBatch()`

```swift
// Configure batching behavior
let config = InnerLoopConfiguration(
    errorReportingURI: "http://your-server.com:7990/api/errors",
    maxBufferSize: 2000,     // Buffer up to 2000 logs before auto-sending
    batchInterval: 600        // Send every 10 minutes instead of 5
)

// Manually send logs with optional message
LogBatcher.shared.sendBatch(userMessage: "Payment failed after entering card details")

// Check buffer status
let bufferSize = LogBatcher.shared.getBufferSize()
print("Currently buffering \(bufferSize) logs")

// Clear buffer (rarely needed)
LogBatcher.shared.clearBuffer()
```

The batching system collects logs at **all levels** (debug, info, warning, error) so that when an issue occurs, you have the complete context leading up to it.

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