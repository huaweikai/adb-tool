#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="release"
PLATFORM=""
GOARCH=""

usage() {
  echo "用法："
  echo "  $(basename "$0") --platform macos|windows --mode debug|release [--arch arm64|amd64]"
  echo ""
  echo "示例："
  echo "  $(basename "$0") --platform macos --mode debug"
  echo "  $(basename "$0") --platform macos --mode release"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="${2:-}"; shift 2;;
    --mode)
      MODE="${2:-}"; shift 2;;
    --arch)
      GOARCH="${2:-}"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "未知参数：$1"
      usage
      exit 1;;
  esac
done

if [[ -z "$PLATFORM" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    PLATFORM="macos"
  else
    echo "未指定 --platform。"
    usage
    exit 1
  fi
fi

if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "--mode 只能是 debug 或 release"
  exit 1
fi

if [[ "$PLATFORM" == "macos" ]]; then
  if [[ -z "$GOARCH" ]]; then
    case "$(uname -m)" in
      arm64) GOARCH="arm64";;
      x86_64) GOARCH="amd64";;
      *) echo "无法识别 CPU 架构：$(uname -m)"; exit 1;;
    esac
  fi

  BACKEND_OUT="$ROOT_DIR/flutter_app/macos/Runner/adb-tool"

  echo "==> 编译后端 (GOOS=darwin GOARCH=$GOARCH)"
  (cd "$ROOT_DIR/backend" && GOOS=darwin GOARCH="$GOARCH" go build -ldflags="-s -w" -o "$BACKEND_OUT" .)
  chmod +x "$BACKEND_OUT"
  echo "后端已输出：$BACKEND_OUT"

  if [[ -z "${SSL_CERT_FILE:-}" && -f "/opt/homebrew/share/ca-certificates/cacert.pem" ]]; then
    export SSL_CERT_FILE="/opt/homebrew/share/ca-certificates/cacert.pem"
  fi

  echo "==> 编译 Flutter macOS ($MODE)"
  (cd "$ROOT_DIR/flutter_app" && flutter build macos "--$MODE")

  MODE_DIR="Release"
  if [[ "$MODE" == "debug" ]]; then MODE_DIR="Debug"; fi

  PRODUCTS_DIR="$ROOT_DIR/flutter_app/build/macos/Build/Products/$MODE_DIR"
  if [[ -d "$PRODUCTS_DIR" ]]; then
    APP_PATH="$(ls -1d "$PRODUCTS_DIR"/*.app 2>/dev/null | head -n 1 || true)"
    if [[ -n "$APP_PATH" ]]; then
      DST="$APP_PATH/Contents/MacOS/adb-tool"
      cp "$BACKEND_OUT" "$DST"
      chmod +x "$DST"
      echo "已确保后端写入 App：$DST"
      echo "产物：$APP_PATH"
    else
      echo "未找到 .app：$PRODUCTS_DIR"
    fi
  else
    echo "未找到构建目录：$PRODUCTS_DIR"
  fi

  exit 0
fi

if [[ "$PLATFORM" == "windows" ]]; then
  echo "Windows 版 Flutter 需要在 Windows 上构建。请在 Windows 上运行 scripts/build.ps1"
  exit 2
fi

echo "不支持的 --platform：$PLATFORM"
exit 1
