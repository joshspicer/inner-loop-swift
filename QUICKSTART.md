# InnerLoop Quick Start Guide

This guide will get you up and running with InnerLoop in under 10 minutes.

## What You'll Build

- A backend service that receives and stores logs from your iOS app
- An iOS app configured to batch logs and send them when users report issues
- (Optional) LLM-powered analysis of errors and user-reported issues

## Step 1: Start the Backend Service

### Option A: Using Docker (Recommended)

```bash
cd service
cp .env.example .env

# Start the service
docker-compose up -d

# Check it's running
curl http://localhost:7990/health
```

### Option B: Without Docker

```bash
cd service
cp .env.example .env
npm install
npm start
```

The service will be available at `http://localhost:7990`.

## Step 2: Configure Your iOS App

Add InnerLoop to your project using Swift Package Manager:

1. In Xcode: File → Add Package Dependencies
2. Enter: `https://github.com/joshspicer/inner-loop-swift.git`

## Step 3: Initialize InnerLoop

In your `AppDelegate.swift` or `App.swift`:

```swift
import InnerLoop

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Get app version from Info.plist
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    // Configure InnerLoop
    let config = InnerLoopConfiguration(
        errorReportingURI: "http://localhost:7990/api/errors",  // Use your server URL
        enableShakeGesture: true,
        environment: "development",
        appVersion: appVersion,
        maxBufferSize: 1000,     // Buffer up to 1000 logs
        batchInterval: 300        // Auto-send every 5 minutes
    )

    InnerLoop.shared.initialize(with: config)

    return true
}
```

## Step 4: Add Logging to Your Code

```swift
import InnerLoop

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Log at different levels
        InnerLoop.shared.debug("ViewController loaded")
        InnerLoop.shared.info("User opened main screen")
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        InnerLoop.shared.info("User tapped save button")

        do {
            try saveData()
            InnerLoop.shared.info("Data saved successfully")
        } catch {
            InnerLoop.shared.error("Failed to save data: \(error.localizedDescription)")
            InnerLoop.shared.reportError(error, additionalInfo: [
                "screen": "ViewController",
                "action": "save"
            ])
        }
    }
}
```

## Step 5: Test Shake-to-Send

1. Run your app on a device or simulator
2. Use the app normally - logs are being collected automatically
3. Shake the device (Device → Shake in simulator)
4. Choose "Send Logs with Message"
5. Type what went wrong (e.g., "Save button didn't work")
6. Tap Send

## Step 6: View Your Logs

### Check the service received them:

```bash
# View all errors
curl http://localhost:7990/api/errors | jq .

# View all log batches
curl http://localhost:7990/api/batches | jq .

# View a specific batch with all logs
curl http://localhost:7990/api/batches/1 | jq .
```

### Check service logs:

```bash
# Docker
docker-compose logs -f innerloop-service

# Without Docker
# Logs appear in the terminal where you ran npm start
```

## Step 7 (Optional): Enable LLM Analysis

To get AI-powered analysis of errors and user-reported issues:

1. Edit `service/.env`:
```bash
ENABLE_LLM=true
AUTO_ANALYZE_ERRORS=true
LLM_PROVIDER=openai  # or anthropic

# Add your API key
OPENAI_API_KEY=sk-your-key-here
# OR
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

2. Restart the service:
```bash
docker-compose restart innerloop-service
```

Now when errors occur or users send logs with messages, the service will automatically analyze them and provide:
- Root cause analysis
- Fix suggestions
- Prevention strategies

View the analysis:
```bash
curl http://localhost:7990/api/batches/1 | jq '.analysis'
```

## Production Deployment

For production use:

1. **Deploy the service** to a cloud provider (AWS, Azure, DigitalOcean, etc.)
2. **Use HTTPS** - deploy behind a reverse proxy with SSL/TLS
3. **Update iOS config** with your server URL:
   ```swift
   errorReportingURI: "https://innerloop.yourdomain.com/api/errors"
   ```
4. **Add authentication** - secure your API endpoints
5. **Set up monitoring** - use the `/health` endpoint for health checks

## Common Issues

### iOS app can't connect to localhost

On device: Use your computer's IP address instead of localhost:
```swift
errorReportingURI: "http://192.168.1.100:7990/api/errors"
```

On simulator: `localhost` should work, but you may need to use `127.0.0.1`

### Service not starting

Check if port 7990 is in use:
```bash
lsof -i :7990
```

Use a different port:
```bash
# Edit .env
PORT=8080

# Update iOS config
errorReportingURI: "http://localhost:8080/api/errors"
```

### Logs not appearing in service

1. Check service logs for errors
2. Verify the URL in iOS config is correct
3. Check network connectivity
4. Try sending manually: `LogBatcher.shared.sendBatch(userMessage: "test")`

## Next Steps

- Read the [full documentation](../README.md)
- Check out [example usage](../Examples/UsageExamples.swift)
- Learn about [advanced features](../INTEGRATION.md)
- Set up [production deployment](service/README.md#production-deployment)

## Help

For issues or questions, open an issue on GitHub.
