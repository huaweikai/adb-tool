#!/usr/bin/env bash
# scripts/dev.sh — 开发模式一键启动
#
# 跟 scripts/build.sh（生产打包）分开，专为日常开发循环优化：
#   - 不清 build/ 目录，全部走增量编译（Gradle / Go / Flutter 都复用上次产物）
#   - 不做跨架构合并、不做 ad-hoc 签名（Flutter 调试运行自己处理）
#   - Flutter 走 `flutter run` 而不是 `flutter build`，启用 hot reload
#
# 流程：
#   1. 编译 Android 辅助 App（debug APK）→ backend/clipboard-helper.apk
#   2. 编译 Go 后端 → flutter_app/macos/Runner/adb-tool
#   3. 启动 Flutter（debug，前台阻塞，按 Ctrl+C 退出）
#
# 用法：
#   scripts/dev.sh                        # 全部三步，最后 flutter run
#   scripts/dev.sh --skip-apk             # 跳过 Android 编译（Android 代码没改时）
#   scripts/dev.sh --skip-backend         # 跳过 Go 编译（Go 代码没改时）
#   scripts/dev.sh --device macos         # 指定 Flutter 目标设备
#   scripts/dev.sh --build-only           # 只编译不启动
#   scripts/dev.sh --backend-only         # 只编译后端，不动 APK，不启动 Flutter

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKIP_APK=0
SKIP_BACKEND=0
BUILD_ONLY=0
BACKEND_ONLY=0
DEVICE=""

usage() {
  sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-apk)        SKIP_APK=1; shift;;
    --skip-backend)    SKIP_BACKEND=1; shift;;
    --build-only)      BUILD_ONLY=1; shift;;
    --backend-only)    BACKEND_ONLY=1; SKIP_APK=1; BUILD_ONLY=1; shift;;
    --device)          DEVICE="${2:-}"; shift 2;;
    -h|--help)         usage; exit 0;;
    *)                 echo "未知参数：$1"; usage; exit 1;;
  esac
done

# ---------------------------------------------------------------------------
# 环境修正：profile 里 ANDROID_HOME 默认指向外部驱动器，沙盒阻止访问。
# 强制 unset 并指向 ~/.adb-tool/sdk/（真正工作的 SDK）。不修正的话 gradle、
# avdmanager、flutter CLI 都会炸（Permission denied / file system sandbox blocked）。
# ---------------------------------------------------------------------------
unset ANDROID_HOME
unset ANDROID_SDK_ROOT
export ANDROID_HOME="$HOME/.adb-tool/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Flutter 在大陆偶尔 SSL 抽风，加 ca bundle
if [[ -z "${SSL_CERT_FILE:-}" && -f "/opt/homebrew/share/ca-certificates/cacert.pem" ]]; then
  export SSL_CERT_FILE="/opt/homebrew/share/ca-certificates/cacert.pem"
fi

step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Step 1: Android 辅助 App
# ---------------------------------------------------------------------------
build_android_apk() {
  local apk_src="$ROOT/adb_tool_app/app/build/outputs/apk/debug/app-debug.apk"
  local apk_dst="$ROOT/backend/clipboard-helper.apk"

  if [[ ! -d "$ROOT/adb_tool_app" ]]; then
    warn "未找到 adb_tool_app/，跳过 APK 编译"
    return 0
  fi

  step "编译 Android 辅助 APK (debug)..."

  # local.properties 里 sdk.dir 指向外部驱动器（被沙盒阻止），用 ANDROID_HOME 覆盖
  # Gradle 优先级：ANDROID_HOME env > local.properties sdk.dir
  #
  # Fix (code-review M15): `set -o pipefail` interacts badly with a bare
  # `2>&1 | tail -50` — in some shells gradle's non-zero exit gets
  # masked. Pipe through `tee` so we keep the full log on disk AND
  # surface the tail to the user, then check gradle's own exit code
  # explicitly via ${PIPESTATUS[0]}.
  local gradle_log="/tmp/adb-tool-gradle-$$.log"
  local gradle_exit=0
  (cd "$ROOT/adb_tool_app" && ./gradlew assembleDebug \
        -x lintVitalAnalyzeRelease -x lintVitalReportRelease \
        -x lintAnalyzeRelease -x lintVitalRelease -x lintReportRelease \
        --console=plain 2>&1 | tee "$gradle_log" | tail -50) || gradle_exit=${PIPESTATUS[0]}
  if [[ "$gradle_exit" -ne 0 ]]; then
    if [[ -f "$apk_dst" ]]; then
      warn "Android 编译失败，沿用已有的 $apk_dst"
      return 0
    fi
    die "Android 编译失败，且 backend/clipboard-helper.apk 不存在；先修 Android 构建（log: $gradle_log）"
  fi

  if [[ ! -f "$apk_src" ]]; then
    if [[ -f "$apk_dst" ]]; then
      warn "未在预期位置找到 $apk_src，沿用已有的 $apk_dst"
      return 0
    fi
    die "Android 编译未产出 APK，且没有现成 APK 可用"
  fi

  cp "$apk_src" "$apk_dst"
  ok "APK 已复制：$apk_dst"
}

# ---------------------------------------------------------------------------
# Step 2: Go 后端 → flutter_app/macos/Runner/adb-tool
# ---------------------------------------------------------------------------
build_go_backend() {
  local out="$ROOT/flutter_app/macos/Runner/adb-tool"

  step "编译 Go 后端 → $out"

  (cd "$ROOT/backend" && go build -o "$out" .)
  chmod +x "$out"

  # Flutter 调试运行也需要这个 binary 能被签名（macOS），用 ad-hoc 签一下，
  # 否则首次 flutter run 在 codesign 阶段会失败。
  if ! codesign --force --sign - "$out" 2>/dev/null; then
    warn "adb-tool 签名失败，Flutter 首次构建可能会拒绝；如果出现 codesign 报错，重跑一次"
  fi

  ok "后端已编译并签名"
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
[[ $SKIP_APK -eq 0 ]]     && build_android_apk
[[ $SKIP_BACKEND -eq 0 ]] && build_go_backend

if [[ $BUILD_ONLY -eq 1 ]]; then
  ok "编译完成（--build-only，不启动 Flutter）"
  exit 0
fi

step "启动 Flutter (debug, hot reload 模式；Ctrl+C 退出)"
cd "$ROOT/flutter_app"
exec flutter run ${DEVICE:+-d "$DEVICE"} --debug