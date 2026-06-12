#!/bin/bash
set -e
cd "$(dirname "$0")"

APK_DIR="../adb_tool_app"
APK_SRC="$APK_DIR/app/build/outputs/apk/debug/app-debug.apk"
APK_DST="./clipboard-helper.apk"

if [ -d "$APK_DIR" ]; then
  echo "Building clipboard helper APK..."
  set +e
  (cd "$APK_DIR" && ./gradlew assembleDebug -x lintVitalAnalyzeRelease -x lintVitalReportRelease \
    -x lintAnalyzeRelease -x lintVitalRelease -x lintReportRelease 2>&1)
  GRADLE_EXIT=$?
  set -e
  if [ $GRADLE_EXIT -eq 0 ] && [ -f "$APK_SRC" ]; then
    cp "$APK_SRC" "$APK_DST"
    echo "APK copied to $APK_DST"
  else
    echo "WARNING: APK build failed or not found, using existing $APK_DST"
  fi
else
  echo "WARNING: adb_tool_app not found, using existing clipboard-helper.apk"
fi

echo "Building ADB Tool backend..."
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o ../flutter_app/macos/Runner/adb-tool .
echo "Backend copied to flutter_app/macos/Runner/adb-tool"
