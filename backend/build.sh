#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building ADB Tool backend..."
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o ../flutter_app/macos/Runner/adb-tool .
echo "Backend copied to flutter_app/macos/Runner/adb-tool"
