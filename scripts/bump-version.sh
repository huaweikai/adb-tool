#!/usr/bin/env bash
# Bump version across all project files and create a git tag.
#
# Usage:
#   ./scripts/bump-version.sh <version> <build> [--tag]
#
# Examples:
#   ./scripts/bump-version.sh 1.3.0 6          # only update files
#   ./scripts/bump-version.sh 1.3.0 6 --tag    # update files + commit + tag

set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

# Portable in-place sed: works on both macOS (BSD sed) and Linux/Git Bash (GNU sed).
sed_replace() {
  local file="$1" pattern="$2" replacement="$3"
  sed "s|$pattern|$replacement|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

if [ $# -lt 2 ]; then
  die "Usage: bump-version.sh <version> <build> [--tag]"
fi

version="$1"
build="$2"
do_tag=false
for arg in "$@"; do [ "$arg" = "--tag" ] && do_tag=true; done

# Validate format
echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "version must be in X.Y.Z format, got '$version'"
echo "$build"   | grep -qE '^[0-9]+$'               || die "build must be a number, got '$build'"

root="$(cd "$(dirname "$0")/.." && pwd)"

# Read current version from pubspec.yaml
pubspec="$root/flutter_app/pubspec.yaml"
old_full="$(grep '^version:' "$pubspec" | awk '{print $2}')"
[ -n "$old_full" ] || die "cannot parse version from flutter_app/pubspec.yaml"

old_ver="${old_full%+*}"
old_build="${old_full#*+}"
[ "$old_build" = "$old_full" ] && old_build="0"

echo "Bumping $old_full -> $version+$build"
echo

# 1. pubspec.yaml — canonical source, build scripts read it automatically
sed_replace "$root/flutter_app/pubspec.yaml" \
  "version: $old_full" "version: $version+$build"
echo "  patched flutter_app/pubspec.yaml"

# 2. build.ps1 default (fallback when running locally without CI)
sed_replace "$root/scripts/build.ps1" \
  "\(\[string\]\$ProductVersion = '\)[^']*'" "\\1$version'"
echo "  patched scripts/build.ps1"

# 3. idea-build.ps1 default (fallback when running locally without CI)
sed_replace "$root/scripts/idea-build.ps1" \
  "\(\[string\]\$ProductVersion = '\)[^']*'" "\\1$version'"
echo "  patched scripts/idea-build.ps1"

echo
echo "All files updated: $old_full -> $version+$build"

if $do_tag; then
  tag="v$version"
  msg="chore: bump version to $version+$build"

  git -C "$root" add -A
  git -C "$root" commit -m "$msg"
  git -C "$root" tag -a "$tag" -m "v$version"
  echo "Committed and tagged $tag."
else
  echo "Skipped git commit/tag (pass --tag to enable)."
fi
