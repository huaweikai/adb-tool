#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="release"
PLATFORM=""
GOARCH=""
DIST_MACOS_DIR="$ROOT_DIR/dist/macos"

usage() {
  cat <<'EOF'
用法：
  $(basename "$0") --platform macos|windows --mode debug|release [--arch arm64|amd64|all]

示例：
  $(basename "$0") --platform macos --mode release --arch all
  $(basename "$0") --platform macos --mode debug --arch arm64
  $(basename "$0") --platform macos --mode release --arch amd64

说明：
  --arch 不传则按当前 Mac host 架构构建。
  --arch all 会依次构建 arm64 与 amd64；非 host 架构依赖 Rosetta 2（Apple Silicon）
  或 Apple Silicon 硬件（Intel Mac 上构建 arm64 会失败）。
EOF
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

build_clipboard_apk() {
  local apk_src="$ROOT_DIR/adb_tool_app/app/build/outputs/apk/debug/app-debug.apk"
  local apk_dst="$ROOT_DIR/backend/clipboard-helper.apk"

  if [[ -z "${ANDROID_HOME:-}" ]]; then
    if [[ -f "$apk_dst" ]]; then
      echo "警告: 未设置 ANDROID_HOME，使用已有剪贴板助手 APK：$apk_dst"
      return 0
    fi
    echo "错误: 未设置 ANDROID_HOME，且找不到已有剪贴板助手 APK：$apk_dst"
    echo "请将 ANDROID_HOME 设置为本机 Android SDK 路径后重试。"
    return 1
  fi

  if [[ ! -d "$ROOT_DIR/adb_tool_app" ]]; then
    if [[ -f "$apk_dst" ]]; then
      echo "警告: 未找到 adb_tool_app，使用已有剪贴板助手 APK：$apk_dst"
      return 0
    fi
    echo "错误: 未找到 adb_tool_app，且找不到已有剪贴板助手 APK：$apk_dst"
    return 1
  fi

  echo "==> 编译剪贴板助手 APK..."
  set +e
  (cd "$ROOT_DIR/adb_tool_app" && ./gradlew assembleDebug \
    -x lintVitalAnalyzeRelease -x lintVitalReportRelease -x lintAnalyzeRelease \
    -x lintVitalRelease -x lintReportRelease 2>&1)
  set -e

  if [[ -f "$apk_src" ]]; then
    cp "$apk_src" "$apk_dst"
    echo "APK 已输出到：$apk_dst"
  elif [[ -f "$apk_dst" ]]; then
    echo "警告: APK 构建失败，使用已有的 $apk_dst"
  else
    echo "错误: APK 构建失败，且找不到已有剪贴板助手 APK：$apk_dst"
    echo "请检查 ANDROID_HOME 是否指向有效 Android SDK。"
    return 1
  fi
}

build_macos_one() {
  local target_arch="$1"
  local mode="$2"

  local mode_dir="Release"
  if [[ "$mode" == "debug" ]]; then mode_dir="Debug"; fi

  local backend_out="$ROOT_DIR/flutter_app/macos/Runner/adb-tool"

  build_clipboard_apk

  echo "==> 编译后端 (GOOS=darwin GOARCH=$target_arch)"
  (cd "$ROOT_DIR/backend" && GOOS=darwin GOARCH="$target_arch" go build -ldflags="-s -w" -o "$backend_out" .)
  chmod +x "$backend_out"
  echo "后端已输出：$backend_out"

  # 强制清掉上一次构建的产物，避免 Flutter 复用导致 arch 错乱
  rm -rf "$ROOT_DIR/flutter_app/build/macos"

  if [[ -z "${SSL_CERT_FILE:-}" && -f "/opt/homebrew/share/ca-certificates/cacert.pem" ]]; then
    export SSL_CERT_FILE="/opt/homebrew/share/ca-certificates/cacert.pem"
  fi

  echo "==> 编译 Flutter macOS ($mode, arch=$target_arch)"
  (cd "$ROOT_DIR/flutter_app" && flutter build macos "--$mode")

  local products_dir="$ROOT_DIR/flutter_app/build/macos/Build/Products/$mode_dir"
  local app_path="$(ls -1d "$products_dir"/*.app 2>/dev/null | head -n 1 || true)"
  if [[ -z "$app_path" ]]; then
    echo "错误: 未找到 .app：$products_dir"
    return 1
  fi

  local inner_dst="$app_path/Contents/MacOS/adb-tool"
  cp "$backend_out" "$inner_dst"
  chmod +x "$inner_dst"
  echo "已确保后端写入 App：$inner_dst"

  local target_dist="$DIST_MACOS_DIR/$target_arch"
  mkdir -p "$target_dist"
  rm -rf "$target_dist/adb_tool.app"
  cp -R "$app_path" "$target_dist/adb_tool.app"
  echo "产物：$target_dist/adb_tool.app"
}

if [[ "$PLATFORM" == "macos" ]]; then
  HOST_ARCH_RAW="$(uname -m)"
  case "$HOST_ARCH_RAW" in
    arm64) HOST_ARCH="arm64";;
    x86_64) HOST_ARCH="amd64";;
    *)
      echo "无法识别 host CPU 架构：$HOST_ARCH_RAW"
      exit 1
      ;;
  esac

  if [[ -z "$GOARCH" ]]; then
    TARGETS=("$HOST_ARCH")
  elif [[ "$GOARCH" == "all" ]]; then
    if [[ "$HOST_ARCH" == "arm64" ]]; then
      TARGETS=("arm64" "amd64")
    else
      TARGETS=("amd64" "arm64")
    fi
  elif [[ "$GOARCH" == "arm64" || "$GOARCH" == "amd64" ]]; then
    TARGETS=("$GOARCH")
  else
    echo "--arch 只能是 arm64、amd64 或 all"
    exit 1
  fi

  mkdir -p "$DIST_MACOS_DIR"

  for TARGET in "${TARGETS[@]}"; do
    echo ""
    echo "==============================================="
    echo "  Building macOS / $TARGET / $MODE"
    echo "==============================================="

    if [[ "$TARGET" == "$HOST_ARCH" ]]; then
      build_macos_one "$TARGET" "$MODE"
    else
      case "$TARGET" in
        arm64) SWITCH="arm64";;
        amd64) SWITCH="x86_64";;
        *)
          echo "未知目标架构：$TARGET"
          exit 1
          ;;
      esac

      if arch -"$SWITCH" /usr/bin/true 2>/dev/null; then
        echo "==> 跨架构构建：切换到 $TARGET (arch -$SWITCH)"
        QUIET_FINAL=1 arch -"$SWITCH" "$0" --platform macos --mode "$MODE" --arch "$TARGET"
      else
        echo "错误: host=$HOST_ARCH 无法切到 $TARGET（需要 Rosetta 2 / Apple Silicon）"
        exit 1
      fi
    fi
  done

  if [[ "${QUIET_FINAL:-0}" != "1" ]]; then
    echo ""
    echo "==> 所有 macOS 构建完成："
    for d in "$DIST_MACOS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      echo "    $d"
    done
  fi

  exit 0
fi

if [[ "$PLATFORM" == "windows" ]]; then
  echo "Windows 版 Flutter 需要在 Windows 上构建。请在 Windows 上运行 scripts/build.ps1"
  exit 2
fi

echo "不支持的 --platform：$PLATFORM"
exit 1