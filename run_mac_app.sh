#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "🔨 Building Attendance for macOS..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcodebuild \
  -project AttendanceMac.xcodeproj \
  -scheme AttendanceMac \
  -configuration Debug \
  -derivedDataPath .build/xcode \
  build -quiet

APP_PATH="$DIR/.build/xcode/Build/Products/Debug/AttendanceMac.app"

if [ -d "$APP_PATH" ]; then
    echo "🚀 Launching Attendance Menu Bar App..."
    killall AttendanceMac 2>/dev/null || true
    sleep 0.5
    open "$APP_PATH"
    echo "✅ Attendance Mac is running in your macOS Menu Bar (top-right of screen)!"
else
    echo "❌ Build failed to generate $APP_PATH"
    exit 1
fi
