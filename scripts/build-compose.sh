#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="release"
PLATFORM=""
GOARCH=""
PACKAGE="false"

usage() {
  echo "用法："
  echo "  $(basename "$0") --platform macos|windows --mode debug|release [--arch arm64|amd64] [--package]"
  echo ""
  echo "示例："
  echo "  $(basename "$0") --platform macos --mode debug"
  echo "  $(basename "$0") --platform macos --mode release"
  echo "  $(basename "$0") --platform macos --mode release --package"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="${2:-}"; shift 2;;
    --mode)
      MODE="${2:-}"; shift 2;;
    --arch)
      GOARCH="${2:-}"; shift 2;;
    --package)
      PACKAGE="true"; shift;;
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "找不到命令：$1"
    exit 1
  fi
}

find_gradle() {
  local wrapper="$ROOT_DIR/compose_app/gradlew"
  local wrapper_jar="$ROOT_DIR/compose_app/gradle/wrapper/gradle-wrapper.jar"

  if [[ -x "$wrapper" && -f "$wrapper_jar" ]]; then
    echo "$wrapper"
    return
  fi

  if command -v gradle >/dev/null 2>&1; then
    command -v gradle
    return
  fi

  local cached_gradle
  cached_gradle="$(find "$HOME/.gradle/wrapper/dists" -path '*/bin/gradle' -type f 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "$cached_gradle" ]]; then
    echo "$cached_gradle"
    return
  fi

  echo ""
}

build_clipboard_helper_apk() {
  local apk_src="$ROOT_DIR/adb_tool_app/app/build/outputs/apk/debug/app-debug.apk"
  local apk_dst="$ROOT_DIR/backend/clipboard-helper.apk"

  if [[ -z "${ANDROID_HOME:-}" ]]; then
    if [[ -f "$apk_dst" ]]; then
      echo "警告: 未设置 ANDROID_HOME，使用已有剪贴板助手 APK：$apk_dst"
      return
    fi
    echo "错误: 未设置 ANDROID_HOME，且找不到已有剪贴板助手 APK：$apk_dst"
    echo "请将 ANDROID_HOME 设置为本机 Android SDK 路径后重试。"
    exit 1
  fi

  if [[ ! -d "$ROOT_DIR/adb_tool_app" ]]; then
    if [[ -f "$apk_dst" ]]; then
      echo "警告: 未找到 adb_tool_app，使用已有剪贴板助手 APK：$apk_dst"
      return
    fi
    echo "错误: 未找到 adb_tool_app，且找不到已有剪贴板助手 APK：$apk_dst"
    exit 1
  fi

  echo "==> 编译剪贴板助手 APK..."
  set +e
  (cd "$ROOT_DIR/adb_tool_app" && ./gradlew assembleDebug \
    -x lintVitalAnalyzeRelease -x lintVitalReportRelease -x lintAnalyzeRelease \
    -x lintVitalRelease -x lintReportRelease 2>&1)
  local gradle_exit=$?
  set -e

  if [[ $gradle_exit -eq 0 && -f "$apk_src" ]]; then
    cp "$apk_src" "$apk_dst"
    echo "APK 已输出到：$apk_dst"
  elif [[ -f "$apk_dst" ]]; then
    echo "警告: APK 构建失败，使用已有的 $apk_dst"
  else
    echo "错误: APK 构建失败，且找不到已有剪贴板助手 APK：$apk_dst"
    echo "请检查 ANDROID_HOME 是否指向有效 Android SDK。"
    exit 1
  fi
}

build_backend() {
  local goos="$1"
  local backend_out="$2"

  require_command go
  echo "==> 编译后端 (GOOS=$goos GOARCH=$GOARCH)"
  (cd "$ROOT_DIR/backend" && GOOS="$goos" GOARCH="$GOARCH" go build -ldflags="-s -w" -o "$backend_out" .)
  chmod +x "$backend_out" 2>/dev/null || true
  echo "后端已输出：$backend_out"
}

build_compose() {
  local gradle_bin="$1"
  local task="createReleaseDistributable"

  if [[ "$MODE" == "debug" ]]; then
    task="createDistributable"
  fi

  if [[ "$PACKAGE" == "true" ]]; then
    if [[ "$MODE" == "release" ]]; then
      task="packageReleaseDistributionForCurrentOS"
    else
      task="packageDistributionForCurrentOS"
    fi
  fi

  echo "==> 编译 Compose Desktop ($MODE, task=$task)"
  (cd "$ROOT_DIR/compose_app" && "$gradle_bin" ":desktopApp:$task" --console=plain -Dkotlin.compiler.execution.strategy=in-process)
}

copy_backend_to_macos_app() {
  local backend_out="$1"
  local app_root="$ROOT_DIR/compose_app/desktopApp/build/compose/binaries/main/app"
  local app_path

  app_path="$(find "$app_root" -maxdepth 2 -name '*.app' -type d 2>/dev/null | head -n 1 || true)"
  if [[ -z "$app_path" ]]; then
    echo "未找到 Compose .app：$app_root"
    return
  fi

  local dst="$app_path/Contents/MacOS/adb-tool"
  cp "$backend_out" "$dst"
  chmod +x "$dst"
  echo "已确保后端写入 App：$dst"
  echo "产物：$app_path"
}

if [[ "$PLATFORM" == "macos" ]]; then
  if [[ -z "$GOARCH" ]]; then
    case "$(uname -m)" in
      arm64) GOARCH="arm64";;
      x86_64) GOARCH="amd64";;
      *) echo "无法识别 CPU 架构：$(uname -m)"; exit 1;;
    esac
  fi

  gradle_bin="$(find_gradle)"
  if [[ -z "$gradle_bin" ]]; then
    echo "找不到可用 Gradle。当前 compose_app/gradle/wrapper/gradle-wrapper.jar 缺失，请修复 wrapper 或安装 gradle。"
    exit 1
  fi

  build_clipboard_helper_apk

  backend_out="$ROOT_DIR/compose_app/desktopApp/build/runtime/adb-tool"
  mkdir -p "$(dirname "$backend_out")"
  build_backend darwin "$backend_out"

  build_compose "$gradle_bin"
  copy_backend_to_macos_app "$backend_out"
  exit 0
fi

if [[ "$PLATFORM" == "windows" ]]; then
  echo "Windows 版 Compose 建议在 Windows 上构建。请后续使用 scripts/build-compose.ps1。"
  exit 2
fi

echo "不支持的 --platform：$PLATFORM"
exit 1
