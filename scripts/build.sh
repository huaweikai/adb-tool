#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DIST="$ROOT/dist"
MACOS="$DIST/macos"
ANDROID="$DIST/android"

APP="ADB Tool"
BUNDLE="adb_tool.app"
EXEC="adb-tool"

mkdir -p "$MACOS" "$ANDROID"

# ---------------- Android helper ----------------
build_android() {
  local src="$ROOT/adb_tool_app/app/build/outputs/apk/release/app-release.apk"

  if [[ -d "$ROOT/adb_tool_app" ]]; then
    (cd "$ROOT/adb_tool_app" && ./gradlew assembleRelease || true)
  fi

  if [[ -f "$src" ]]; then
    cp "$src" "$ROOT/backend/clipboard-helper.apk"
    cp "$src" "$ANDROID/clipboard-helper.apk"
  fi
}

# ---------------- backend ----------------
build_backend() {
  local arch=$(uname -m)
  [[ "$arch" == "arm64" ]] && GOARCH="arm64" || GOARCH="amd64"

  local out="$ROOT/flutter_app/macos/Runner/$EXEC"

  (cd "$ROOT/backend" && \
    GOOS=darwin GOARCH=$GOARCH go build -ldflags="-s -w" -o "$out" .)

  codesign --force --sign - "$out"
}

# ---------------- flutter ----------------
build_flutter() {
  (cd "$ROOT/flutter_app" && flutter pub get)
  (cd "$ROOT/flutter_app" && flutter build macos --release)
}

# ---------------- copy app ----------------
copy_app() {
  local src="$ROOT/flutter_app/build/macos/Build/Products/Release"
  local app="$(ls -1d "$src"/*.app | head -n 1)"

  local arch=$(uname -m)
  local dst="$MACOS/$arch/$BUNDLE"

  rm -rf "$dst"
  mkdir -p "$MACOS/$arch"
  cp -R "$app" "$dst"

  if [[ -f "$ANDROID/clipboard-helper.apk" ]]; then
    mkdir -p "$dst/Contents/Resources"
    cp "$ANDROID/clipboard-helper.apk" "$dst/Contents/Resources/"
  fi
}

# ---------------- dmg ----------------
create_dmg() {
  local raw=$(uname -m)
  local arch="amd64"; [[ "$raw" == "arm64" ]] && arch="arm64"
  local app="$MACOS/$raw/$BUNDLE"
  local ver="${PRODUCT_VERSION:-dev}"
  local dmg="$MACOS/ADBTool-$ver-$arch.dmg"

  rm -rf /tmp/dmg
  mkdir -p /tmp/dmg

  cp -R "$app" "/tmp/dmg/$APP.app"
  ln -s /Applications "/tmp/dmg/Applications"

  hdiutil create \
    -volname "$APP" \
    -srcfolder "/tmp/dmg" \
    -format UDZO \
    -ov \
    "$dmg"
}

build_android
build_backend
build_flutter
copy_app
create_dmg

echo "macOS OK"