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
  $(basename "$0") --platform macos|windows --mode debug|release [--arch arm64|amd64|all|universal]

示例：
  $(basename "$0") --platform macos --mode release --arch all
  $(basename "$0") --platform macos --mode debug --arch arm64
  $(basename "$0") --platform macos --mode release --arch amd64
  $(basename "$0") --platform macos --mode release --arch universal

说明：
  --arch 不传则按当前 Mac host 架构构建。
  --arch all 会依次构建 arm64 与 amd64 分开的包；非 host 架构依赖 Rosetta 2。
  --arch universal 会构建通用包（arm64 + amd64 合并为一个 app）。
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

  # 为 adb-tool 添加 ad-hoc 签名（Flutter 构建时会检查签名）
  echo "==> 签名 adb-tool..."
  if ! codesign --force --sign - "$backend_out"; then
    echo "错误: adb-tool 签名失败,Flutter 会拒绝打包"
    codesign -dv "$backend_out" 2>&1 || true
    exit 1
  fi
  codesign -dv "$backend_out" 2>&1 | head -3

  echo "后端已输出并签名：$backend_out"

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

  # Flutter 构建已经包含签名后的 adb-tool，直接用
  echo "App 已生成：$app_path"

  local target_dist="$DIST_MACOS_DIR/$target_arch"
  mkdir -p "$target_dist"
  rm -rf "$target_dist/adb_tool.app"
  cp -R "$app_path" "$target_dist/adb_tool.app"
  echo "产物：$target_dist/adb_tool.app"
}

# 合并两个架构的 app 为 universal app
merge_to_universal() {
  local arm64_app="$DIST_MACOS_DIR/arm64/adb_tool.app"
  local amd64_app="$DIST_MACOS_DIR/amd64/adb_tool.app"
  local universal_app="$DIST_MACOS_DIR/adb_tool.app"

  if [[ ! -d "$arm64_app" ]]; then
    echo "错误: 找不到 arm64 app：$arm64_app"
    return 1
  fi
  if [[ ! -d "$amd64_app" ]]; then
    echo "错误: 找不到 amd64 app：$amd64_app"
    return 1
  fi

  echo "==> 以 arm64 为基础构建 universal app..."

  # 复制 arm64 版本作为基础
  rm -rf "$universal_app"
  cp -R "$arm64_app" "$universal_app"

  # 合并主程序 adb-tool
  echo "  合并 adb-tool..."
  lipo -create \
    "$arm64_app/Contents/MacOS/adb-tool" \
    "$amd64_app/Contents/MacOS/adb-tool" \
    -output "$universal_app/Contents/MacOS/adb-tool"
  chmod +x "$universal_app/Contents/MacOS/adb-tool"

  # 合并 Flutter 引擎 (FlutterMacOS.framework)
  local arm64_fw="$arm64_app/Contents/Frameworks/FlutterMacOS.framework"
  local amd64_fw="$amd64_app/Contents/Frameworks/FlutterMacOS.framework"
  local uni_fw="$universal_app/Contents/Frameworks/FlutterMacOS.framework"

  if [[ -d "$arm64_fw" && -d "$amd64_fw" ]]; then
    echo "  合并 FlutterMacOS.framework..."
    rm -rf "$uni_fw"
    cp -R "$arm64_fw" "$universal_app/Contents/Frameworks/"

    # 合并 FlutterMacOS 二进制
    lipo -create \
      "$arm64_fw/Contents/MacOS/FlutterMacOS" \
      "$amd64_fw/Contents/MacOS/FlutterMacOS" \
      -output "$uni_fw/Contents/MacOS/FlutterMacOS"
  fi

  # 合并其他 frameworks (如果有的话)
  for fw in "$arm64_app/Contents/Frameworks"/*.framework; do
    [[ -e "$fw" ]] || continue
    local fw_name="$(basename "$fw")"
    # Skip the Flutter engine framework — it was handled above with its
    # own $uni_fw path.
    [[ "$fw_name" == "FlutterMacOS.framework" ]] && continue
    local arm64_bin="$fw/Contents/MacOS/$fw_name"
    local amd64_bin="$amd64_app/Contents/Frameworks/$fw_name/Contents/MacOS/$fw_name"

    if [[ -f "$arm64_bin" && -f "$amd64_bin" ]]; then
      echo "  合并 $fw_name..."
      # Fix (code-review M14): each non-Flutter framework needs its OWN
      # output dir under Contents/Frameworks/<fw_name>/Contents/MacOS/<fw_name>.
      # The previous code wrote all merged binaries into
      # FlutterMacOS.framework/Contents/MacOS/<fw_name>, so they ended up
      # in the wrong framework and dlopen() at runtime failed to find
      # the architecture-specific binary.
      local dst_bin="$universal_app/Contents/Frameworks/$fw_name/Contents/MacOS/$fw_name"
      mkdir -p "$(dirname "$dst_bin")"
      lipo -create "$arm64_bin" "$amd64_bin" -output "$dst_bin"
    fi
  done

  # Fix (code-review B11): every lipo above writes a NEW fat binary, which
  # invalidates the ad-hoc signature carried over from the arm64 base copy.
  # Without re-signing, Gatekeeper refuses to launch the universal app
  # ("damaged" / "cannot be opened"). Re-sign with ad-hoc (the "-" identity)
  # since this is a local-dev distribution; CI/release uses a real cert.
  echo "==> 重新签名 universal app..."
  for fw in "$universal_app/Contents/Frameworks"/*.framework; do
    [[ -d "$fw" ]] || continue
    local fw_name="$(basename "$fw")"
    local fw_bin="$fw/Contents/MacOS/$fw_name"
    if [[ -f "$fw_bin" ]]; then
      codesign --force --sign - --timestamp=none "$fw_bin" >/dev/null 2>&1 || true
    fi
  done
  # Main helper binary (the Go-built adb-tool), then the whole .app so
  # Gatekeeper's nested-code check passes.
  codesign --force --sign - --timestamp=none \
    "$universal_app/Contents/MacOS/adb-tool" >/dev/null 2>&1 || true
  codesign --force --sign - --deep --timestamp=none "$universal_app" \
    >/dev/null 2>&1 || true

  echo "==> Universal app 已生成：$universal_app"
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
  elif [[ "$GOARCH" == "arm64" || "$GOARCH" == "amd64" || "$GOARCH" == "universal" ]]; then
    if [[ "$GOARCH" == "universal" ]]; then
      if [[ "$HOST_ARCH" == "arm64" ]]; then
        TARGETS=("arm64" "amd64")
      else
        TARGETS=("amd64" "arm64")
      fi
      IS_UNIVERSAL=1
    else
      TARGETS=("$GOARCH")
    fi
  else
    echo "--arch 只能是 arm64、amd64、all 或 universal"
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

  # 如果是 universal 模式，合并两个架构
  if [[ "${IS_UNIVERSAL:-0}" == "1" && "${QUIET_FINAL:-0}" != "1" ]]; then
    echo ""
    echo "==> 合并为 Universal App..."
    merge_to_universal
  fi

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