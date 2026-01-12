# Agent Development Guidelines

This document outlines the code organization and modularity principles for the InnerLoop Swift library.

## Core Principle: Maximum Modularity

**Our goal is to split every new feature into AS MANY FILES AS POSSIBLE.**

This approach provides several benefits:
- **Better organization**: Each file has a single, clear responsibility
- **Easier testing**: Smaller, focused units are easier to test in isolation
- **Improved readability**: Developers can quickly find and understand specific functionality
- **Better maintainability**: Changes are localized to specific files, reducing merge conflicts
- **Clearer dependencies**: File structure makes dependencies between components explicit

## File Structure

The codebase is organized with one class, struct, enum, or protocol per file:

### Core Components
- `InnerLoop.swift` - Main facade class
- `Configuration.swift` - Configuration data structure

### Logging
- `LogLevel.swift` - Log level enumeration
- `LogDestination.swift` - Protocol for log destinations
- `ConsoleLogDestination.swift` - Console logging implementation
- `RemoteLogDestination.swift` - Remote server logging implementation
- `FileLogDestination.swift` - File logging implementation
- `Logger.swift` - Core logger class

### Batching
- `LogEntry.swift` - Individual log entry structure
- `LogBatch.swift` - Batch data structure
- `LogBatcher.swift` - Batching logic

### Error Handling
- `ErrorInfo.swift` - Error information structure
- `ErrorHandler.swift` - Error handling and reporting

### Shake Gesture Detection
- `ShakeGestureDetector.swift` - Main shake detection logic
- `ShakeGestureUI.swift` - UI alert presentation for shake gestures
- `UIViewControllerHelper.swift` - Utility for finding top view controller

### Utilities
- `MetadataUtil.swift` - Shared metadata conversion utilities

## Guidelines for New Features

When adding a new feature:

1. **Create separate files** for each logical component:
   - One file per class
   - One file per struct
   - One file per enum
   - One file per protocol

2. **Extract UI code** into dedicated UI files when applicable

3. **Share common logic** by creating utility files instead of duplicating code

4. **Name files clearly** - the filename should match the main type it contains

5. **Keep files focused** - if a file grows beyond ~200 lines, consider splitting it further

## Example: Adding a New Feature

If you're adding a new "Analytics" feature, you might create:

```
Sources/InnerLoop/
  Analytics/
    AnalyticsEvent.swift       # Event data structure
    AnalyticsTracker.swift     # Main tracking logic
    AnalyticsDestination.swift # Protocol for analytics destinations
    AnalyticsConsoleDestination.swift
    AnalyticsRemoteDestination.swift
    AnalyticsConfiguration.swift
```

## Anti-Patterns to Avoid

❌ **Don't** put multiple unrelated classes in one file
❌ **Don't** create large "utility" files with many unrelated functions
❌ **Don't** mix UI code with business logic in the same file
❌ **Don't** duplicate helper functions across files - extract to a shared utility

## Benefits We've Achieved

By following these principles, we've:
- Reduced code duplication (e.g., `MetadataUtil` instead of duplicate `buildMetadata` functions)
- Separated concerns (e.g., `ShakeGestureUI` handles only UI, `ShakeGestureDetector` handles only detection)
- Made the codebase more navigable
- Improved testability of individual components

## Conclusion

Remember: **When in doubt, create a new file.** The overhead of additional files is minimal compared to the benefits of clear organization and separation of concerns.
