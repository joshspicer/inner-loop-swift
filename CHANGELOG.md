# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-09

### Added
- Initial release of InnerLoop Swift library
- Generic Logger with multiple log levels (debug, info, warning, error)
- Flexible log destination system:
  - ConsoleLogDestination for console output
  - FileLogDestination for file logging
  - RemoteLogDestination for remote server logging
- ErrorHandler for automatic error catching and reporting
- Configurable error reporting URI (no hardcoded endpoints)
- ShakeGestureDetector for device shake debugging
- Built-in debug menu triggered by device shake
- InnerLoopConfiguration for easy setup
- Thread-safe logging and error reporting
- Metadata support for additional context in errors and logs
- Custom header support for API calls
- UIWindow extension for automatic shake gesture detection
- Comprehensive test suite
- Extensive documentation and usage examples
- SwiftUI and UIKit support

### Features
- 📝 Generic Logger with customizable destinations
- 🐛 Error Handler with configurable reporting
- 🔄 Device Shake Debugging
- 🚀 Easy integration with minimal setup
- 🎯 Non-hardcoded, configurable URIs
- 🔒 Thread-safe operations
- 📱 iOS 13.0+ support
