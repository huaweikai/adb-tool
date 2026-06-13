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

  APK_SRC="$ROOT_DIR/adb_tool_app/app/build/outputs/apk/debug/app-debug.apk"
  APK_DST="$ROOT_DIR/backend/clipboard-helper.apk"
  if [[ -z "${ANDROID_HOME:-}" ]]; then
    if [[ -f "$APK_DST" ]]; then
      echo "警告: 未设置 ANDROID_HOME，使用已有剪贴板助手 APK：$APK_DST"
    else
      echo "错误: 未设置 ANDROID_HOME，且找不到已有剪贴板助手 APK：$APK_DST"
      echo "请将 ANDROID_HOME 设置为本机 Android SDK 路径后重试。"
      exit 1
    fi
  elif [[ -d "$ROOT_DIR/adb_tool_app" ]]; then
    echo "==> 编译剪贴板助手 APK..."
    set +e
    (cd "$ROOT_DIR/adb_tool_app" && ./gradlew assembleDebug \
      -x lintVitalAnalyzeRelease -x lintVitalReportRelease -x lintAnalyzeRelease \
      -x lintVitalRelease -x lintReportRelease 2>&1)
    set -e
    if [[ -f "$APK_SRC" ]]; then
      cp "$APK_SRC" "$APK_DST"
      echo "APK 已输出到：$APK_DST"
    elif [[ -f "$APK_DST" ]]; then
      echo "警告: APK 构建失败，使用已有的 $APK_DST"
    else
      echo "错误: APK 构建失败，且找不到已有剪贴板助手 APK：$APK_DST"
      echo "请检查 ANDROID_HOME 是否指向有效 Android SDK。"
      exit 1
    fi
  elif [[ -f "$APK_DST" ]]; then
    echo "警告: 未找到 adb_tool_app，使用已有剪贴板助手 APK：$APK_DST"
  else
    echo "错误: 未找到 adb_tool_app，且找不到已有剪贴板助手 APK：$APK_DST"
    exit 1
  fi

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
