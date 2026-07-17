#!/usr/bin/env bash
# Bump clipboard helper APK version across Android project and Go backend.
#
# Usage:
#   ./scripts/bump-clipboard-helper.sh <versionCode> <versionName>
#
# Example:
#   ./scripts/bump-clipboard-helper.sh 3 1.2
#
# This updates both:
#   - adb_tool_app/app/build.gradle.kts   (versionCode + versionName)
#   - backend/internal/server/adb_clipboard.go (clipboardHelperVersionCode)

set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

if [ $# -ne 2 ]; then
  die "Usage: bump-clipboard-helper.sh <versionCode> <versionName>"
fi

new_code="$1"
new_name="$2"

echo "$new_code" | grep -qE '^[0-9]+$' || die "versionCode must be a number, got '$new_code'"
echo "$new_name" | grep -qE '^[0-9]+\.[0-9]+$' || die "versionName must be in X.Y format, got '$new_name'"

root="$(cd "$(dirname "$0")/.." && pwd)"

gradle="$root/adb_tool_app/app/build.gradle.kts"
go_file="$root/backend/internal/server/adb_clipboard.go"

# Read current values for confirmation
old_code="$(grep -E '^\s+versionCode\s*=\s*[0-9]+' "$gradle" | grep -oE '[0-9]+')"
old_name="$(grep -E '^\s+versionName\s*=\s*"[^"]+"' "$gradle" | sed 's/.*"\(.*\)".*/\1/')"
old_go="$(grep -E '^const clipboardHelperVersionCode\s*=\s*[0-9]+' "$go_file" | grep -oE '[0-9]+')"

echo "Bumping clipboard helper:"
echo "  build.gradle.kts:  $old_code / \"$old_name\" -> $new_code / \"$new_name\""
echo "  adb_clipboard.go:  $old_go -> $new_code"
echo

# 1. Update build.gradle.kts
sed_replace() {
  local file="$1" pattern="$2" replacement="$3"
  sed "s|$pattern|$replacement|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

sed_replace "$gradle" \
  "versionCode = $old_code" "versionCode = $new_code"
sed_replace "$gradle" \
  "versionName = \"$old_name\"" "versionName = \"$new_name\""
echo "  patched adb_tool_app/app/build.gradle.kts"

# 2. Update adb_clipboard.go
sed_replace "$go_file" \
  "clipboardHelperVersionCode = $old_go" "clipboardHelperVersionCode = $new_code"
echo "  patched backend/internal/server/adb_clipboard.go"

echo
echo "Done. Both files are in sync at versionCode=$new_code, versionName=\"$new_name\"."
