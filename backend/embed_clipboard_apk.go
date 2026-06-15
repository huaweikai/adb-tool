package main

import _ "embed"

// clipboard-helper.apk is embedded at Go build time from backend/clipboard-helper.apk.
//
// Trusted source:
//   - Build from this repository's adb_tool_app/ via scripts/build.ps1 or scripts/build.sh
//     (Gradle assembleDebug -> app-debug.apk copied to backend/clipboard-helper.apk).
//   - Package name must be com.adbtool.clipboard; sources live in adb_tool_app/.
//
// The prebuilt APK committed in the repo should only be updated by building from adb_tool_app/.
// If you do not trust the committed binary, rebuild locally before compiling the Go backend.
//
//go:embed clipboard-helper.apk
var clipboardHelperApk []byte
