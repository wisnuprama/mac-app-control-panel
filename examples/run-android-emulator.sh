#!/bin/bash

# Run Android Emulator Script
# This script launches an Android emulator from the command line
#
# Prerequisites:
# - Android SDK installed
# - At least one AVD (Android Virtual Device) created
# - ANDROID_HOME or ANDROID_SDK_ROOT environment variable set

# Try to find Android SDK
if [ -n "$ANDROID_HOME" ]; then
    SDK_PATH="$ANDROID_HOME"
elif [ -n "$ANDROID_SDK_ROOT" ]; then
    SDK_PATH="$ANDROID_SDK_ROOT"
elif [ -d "$HOME/Library/Android/sdk" ]; then
    SDK_PATH="$HOME/Library/Android/sdk"
elif [ -d "$HOME/Android/Sdk" ]; then
    SDK_PATH="$HOME/Android/Sdk"
else
    echo "Error: Android SDK not found!"
    echo "Please set ANDROID_HOME or ANDROID_SDK_ROOT environment variable"
    exit 1
fi

EMULATOR="$SDK_PATH/emulator/emulator"

# Check if emulator exists
if [ ! -f "$EMULATOR" ]; then
    echo "Error: Emulator not found at $EMULATOR"
    exit 1
fi

# List available AVDs
echo "Available Android Virtual Devices:"
"$EMULATOR" -list-avds

# Get first available AVD if no argument provided
AVD_NAME="Pixel_6"

echo ""
echo "Starting emulator: $AVD_NAME"
echo "This may take a moment..."

# Launch emulator in background
# -no-snapshot-load: Start fresh (optional, remove for faster boot)
# -gpu auto: Use GPU acceleration if available
"$EMULATOR" -avd "$AVD_NAME" -gpu auto -no-snapshot-load &

echo "Emulator launched! PID: $!"
