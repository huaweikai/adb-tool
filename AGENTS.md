# AGENTS.md

ADB Tool — 跨平台 Android 调试桌面工具，**Go 后端 + Flutter 桌面端 + Android 剪贴板辅助 APK**，仅支持 macOS 和 Windows。详细架构见 `PROJECT_OVERVIEW.md` 与 `.harness/docs/architecture.md`。

## Setup commands

- 后端依赖: `cd backend && go mod download`
- 后端运行: `cd backend && go run .` — 默认监听 `http://localhost:9876`
- 前端依赖: `cd flutter_app && flutter pub get`
- 前端运行 (macOS): `cd flutter_app && flutter run -d macos`
- 前端运行 (Windows): `cd flutter_app && flutter run -d windows`
- 构建 macOS app: `bash scripts/build.sh --platform macos --mode release [--arch arm64|amd64|all|universal]`
- 构建 Windows MSI: `powershell scripts/build.ps1 -Mode Release -Platform Windows -GoArch amd64`

## Project layout

- `backend/` — Go 1.26.3，net/http + gorilla/websocket。`internal/server/` 按功能拆 `adb_*.go` / `handlers_*.go` / `scrcpy_*.go` / `recovery.go` / `security.go`。**平台条件编译** `//go:build darwin` / `//go:build windows` 嵌入不同 platform-tools 和 scrcpy。
- `flutter_app/` — Flutter 3.4+ / Dart 3.4+，桌面端 macOS + Windows。`lib/models/` 数据模型、`lib/db/` drift SQLite、`lib/providers/` 全局状态、`lib/services/api/` 按域 REST 客户端（10 个）、`lib/screens/` 12 个页面（含 `test_session/` 子包）、`lib/i18n/` 中英文字典按页拆分、`lib/widgets/` 复用组件、`macos/Runner/` Swift + `windows/runner/` C++ 平台原生层（拖放 COM/NSView）。
- `adb_tool_app/` — Kotlin 剪贴板辅助 APK（AGP 9.1.1，Java 11，minSdk 24）。`SetClipboardActivity` 通过 Base64 文本写入系统剪贴板。
- `scripts/` — `build.sh` (macOS)、`build.ps1` (Windows + WiX MSI)、`idea-build.ps1`、`check_i18n_tr_keys.py`、`reset-db.ps1`。
- `api/` — 后端统一 envelope 协议与接口字段文档（见 `api/README.md`）。
- `docs/` — 架构与方案文档（例：`OPTIMIZATION_PROPOSAL.md`）。

## Code style

- **Go**: handler 与 adb 封装分层；统一 envelope `{ok, data, error}`（见 `internal/server/response.go`），但二进制端点（截图 / 文件下载 / 录屏）跳过 envelope。`security.go` 强制 loopback-only。
- **Dart**: `lib/<layer>/<domain>.dart` 按层 × 域拆分；Provider 状态管理、drift 本地持久化；加 endpoint 时优先在 `lib/services/api/<domain>_api.dart` 单文件加，影响面最小。`analysis_options.yaml` 继承 `package:flutter_lints/flutter.yaml`。
- **i18n**: 中英文按页面分文件（`flutter_app/lib/i18n/<page>.dart`），CI 用 `scripts/check_i18n_tr_keys.py` 校验 key 完整性。
- **平台条件编译**: Go 端用 `//go:build darwin|windows`；Flutter 端用 `defaultTargetPlatform` + MethodChannel（`mac_drop` / `win_drop`）。
- **Backend embedding**: `platform-tools-*.zip`、`scrcpy` 与 `clipboard-helper.apk` 全部 `//go:embed` 进二进制，运行时提取到 `/tmp/adb-tool-cache/`。

## Testing instructions

- Go 单元测试: `cd backend && go test ./...`
- Flutter 单元 / widget 测试: `cd flutter_app && flutter test`
- i18n key 完整性: `python scripts/check_i18n_tr_keys.py`
- 新功能必须配单测（参考 `flutter_app/test/` 与 `backend/internal/server/*_test.go` 已有风格）。
- 端到端冒烟: 启动后端 → `flutter run` → 在设备页面切到 ADB 指令面板 → 各分类指令跑一遍。

## PR & commit conventions

- 分支从 `main` 拉，**不要直接 push 到 main**。
- Commit 格式: conventional commits，`feat:` / `fix:` / `docs:` / `refactor:` / `chore:` / `ci:`，建议带 scope，如 `feat(flutter):` / `fix(backend):` / `ci(release):`。
- Push 后 PR 描述说明：改了哪些模块 / 关联 issue / 回归测试结果。

## Security

- 后端仅 loopback（`localhost:9876`），外部不可访问（`internal/server/security.go`）。
- **不要 commit**: `.env` / `adb_tool_app/local.properties` / keystore / `~/.android/` / 任何签名后的 APK。`backend/clipboard-helper.apk` 由构建脚本生成（基于仓库内已签 debug APK 或重新构建）。
- 构建产物 `backend/adb-tool`、`flutter_app/macos/Runner/adb-tool`、`flutter_app/windows/runner/Resources/runtime.exe` 已在 `.gitignore`，**不要 commit**。
- `wifi adb` 暴露端口默认开；用户主动操作时再开。

## Workspace rules — 不可违反

- **不要自动 commit / push**。所有 `git commit` / `git push` / `gh pr create` 必须用户明确同意。
- 允许的 git 操作（无需许可）: `git status`、`git diff`、`git log`、`git stash`、`git add`。
- 改完代码先给出修改清单，等用户 ack 再 commit。

## Environment notes

- **日常开发**: macOS（用户本机），用 `flutter run -d macos` 跑桌面端。
- **Windows 桌面构建**: 必须在 Windows 上跑 `scripts/build.ps1`，macOS 上跑不了（Flutter Windows runner 链不通）。
- **CI**: `.github/workflows/release.yml` 在 tag 推送时跑三路（windows-latest / macos-14 / macos-13）→ MSI + arm64/amd64 macOS zip → GitHub Release。