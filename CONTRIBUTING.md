# Contributing to InnerLoop

Thank you for your interest in contributing to InnerLoop! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/inner-loop-swift.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`

## Development Setup

### Requirements

- Xcode 14.0 or later
- Swift 5.9 or later
- iOS 13.0+ deployment target

### Building the Project

```bash
# Clone the repository
git clone https://github.com/joshspicer/inner-loop-swift.git
cd inner-loop-swift

# Open in Xcode
open Package.swift

# Or build from command line (on macOS)
swift build
```

### Running Tests

```bash
swift test
```

Or in Xcode:
1. Open Package.swift
2. Select Product → Test (⌘U)

## Code Style

### Swift Style Guidelines

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (no tabs)
- Maximum line length: 120 characters
- Use meaningful variable and function names
- Add documentation comments for public APIs

### Example

```swift
/// Brief description of what this function does
///
/// More detailed description if needed. Explain the purpose,
/// any important implementation details, and usage examples.
///
/// - Parameter message: Description of the parameter
/// - Returns: Description of what is returned
/// - Throws: Description of what errors might be thrown
public func exampleFunction(message: String) throws -> String {
    // Implementation
}
```

## Making Changes

### Adding New Features

1. **Discuss First**: For major changes, open an issue first to discuss what you would like to change
2. **Write Tests**: Add tests for your new feature
3. **Update Documentation**: Update README.md and other relevant documentation
4. **Follow Code Style**: Ensure your code follows the project's code style
5. **Keep It Minimal**: Make focused, minimal changes

### Fixing Bugs

1. **Create an Issue**: If one doesn't exist, create an issue describing the bug
2. **Write a Test**: Add a test that reproduces the bug
3. **Fix the Bug**: Implement the fix
4. **Verify**: Ensure all tests pass
5. **Document**: Update CHANGELOG.md

### Improving Documentation

- Fix typos and grammar
- Add examples
- Clarify unclear sections
- Translate documentation (if multilingual support is added)

## Pull Request Process

1. **Update Tests**: Ensure all tests pass
2. **Update Documentation**: Update README.md, CHANGELOG.md, and code comments
3. **Follow Commit Guidelines**: Use clear, descriptive commit messages
4. **One Feature Per PR**: Keep pull requests focused on a single feature or fix
5. **Reference Issues**: Link to relevant issues in your PR description

### Commit Message Format

```
type: Brief description (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what and why, not how.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `style`: Code style changes (formatting, etc.)
- `chore`: Maintenance tasks

### Example Commit Messages

```
feat: Add custom log formatting support

Allow users to customize the format of log messages by providing
a custom formatter function. This is useful for integrating with
existing logging infrastructure.

Fixes #45

---

fix: Prevent crash when shake gesture occurs without configuration

Added nil check for configuration in ShakeGestureDetector to prevent
crash when shake gesture is detected before InnerLoop is initialized.

Fixes #67

---

docs: Add SwiftUI integration examples

Added comprehensive examples showing how to integrate InnerLoop
in SwiftUI apps, including both App and Scene-based configurations.
```

## Testing Guidelines

### Writing Tests

- Test both success and failure cases
- Use descriptive test names: `testLoggerFiltersMessagesBelowMinimumLevel()`
- Keep tests focused on one thing
- Use test fixtures to reduce duplication
- Mock external dependencies

### Example Test

```swift
func testErrorHandlerIncludesMetadataInReport() {
    // Arrange
    let config = InnerLoopConfiguration(
        environment: "test",
        metadata: ["userId": "12345"]
    )
    errorHandler.configure(with: config)
    
    // Act
    errorHandler.report(message: "Test error")
    
    // Assert
    // Verify metadata was included in report
    XCTAssertTrue(true) // Replace with actual assertion
}
```

## What to Contribute

### Good First Issues

Look for issues labeled `good first issue` for beginner-friendly contributions:
- Documentation improvements
- Adding examples
- Writing tests
- Fixing typos

### Areas for Contribution

- **Features**: New log destinations, custom formatters, additional debug tools
- **Documentation**: More examples, translations, tutorials
- **Tests**: Increase test coverage
- **Performance**: Optimize logging and error reporting
- **Bug Fixes**: Fix reported issues

### What We're Looking For

- Thread-safety improvements
- Performance optimizations
- Better error messages
- More comprehensive examples
- Integration with popular frameworks
- Accessibility improvements

## Code Review Process

1. **Automated Checks**: CI will run tests automatically
2. **Maintainer Review**: A maintainer will review your code
3. **Address Feedback**: Make requested changes
4. **Approval**: Once approved, your PR will be merged
5. **Release**: Changes will be included in the next release

## Community Guidelines

- Be respectful and constructive
- Welcome newcomers
- Help others learn
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md)

## Questions?

- Open an issue with the `question` label
- Start a discussion in GitHub Discussions
- Reach out to maintainers

## License

By contributing to InnerLoop, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in:
- README.md (for significant contributions)
- Release notes
- CHANGELOG.md

Thank you for contributing to InnerLoop! 🎉
