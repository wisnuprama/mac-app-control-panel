#!/bin/bash

# Build and Run Script for AppControlPanel
# Usage: ./build.sh [build|run|clean|release]

set -e

PROJECT_NAME="AppControlPanel"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="$PROJECT_NAME.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Build the project
build_debug() {
    print_status "Building $PROJECT_NAME (Debug)..."

    xcodebuild \
        -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR" \
        -destination 'platform=macOS' \
        build \
        | grep -E "^(Build|Compile|Link|warning:|error:|\*\*)" || true

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_status "Build succeeded!"
    else
        print_error "Build failed!"
        exit 1
    fi
}

# Build release version
build_release() {
    print_status "Building $PROJECT_NAME (Release)..."

    xcodebuild \
        -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        -destination 'platform=macOS' \
        build \
        | grep -E "^(Build|Compile|Link|warning:|error:|\*\*)" || true

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_status "Release build succeeded!"

        # Copy to project root for easy access
        APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"
        if [ -d "$APP_PATH" ]; then
            cp -R "$APP_PATH" "$PROJECT_DIR/"
            print_status "App copied to: $PROJECT_DIR/$APP_NAME"
        fi
    else
        print_error "Build failed!"
        exit 1
    fi
}

# Run the app
run_app() {
    APP_PATH="$BUILD_DIR/Build/Products/Debug/$APP_NAME"

    if [ ! -d "$APP_PATH" ]; then
        print_warning "App not found, building first..."
        build_debug
    fi

    print_status "Running $PROJECT_NAME..."

    # Kill existing instance if running
    pkill -x "$PROJECT_NAME" 2>/dev/null || true
    sleep 0.5

    # Run the app
    open "$APP_PATH"

    print_status "App launched! Check your menu bar."
}

# Clean build artifacts
clean_build() {
    print_status "Cleaning build artifacts..."

    rm -rf "$BUILD_DIR"
    rm -rf "$PROJECT_DIR/$APP_NAME"

    xcodebuild \
        -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        clean \
        2>/dev/null || true

    print_status "Clean completed!"
}

# Watch for changes and rebuild (requires fswatch)
watch_and_build() {
    if ! command -v fswatch &> /dev/null; then
        print_error "fswatch is not installed. Install it with: brew install fswatch"
        exit 1
    fi

    print_status "Watching for changes in $PROJECT_DIR/$PROJECT_NAME..."
    print_status "Press Ctrl+C to stop"

    # Initial build and run
    build_debug
    run_app

    # Watch for changes
    fswatch -o "$PROJECT_DIR/$PROJECT_NAME" --exclude ".*\.xcodeproj.*" | while read; do
        print_status "Changes detected, rebuilding..."
        build_debug

        # Restart the app
        pkill -x "$PROJECT_NAME" 2>/dev/null || true
        sleep 0.5
        run_app
    done
}

# Show help
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build     Build the project (Debug)"
    echo "  release   Build the project (Release)"
    echo "  run       Build and run the app"
    echo "  clean     Clean build artifacts"
    echo "  watch     Watch for changes and auto-rebuild (requires fswatch)"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 run      # Build and launch the app"
    echo "  $0 release  # Create a release build"
    echo "  $0 clean    # Remove all build files"
}

# Main
case "${1:-run}" in
    build)
        build_debug
        ;;
    release)
        build_release
        ;;
    run)
        build_debug
        run_app
        ;;
    clean)
        clean_build
        ;;
    watch)
        watch_and_build
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
