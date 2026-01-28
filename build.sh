#!/bin/bash

set -e

echo "🔨 Building ADB Assistant..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XcodeGen not found. Installing..."
    brew install xcodegen
fi

# Generate Xcode project
echo "📋 Generating Xcode project..."
xcodegen generate

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo "⚠️  ADB not found in PATH. Please install Android SDK."
fi

echo "✅ Done! Open adb-assistant.xcodeproj in Xcode"
echo ""
echo "To build from command line:"
echo "  xcodebuild -project adb-assistant.xcodeproj -scheme adb-assistant -configuration Debug build"
echo ""
echo "To run tests:"
echo "  xcodebuild -project adb-assistant.xcodeproj -scheme adb-assistant -configuration Debug test"
