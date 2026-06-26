# ADB Tool — 架构速查

> 给 reins 用的项目知识底座。详细文档见 `PROJECT_OVERVIEW.md`、`api/README.md`。
> 本文件聚焦"项目结构 + 跨层契约 + 关键约束"，避免 reins 在 agent.md body 内大量重复。

## 一、三层架构

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter 桌面端 (flutter_app/)                                │
│   macOS (Swift AppDelegate + MainFlutterWindow + DropOverlay)│
│   Windows (C++ runner + IDropTarget COM)                     │
│   Dart: Provider + drift + dio + web_socket_channel          │
└────────────────────────┬────────────────────────────────────┘
                         │ http://localhost:9876  (loopback only)
                         │ WebSocket /ws/logs
┌────────────────────────┴────────────────────────────────────┐
│ Go 后端 (backend/)                                          │
│   net/http + gorilla/websocket                               │
│   internal/server/{adb_*, handlers_*, scrcpy_*, recovery,    │
│                     security, response, backend_logger, log_ │
│                     stream, session_logcat, logging_        │
│                     middleware, server}                       │
│   embed: platform-tools-{darwin,windows}.zip + scrcpy +       │
│          clipboard-helper.apk                                 │
└────────────────────────┬────────────────────────────────────┘
                         │ adb shell / adb exec-out / adb pull ...
┌────────────────────────┴────────────────────────────────────┐
│ Android 设备 (含 adb_tool_app/ 剪贴板 APK)                  │
│   SetClipboardActivity.kt: 透明 Activity，Base64 解码写剪贴板│
└─────────────────────────────────────────────────────────────┘
```

## 二、统一 envelope（HTTP API）

```json
// 成功
{ "ok": true,  "data": { ... } }

// 失败
{ "ok": false, "data": null, "error": "serial required" }
```

- 实现：`backend/internal/server/response.go`
- 文档：`api/README.md`
- **二进制端点例外**：截图 (`/api/screenshot`)、文件下载 (`/api/pull-file`)、录屏视频 (`/api/screen-record-video`) — 这些返回原始字节流，不包 envelope
- 路由注册：`backend/internal/server/server.go`

## 三、loopback-only 安全

- `internal/server/security.go` 限制后端只接 `127.0.0.1` / `::1`
- `/api/shutdown` 仅 loopback 可调
- 不要在 PR 里放宽这个限制；任何"远程访问"需求应单独评估

## 四、嵌入式资源 + 平台条件编译

| 文件 | Build tag | 内容 |
|---|---|---|
| `embed_darwin.go` | `darwin` | macOS platform-tools |
| `embed_windows.go` | `windows` | Windows platform-tools |
| `embed_fallback.go` | `!darwin && !windows` | 回退到 darwin（基本不命中） |
| `embed_scrcpy_darwin.go` | `darwin` | macOS scrcpy (arm64 + x86_64) |
| `embed_scrcpy_windows.go` | `windows` | Windows scrcpy (386 + amd64) |
| `embed_scrcpy_fallback.go` | `!darwin && !windows` | 空实现 |
| `embed_clipboard_apk.go` | 通用 | `clipboard-helper.apk` |

加新嵌入资源时三件套齐：`embed_xxx_<platform>.go` × 2 + `embed_xxx_fallback.go`。

## 五、Flutter 端关键路径

| 关注点 | 路径 |
|---|---|
| 入口 + Provider 装配 | `flutter_app/lib/main.dart` |
| i18n 入口（按文件 part） | `flutter_app/lib/i18n.dart` + `flutter_app/lib/i18n/*.dart` |
| API 客户端 facade | `flutter_app/lib/services/api_client.dart` |
| 按域 REST 客户端 | `flutter_app/lib/services/api/<domain>_api.dart`（10+ 文件） |
| WebSocket logcat | `flutter_app/lib/services/log_stream.dart` |
| 后端进程管理 | `flutter_app/lib/services/server_launcher.dart`（macOS `lsof`，Windows `netstat -ano`） |
| 拖放统一封装 | `flutter_app/lib/services/drop_target.dart` + `mac_drop.dart` + `win_drop.dart` |
| drift 数据库 | `flutter_app/lib/db/database.dart` + `db/tables/*.dart` + `db/dao/*.dart` |
| 全局状态 | `flutter_app/lib/providers/<domain>_provider.dart` |
| 页面 | `flutter_app/lib/screens/<page>_screen.dart`（巨大页面拆子包，如 `test_session/`） |
| 复用组件 | `flutter_app/lib/widgets/*.dart` |
| macOS 原生 | `flutter_app/macos/Runner/`（Swift：`AppDelegate.swift`、`MainFlutterWindow.swift`） |
| Windows 原生 | `flutter_app/windows/runner/`（C++：`flutter_window.cpp`、`drop_target.cpp`、`main.cpp`） |

## 六、后端关键路径

| 关注点 | 路径 |
|---|---|
| 入口 | `backend/main.go` |
| 路由注册 + HTTP server | `backend/internal/server/server.go` |
| Panic 恢复 | `backend/internal/server/recovery.go`（`recoverHTTP` / `goSafe`） |
| 安全 | `backend/internal/server/security.go` |
| Envelope | `backend/internal/server/response.go` |
| 日志环形缓冲 | `backend/internal/server/backend_logger.go`（500 条） |
| WebSocket logcat | `backend/internal/server/log_stream.go` |
| 会话 logcat | `backend/internal/server/session_logcat.go` |
| ADB 二进制提取 | `backend/internal/server/adb.go` / `adb_binary.go` |
| 设备列表 | `backend/internal/server/adb_devices.go` |
| 设备状态 | `backend/internal/server/adb_status.go` |
| 文件 | `backend/internal/server/adb_files.go` |
| 应用 | `backend/internal/server/adb_packages.go` |
| 截图 / 录屏 | `backend/internal/server/adb_media.go` |
| scrcpy | `backend/internal/server/adb_scrcpy.go` + `scrcpy_binary.go` + `scrcpy_options.go` + `adb_scrcpy_{darwin,windows}.go` |
| 剪贴板 | `backend/internal/server/adb_clipboard.go` |
| 通用 adb exec | `backend/internal/server/adb_exec.go` |
| 公共类型 | `backend/internal/server/adb_types.go` |
| 路由 handler | `backend/internal/server/handlers_{devices,files,packages,screen,scrcpy,logcat,clipboard,wireless,emulator,meta}.go` |
| 模拟器后端 | `handlers_emulator.go` + `main.go` 的 `srv.InitEmulator()` |
| 中间件 / 日志中间件 | `logging_middleware.go` |

## 七、Android 辅助端（极简）

- 路径：`adb_tool_app/`
- 单源：`app/src/main/java/com/adbtool/clipboard/SetClipboardActivity.kt`
- 启动方式：`am start -n com.adbtool.clipboard/.SetClipboardActivity --es text <base64>`
- AGP 9.1.1，Java 11，compileSdk 36，minSdk 24
- 产物：`app/build/outputs/apk/debug/app-debug.apk`
- **必须**复制到 `backend/clipboard-helper.apk` 才会被 Go 嵌入（构建脚本自动）

## 八、关键约束清单

1. **统一 envelope** — 新加 JSON endpoint 必须返回 `{ok, data, error}`，更新 `api/README.md`
2. **loopback-only** — 不要放宽 `security.go`
3. **panic recovery** — 新 HTTP handler 必须经过 `recoverHTTP` 中间件；新 goroutine 必须用 `goSafe`
4. **平台条件编译** — Go 端嵌入式与平台分支三件套；Flutter 端用 `defaultTargetPlatform` + MethodChannel
5. **i18n 双侧** — 中英文按页面分文件，新增 key 必须两个文件都加
6. **ANDROID_HOME** — 构建脚本不反推 SDK 路径，未设置则用已有 APK，不存在则报错
7. **不要自动 commit / push** — 任何 commit / push / PR 创建必须用户明确同意
8. **构建产物不入 git** — `backend/adb-tool`、`backend/adb-tool.exe`、`flutter_app/macos/Runner/adb-tool`、`flutter_app/windows/runner/Resources/runtime.exe`、`dist/` 均在 `.gitignore`
9. **本地路径不外泄** — `local.properties` / keystore / `~/.android/` 不进 git
10. **WiX 版本** — 用 5.0.2 + `WixToolset.UI.wixext/5.0.2`，**不要用 WiX 7+**

## 九、开发流速查

| 想做的事 | 命令 |
|---|---|
| 跑后端 | `cd backend && go run .` |
| 跑后端单测 | `cd backend && go test ./...` |
| 跑 Flutter 桌面端 (macOS) | `cd flutter_app && flutter run -d macos` |
| 跑 Flutter 桌面端 (Windows) | `cd flutter_app && flutter run -d windows` |
| 跑 Flutter 单测 | `cd flutter_app && flutter test` |
| Flutter 静态分析 | `cd flutter_app && flutter analyze` |
| 生成 drift 代码 | `cd flutter_app && dart run build_runner build` |
| i18n key 校验 | `python scripts/check_i18n_tr_keys.py` |
| 重新生成剪贴板 APK | 设置 `ANDROID_HOME` → `cd adb_tool_app && ./gradlew assembleDebug` → 复制到 `backend/clipboard-helper.apk` |
| 构建 macOS app | `bash scripts/build.sh --platform macos --mode release` |
| 构建 Windows MSI | `powershell scripts/build.ps1 -Mode Release -Platform Windows -GoArch amd64` |
| 重置本地 SQLite | `powershell scripts/reset-db.ps1` |