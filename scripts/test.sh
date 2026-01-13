#!/bin/bash

# InnerLoop Swift Package Test Script
# This script can be run locally or in CI to build and test the Swift package

set -e  # Exit on error
set -o pipefail  # Catch errors in pipelines

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
SCHEME="InnerLoop"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=latest"
ENABLE_COVERAGE="YES"
BUILD_ONLY=false
TEST_ONLY=false

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --no-coverage)
            ENABLE_COVERAGE="NO"
            shift
            ;;
        --destination)
            DESTINATION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-only       Only build, don't run tests"
            echo "  --test-only        Only run tests, skip explicit build step"
            echo "  --no-coverage      Disable code coverage"
            echo "  --destination DST  Specify xcodebuild destination (default: iOS Simulator)"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if xcodebuild is available
if ! command -v xcodebuild &> /dev/null; then
    print_error "xcodebuild not found. This script requires Xcode to be installed."
    exit 1
fi

# Display environment information
print_info "Environment Information:"
echo "  Swift version: $(swift --version | head -n 1)"
echo "  Xcode version: $(xcodebuild -version | head -n 1)"
echo "  Xcode build: $(xcodebuild -version | tail -n 1)"
echo ""

# List available simulators
print_info "Available iOS Simulators:"
xcrun simctl list devices available | grep "iPhone" | head -n 5
echo ""

# Build the package
if [ "$TEST_ONLY" = false ]; then
    print_info "Building Swift package..."
    xcodebuild build \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        | xcpretty --simple || xcodebuild build \
            -scheme "$SCHEME" \
            -destination "$DESTINATION"

    print_info "Build completed successfully!"
    echo ""
fi

# Run tests
if [ "$BUILD_ONLY" = false ]; then
    print_info "Running Swift tests..."
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -enableCodeCoverage "$ENABLE_COVERAGE" \
        | xcpretty --simple || xcodebuild test \
            -scheme "$SCHEME" \
            -destination "$DESTINATION" \
            -enableCodeCoverage "$ENABLE_COVERAGE"

    print_info "Tests completed successfully!"
    echo ""
fi

print_info "All tasks completed successfully! ✅"
