# ADB Tool 项目架构文档

## 一、项目概述

跨平台 ADB (Android Debug Bridge) 桌面工具，通过 **Go 后端 + Flutter 前端** 提供图形化界面，用于管理 Android 设备。

### 技术栈三层架构

| 层 | 技术栈 | 路径 | 作用 |
|---|---|---|---|
| Android APP | Kotlin + Gradle (AGP 9.1.1) | `adb_tool_app/` | 剪贴板辅助 APK，安装在目标 Android 设备上 |
| 后端 | Go 1.26.3 | `backend/` | HTTP 服务器 + WebSocket，封装所有 ADB 命令 |
| 前端 | Flutter 3.4+ (Dart) | `flutter_app/` | 桌面 GUI（支持 macOS、Windows） |

---

## 二、目录结构

```
.
├── scripts/
│   ├── build.sh                        # macOS 主构建脚本
│   ├── build.ps1                       # Windows 构建脚本 (PowerShell)
│   ├── idea-build.ps1                  # IDEA 复用 build.ps1 的封装
│   ├── installer.wxs                   # WiX 安装器源文件
│   ├── check_i18n_tr_keys.py           # CI 用的 i18n key 完整性检查
│   └── reset-db.ps1                    # 重置本地 SQLite 数据库 (开发用)
├── adb_tool_app/                       # Android 剪贴板辅助 APK
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   ├── gradle.properties
│   ├── gradle/
│   │   └── libs.versions.toml          # AGP 9.1.1, JUnit 4.13.2
│   └── app/
│       ├── build.gradle.kts
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── java/com/adbtool/clipboard/
│               └── SetClipboardActivity.kt
├── backend/                            # Go 后端
│   ├── go.mod                          # module: adb-tool/backend, gorilla/websocket
│   ├── main.go                         # 入口
│   ├── embed_darwin.go                 # //go:build darwin，嵌入 platform-tools
│   ├── embed_windows.go                # //go:build windows，嵌入 platform-tools
│   ├── embed_scrcpy_darwin.go          # //go:build darwin，嵌入 macOS scrcpy
│   ├── embed_scrcpy_windows.go         # //go:build windows，嵌入 Windows scrcpy
│   ├── embed_scrcpy_fallback.go        # //go:build !darwin && !windows
│   ├── embed_fallback.go               # //go:build !darwin && !windows
│   ├── embed_clipboard_apk.go          # 嵌入 clipboard-helper.apk
│   ├── clipboard-helper.apk
│   ├── platform-tools-latest-darwin.zip
│   ├── platform-tools-latest-windows.zip
│   ├── build.sh / build.bat
│   ├── web/index.html
│   ├── uninstall/                      # Windows MSI 卸载入口
│   └── internal/server/                # HTTP 路由 + ADB 封装（按功能拆）
│       ├── server.go                   # 路由注册 + 启动
│       ├── recovery.go                # Panic 恢复中间件 (recoverHTTP, goSafe)
│       ├── security.go                # Loopback-only 安全限制
│       ├── response.go                # 统一 envelope {ok,data,error}
│       ├── backend_logger.go           # 环形缓冲日志 (500 条)
│       ├── backend_logger_darwin.go    # 平台特定日志路径
│       ├── backend_logger_windows.go
│       ├── log_stream.go               # WebSocket /ws/logs
│       ├── session_logcat.go           # 会话绑定 logcat
│       ├── adb.go / adb_binary.go      # ADB 二进制查找、提取、chmod
│       ├── adb_types.go                # Device / FileItem / 公共结构体
│       ├── adb_devices.go              # 设备列表 (adb devices -l)
│       ├── adb_status.go               # 设备状态 (getprop / 实时指标)
│       ├── adb_files.go                # 文件操作 (ls/cat/pull/push)
│       ├── adb_packages.go             # 应用列表 / 安装 / 卸载
│       ├── adb_media.go                # 截图 / 录屏
│       ├── adb_scrcpy.go               # scrcpy 进程生命周期、投屏快捷动作
│       ├── adb_scrcpy_darwin.go        # macOS scrcpy 二进制定位与权限处理
│       ├── adb_scrcpy_windows.go       # Windows scrcpy 二进制定位
│       ├── scrcpy_binary.go            # 内置 scrcpy 资源提取
│       ├── scrcpy_options.go           # scrcpy 参数模型、默认值和校验
│       ├── adb_logcat.go               # logcat 控制
│       ├── adb_clipboard.go            # 剪贴板助手 APK 操作
│       ├── adb_exec.go                 # 通用 adb shell / adb 命令透传
│       ├── handlers_devices.go         # 设备 / 状态 / info 相关路由
│       ├── handlers_files.go           # 文件路由 + 增删改
│       ├── handlers_packages.go        # 应用管理路由
│       ├── handlers_screen.go          # 截图 / 录屏路由
│       ├── handlers_scrcpy.go          # 投屏启停 / 状态 / 快捷动作路由
│       ├── handlers_logcat.go          # logcat / session-logcat 路由
│       ├── handlers_clipboard.go       # 剪贴板路由
│       ├── handlers_wireless.go        # 无线 ADB 路由
│       ├── handlers_meta.go            # identify / shutdown / adb-exec / backend-logs
│       └── *_test.go                   # 单元测试 (adb_*, backend_logger, recovery, security)
└── flutter_app/                        # Flutter 桌面应用
    ├── pubspec.yaml                    # drift, provider, shared_preferences, dio, video_player, ...
    ├── lib/
    │   ├── main.dart                   # 入口 + Provider 装配
    │   ├── i18n.dart                   # i18n 入口 (按文件 part 分片)
    │   ├── i18n/                       # 各页面中英文字典
    │   │   ├── common.dart / sidebar.dart / device_monitor.dart
    │   │   ├── logcat.dart / file_browser.dart / app_manager.dart
    │   │   ├── device_info.dart / clipboard.dart / adb_command.dart
    │   │   ├── backend_log.dart / test_session.dart / session_history.dart
    │   ├── models/                     # 纯数据模型
    │   │   ├── device.dart             # Device, LogFilter, LogEntry
    │   │   ├── device_status.dart      # 实时设备状态指标
    │   │   ├── scrcpy_options.dart     # 投屏参数模型，与 Go ScrcpyOptions JSON 字段对齐
    │   │   ├── file_item.dart
    │   │   ├── app_package.dart
    │   │   ├── test_session.dart       # TestSession + events/artifacts/issues/notes/plan
    │   │   └── test_config.dart        # App 配置 + 测试流程/步骤
    │   ├── db/                         # 本地 SQLite (drift) 持久化
    │   │   ├── database.dart           # AppDatabase 主类 + schema
    │   │   ├── database.g.dart         # drift 生成的代码 (commit 进仓库)
    │   │   ├── tables/                 # Drift 表: test_sessions / *_events / scrcpy_options / sent_clipboard_entry / ...
    │   │   │   ├── app_states.dart
    │   │   │   ├── saved_devices.dart
    │   │   │   ├── scrcpy_options.dart
    │   │   │   ├── sent_clipboard_entry.dart
    │   │   │   ├── test_sessions.dart
    │   │   │   ├── test_session_events.dart
    │   │   │   ├── test_session_artifacts.dart
    │   │   │   ├── test_session_issues.dart
    │   │   │   ├── test_session_issue_artifacts.dart
    │   │   │   ├── test_session_notes.dart
    │   │   │   └── test_session_plan_items.dart
    │   │   └── dao/                    # 表对应的 DAO (含 .g.dart)
    │   │       ├── app_states_dao.dart
    │   │       ├── saved_devices_dao.dart
    │   │       ├── scrcpy_options_dao.dart
    │   │       ├── sent_clipboard_entry_dao.dart
    │   │       └── test_sessions_dao.dart
    │   ├── providers/                  # ChangeNotifier 全局状态
    │   │   ├── device_provider.dart    # 设备列表 / activeSerial / 离线软状态
    │   │   ├── locale_provider.dart
    │   │   ├── theme_provider.dart
    │   │   ├── scrcpy_settings_provider.dart # 按设备加载/保存投屏参数
    │   │   ├── clipboard_history_provider.dart # 数据库驱动的剪贴板历史
    │   │   ├── test_config_provider.dart
    │   │   ├── test_session_provider.dart  # Session CRUD + 附件归档 + 导出
    │   │   └── test_session/           # test_session_provider 的辅助模块
    │   │       ├── attachment_store.dart   # 截图/录屏/logcat 落盘
    │   │       ├── exporter.dart           # 导出 ZIP
    │   │       ├── formatter.dart          # report.md / 测试报告生成
    │   │       └── session_translate.dart  # 中英文翻译注入
    │   ├── services/
    │   │   ├── api_client.dart         # 拼装所有 REST 调用 (facade)
    │   │   ├── api/                    # 按域拆分的 API 客户端
    │   │   │   ├── device_api.dart / file_api.dart / logcat_api.dart
    │   │   │   ├── packages_api.dart / screen_api.dart / wireless_api.dart
    │   │   │   ├── scrcpy_api.dart / clipboard_api.dart / backend_log_api.dart
    │   │   │   ├── adb_command_api.dart
    │   │   ├── log_stream.dart         # WebSocket logcat, Stream<LogEntry>
    │   │   ├── server_launcher.dart    # 后端进程管理 (mac/win 端口清理)
    │   │   ├── mac_drop.dart / win_drop.dart / drop_target.dart  # 平台拖放统一封装
    │   │   ├── screen_capture_service.dart
    │   │   └── screen_record_owner.dart
    │   ├── mixins/                     # 截图 / 录屏捕获混入
    │   │   ├── screen_capture_mixin.dart
    │   │   ├── file_browser_capture_mixin.dart
    │   │   └── test_session_capture_mixin.dart
    │   ├── widgets/                    # 跨页面复用组件 (17 个)
    │   │   ├── widgets/                # 顶层: 截图水印 / 录制 FAB / 文件传输 / 投屏设置 ...
    │   │   └── logcat/                 # 子目录: 高亮规则等 logcat 专用组件
    │   ├── utils/
    │   │   ├── test_flow_text.dart     # 测试流程/步骤文本解析与格式化
    │   │   ├── time_formatters.dart
    │   │   └── legacy_session_cleanup.dart  # 老版本 JSON session 一次性清理
    │   └── screens/                    # 12 个屏幕 (home / test_session 已拆子包)
    │       ├── home_screen.dart        # 主框架 + 侧边栏
    │       ├── logcat_screen.dart
    │       ├── file_browser_screen.dart
    │       ├── app_manager_screen.dart
    │       ├── device_info_screen.dart
    │       ├── device_status_screen.dart   # 实时指标 (CPU/内存/电池/...)
    │       ├── screen_mirror_screen.dart    # scrcpy 投屏控制页
    │       ├── clipboard_screen.dart
    │       ├── adb_command_screen.dart     # ADB 指令面板
    │       ├── test_config_screen.dart     # 测试配置编辑
    │       ├── backend_log_screen.dart
    │       └── test_session/           # 测试会话 (hub + active + 预览组件)
    │           ├── test_session_hub_screen.dart    # 会话列表 / 历史浏览 / 创建入口
    │           ├── test_session_active_screen.dart  # 进行中会话 (步骤标记/附件归档)
    │           └── session_preview_widgets.dart     # 截图/视频/日志预览
    ├── macos/                          # macOS 原生层
    │   └── Runner/
    │       ├── AppDelegate.swift
    │       ├── MainFlutterWindow.swift
    │       └── ...
    ├── windows/                        # Windows 原生层 (C++ 拖放 + Flutter runner)
    │   └── runner/
    │       ├── main.cpp / flutter_window.{h,cpp}
    │       ├── drop_target.{h,cpp}     # IDropTarget COM 实现
    │       └── utils.{h,cpp}
    └── test/                           # Flutter 单元/widget 测试
        ├── highlight_rule_test.dart
        ├── session_formatter_test.dart
        ├── test_config_provider_test.dart
        ├── test_config_screen_test.dart
        ├── test_session_hub_device_switch_test.dart
        └── video_preview_test.dart
```

---

## 三、Android 层 (`adb_tool_app`)

### SetClipboardActivity.kt

唯一 Kotlin 源文件，极简 Activity：
- 通过 `am start -n com.adbtool.clipboard/.SetClipboardActivity --es text <base64>` 启动
- 接收 Base64 编码文本，解码后写入系统剪贴板
- 透明主题，`finish()` 立即退出

### 构建参数

| 参数 | 值 |
|---|---|
| AGP | 9.1.1 |
| compileSdk | 36 |
| minSdk | 24 |
| targetSdk | 36 |
| applicationId | com.adbtool.clipboard |
| Java | 11 |

### Android SDK 与剪贴板助手 APK 构建规则

`adb_tool_app/local.properties` 不提交到仓库。构建脚本不猜测本机 SDK 路径，只读取系统环境变量 `ANDROID_HOME`。

规则：
1. 如果设置了 `ANDROID_HOME`，构建脚本会尝试执行 `adb_tool_app/gradlew assembleDebug`，重新构建剪贴板助手 APK。
2. 如果没有设置 `ANDROID_HOME`，构建脚本不会调用 Gradle，直接使用仓库内已有的 `backend/clipboard-helper.apk`。
3. 如果没有设置 `ANDROID_HOME`，并且 `backend/clipboard-helper.apk` 也不存在，构建脚本会直接报错，提示用户设置 `ANDROID_HOME`。

`ANDROID_HOME` 应指向本机 Android SDK 根目录，例如：

```powershell
$env:ANDROID_HOME = "D:\\Android\\Sdk"
```

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
```

本项目不依赖自动路径反推，避免不同设备、不同安装目录导致不可预期行为。

---

## 四、Go 后端 (`backend`)

### 4.1 启动流程 (main.go)

1. 从嵌入 ZIP 提取 `adb` 到 `/tmp/adb-tool-cache/`
2. 在 `:9876` 启动 HTTP 服务器
3. 等待 SIGINT/SIGTERM 优雅关闭

### 4.2 平台条件编译

| 文件 | Build Tag | 内容 |
|---|---|---|
| embed_darwin.go | `//go:build darwin` | 嵌入 macOS ADB 包 |
| embed_windows.go | `//go:build windows` | 嵌入 Windows ADB 包 |
| embed_fallback.go | `//go:build !darwin && !windows` | 回退 macOS ADB 包 |
| embed_scrcpy_darwin.go | `//go:build darwin` | 嵌入 macOS arm64 / x86_64 scrcpy 包 |
| embed_scrcpy_windows.go | `//go:build windows` | 嵌入 Windows 386 / amd64 scrcpy 包 |
| embed_scrcpy_fallback.go | `//go:build !darwin && !windows` | 非 macOS / Windows 平台空实现 |
| embed_clipboard_apk.go | 通用 | 嵌入 clipboard-helper.apk |

### 4.3 HTTP API 完整列表

所有 API 基于 `http://localhost:9876`，通过 `ApiClient` (Flutter 端 facade) 转发到 `lib/services/api/*` 下的领域客户端。统一响应 envelope 见 `response.go` 与 `api/README.md`。

#### 设备与基础信息

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/devices` | GET | 获取已连接设备列表 | 无 | Device[] (JSON) |
| `/api/info` | GET | 获取设备属性 (getprop) | `?serial=` | 属性键值对 JSON |
| `/api/device-detail` | GET | 获取设备所有属性 | `?serial=` | 完整属性 JSON |
| `/api/device-status` | GET | 获取实时设备指标 (CPU/内存/电池/...) | `?serial=` | 状态 JSON |
| `/api/package-pid` | GET | 根据包名查 PID | `?serial=&pkg=` | PID 文本 |
| `/api/running-packages` | GET | 获取运行中应用列表 | `?serial=` | 包名列表 JSON |
| `/api/identify` | GET | 服务标识 (健康检查) | 无 | 标识、PID、启动时间 |
| `/api/adb-path` | GET | 获取 ADB 路径 | 无 | 路径字符串 |

#### 应用管理

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/packages` | GET | 已安装应用列表 | `?serial=&system=` (true/false) | AppPackage[] JSON |
| `/api/install-package` | POST | 安装 APK | `?serial=` + multipart apk 文件 | 结果 JSON |
| `/api/uninstall-package` | POST | 卸载应用 | `?serial=&pkg=` | 结果 JSON |

#### 文件管理

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/files` | GET | 列出目录文件 | `?serial=&path=` | FileItem[] JSON |
| `/api/file-content` | GET | 读取文本文件内容 | `?serial=&path=` | 文本内容 |
| `/api/file-stat` | GET | 单个文件元信息 | `?serial=&path=` | FileItem JSON |
| `/api/file-mkdir` | POST | 新建目录 | `?serial=&path=` | 结果 JSON |
| `/api/file-touch` | POST | 新建空文件 | `?serial=&path=` | 结果 JSON |
| `/api/file-rename` | POST | 重命名 / 移动 | `?serial=&from=&to=` | 结果 JSON |
| `/api/file-delete` | POST | 删除文件 / 空目录 | `?serial=&path=` | 结果 JSON |
| `/api/push-file` | POST | 推送文件到设备 | `?serial=&path=` + multipart file | 结果 JSON |
| `/api/pull-file` | GET | 从设备拉取文件 | `?serial=&path=` | 文件二进制流 |
| `/api/screenshot` | GET | 截图 | `?serial=` | PNG 图片 |

#### 录屏

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/screen-record` | GET/POST | 录屏控制 | `?serial=&action=` (start/stop/status) | 状态 JSON |
| `/api/screen-record-video` | GET | 获取录屏视频 | `?serial=` | MP4 视频流 |

#### scrcpy 投屏

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/scrcpy/start` | POST | 启动内置 scrcpy 投屏 | `?serial=` + 可选 JSON `scrcpy_options` | 启动状态 JSON |
| `/api/scrcpy/stop` | POST | 停止当前 scrcpy 进程 | 无 | 停止状态 JSON |
| `/api/scrcpy/status` | GET | 查询投屏运行状态 | 可选 `?serial=` | running / serial / pid / elapsed |
| `/api/scrcpy/action` | POST | 发送设备侧快捷动作 | `?serial=&action=` | 动作结果 JSON |

投屏画面由 scrcpy 自己打开独立 SDL 窗口，Flutter 页面只负责启停、状态展示、参数配置和快捷键说明。

#### Logcat

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/clear` | GET | 清理 logcat 缓冲区 | `?serial=` |
| `/api/logcat-recent` | GET | 获取最近 logcat 快照 | `?serial=&lines=` (默认 1000) |
| `/api/session-logcat` | POST | 会话绑定的 logcat | `?serial=&sessionDir=&packageName=&action=start/stop` |
| `/ws/logs` | WebSocket | 实时 logcat 流 | JSON 命令: start/stop/pause/resume/clear/filter |

#### 剪贴板

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/clipboard-check` | GET | 检查助手是否安装 | `?serial=` |
| `/api/clipboard-install` | POST | 安装剪贴板助手 | `?serial=` |
| `/api/clipboard-send` | POST | 发送文本到剪贴板 | `?serial=&text=` |
| `/api/clipboard-uninstall` | POST | 卸载剪贴板助手 | `?serial=` |

#### 无线 ADB

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/adb-wireless-pair` | POST | 配对 | `?host=&port=&code=` |
| `/api/adb-wireless-connect` | POST | 连接 | `?host=&port=` |
| `/api/adb-wireless-disconnect` | POST | 断开 | `?serial=` |
| `/api/adb-wireless-scan` | GET | 扫描局域网端口 | `?host=` |

#### 通用 / 系统

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/adb-exec` | POST | 透传任意 ADB 命令 | `args=...` |
| `/api/backend-logs` | GET | 后端操作日志 (环形缓冲) | 无 |
| `/api/shutdown` | POST | 关闭后端进程 (loopback only) | 无 |
| `/` | GET | 静态文件 (web/index.html) | 无 |

### 4.4 Panic 恢复中间件 (`recovery.go`)

防止单个请求 panic 导致整个 Go 进程崩溃：

- `recoverHTTP(next http.Handler) http.Handler` — HTTP 中间件，捕获 handler panic 并返回 500 错误，同时记录完整堆栈到后端日志
- `goSafe(name string, fn func())` — 安全启动 goroutine，内部捕获 panic 并写入日志
- 已应用于：HTTP 中间件链（最外层）、设备属性采集 goroutine
- 无线 ADB 操作通过 `r.Context()` 传递请求上下文，客户端断开时 ADB 子进程自动终止

### 4.5 ADB 命令封装

按功能拆分为 `adb_xxx.go`，核心函数分布：

- `adb.go` / `adb_binary.go` — `FindOrExtractADB()` 提取 ADB 二进制，chmod 0755
- `adb_devices.go` — `Devices()` / `DevicesContext()` 解析 `adb devices -l`
- `adb_status.go` — `DeviceStatus()` (CPU/内存/电池/前台应用等实时指标)
- `adb_logcat.go` — `StartLogcat()` / `ClearLogcat()`
- `adb_files.go` — `ListFiles()` / `ReadFile()` / `PullFile()` / `PushFile()` / 增删改
- `adb_packages.go` — `InstalledPackages()` (解析 `pm list packages -f`) / `InstallPackage()` (自动处理签名冲突) / `UninstallPackage()`
- `adb_media.go` — `Screenshot()` (`exec-out screencap`) / `StartScreenRecord()` / `StopScreenRecord()`
- `adb_scrcpy.go` / `scrcpy_binary.go` / `scrcpy_options.go` — `StartScrcpy()` / `StopScrcpy()` / `ScrcpyStatus()` / `ScrcpyShortcut()`，提取内置 scrcpy 并转换用户配置为命令行参数
- `adb_clipboard.go` — `InstallClipboardHelper()` / `SendClipboard()` / `IsClipboardHelperInstalled()` / `UninstallClipboardHelper()`
- `adb_exec.go` — `Shell()` 通用 shell 命令 / `ExecAdb()` 透传任意 ADB 命令
- `adb_types.go` — Device / FileItem / 公共结构体定义

每个 `adb_xxx.go` 配套 `adb_xxx_test.go` 单元测试。

### 4.5 Logcat WebSocket 协议 (log_stream.go)

JSON 命令格式：

```json
{ "command": "start", "serial": "xxx" }
{ "command": "stop", "serial": "xxx" }
{ "command": "pause", "serial": "xxx" }
{ "command": "resume", "serial": "xxx" }
{ "command": "clear", "serial": "xxx" }
{ "command": "filter", "serial": "xxx", "keyword": "", "tag": "", "pids": "" }
```

暂停时缓冲最多 5000 行日志，超出丢弃旧的一半。

### 4.6 后端日志 (backend_logger.go)

- 环形缓冲，最大 500 条
- 每条包含：时间戳、命令、结果、错误、耗时
- 线程安全

---

## 五、Flutter 前端 (`flutter_app`)

### 5.1 整体架构

- 多个设备调试与测试功能页面，侧边栏导航
- 中英双语（`_loc` 字典）
- 暗/亮主题切换（持久化 `~/.adb_tool_prefs.json`）
- HTTP REST + WebSocket 与后端通信

### 5.2 页面功能

| 页面 | 文件 | 功能 |
|---|---|---|
| Home | `home_screen.dart` | 240px 侧边栏，设备树，语言/主题切换，服务重启，导航缓存 |
| Logcat | `logcat_screen.dart` | 实时日志，Tag/优先级/关键词/PID 过滤，暂停/自动滚动 |
| File Browser | `file_browser_screen.dart` | 列表/网格视图，上传/下载，截图，录屏(≤30min)，增删改查，路径面包屑 |
| App Manager | `app_manager_screen.dart` | APK 拖放安装，搜索，卸载确认，错误详情弹窗 |
| Device Info | `device_info_screen.dart` | 系统属性分组，搜索，截图 |
| Device Status | `device_status_screen.dart` | 实时指标 (CPU/内存/电池/存储/前台应用) |
| Screen Mirror | `screen_mirror_screen.dart` | 内置 scrcpy 投屏控制，按设备保存参数，独立窗口显示，支持录制和快捷键参考 |
| Clipboard | `clipboard_screen.dart` | 文本发送，自动安装/卸载助手，历史记录与收藏 |
| ADB Command | `adb_command_screen.dart` | ADB 指令面板：参数/命令输入 + 快捷指令分类 |
| Test Config | `test_config_screen.dart` | 测试 App 配置、流程/步骤编辑，复制配置 |
| Backend Logs | `backend_log_screen.dart` | 2 秒轮询日志，错误高亮，命令过滤 |
| Test Session (Hub) | `screens/test_session/test_session_hub_screen.dart` | 会话列表、历史浏览、创建入口、设备切换 |
| Test Session (Active) | `screens/test_session/test_session_active_screen.dart` | 进行中会话：步骤标记、附件归档、问题/备注 |
| Test Session (Preview) | `screens/test_session/session_preview_widgets.dart` | 截图/视频/日志预览组件 |

### 5.3 核心服务

#### ApiClient + services/api/ 分片

`api_client.dart` 作为 facade，内部把每个域的调用委托给 `services/api/` 下的独立客户端：

- `device_api.dart` / `file_api.dart` / `logcat_api.dart` / `packages_api.dart`
- `screen_api.dart` / `wireless_api.dart` / `scrcpy_api.dart`
- `clipboard_api.dart` / `backend_log_api.dart` / `adb_command_api.dart`

这样新加 endpoint 时影响面小，单测也好写。

#### ServerLauncher (server_launcher.dart)

后端进程生命周期管理：

- `findServerBinary()` — 查找二进制路径：
  1. macOS App Bundle `../..` (Contents/MacOS/)
  2. App 同级目录
  3. 项目 `macos/Runner/` 目录
  4. `build/` 等其他目录
- Windows 路径走 `windows/runner/Resources/runtime.exe` 或同目录
- `start()` — 启动后端进程，设置 PATH 环境变量
- `stop()` — 终止进程
- `_stopOldServerIfAny()` — HTTP shutdown + `lsof` 杀端口 (macOS) / `netstat -ano` 杀端口 (Windows)

#### 拖放（drop_target / mac_drop / win_drop）

- `drop_target.dart` — 跨平台统一 `DropTarget` Widget，按 `defaultTargetPlatform` 选择实现
- `mac_drop.dart` — macOS 拖放 MethodChannel (`mac_drop`)，Swift 端 `DropOverlayView` + NSDraggingInfo
- `win_drop.dart` — Windows 拖放 MethodChannel (`win_drop`)，C++ 端 `IDropTarget` COM 实现 + `OleInitialize`
- App Manager 页面通过 `DropTarget` 接收 APK 拖放安装

#### 截图与录屏

- `screen_capture_service.dart` — 调 `/api/screenshot`，支持加水印 (`widgets/screenshot_watermark.dart`)
- `screen_record_owner.dart` — 录屏状态机（idle / recording），FAB (`widgets/recording_fab.dart`) 触发
- `mixins/screen_capture_mixin.dart` + `mixins/file_browser_capture_mixin.dart` + `mixins/test_session_capture_mixin.dart` — 三个 capture mixin，给不同页面复用截图/录屏能力

#### 投屏设置

- `scrcpy_settings_provider.dart` — 通过 `scrcpy_options_dao` 按设备序列号加载、保存和重置投屏参数。
- `scrcpy_settings_panel.dart` — 将 scrcpy 4.0 常用参数按视频源、视频、音频、窗口、控制、设备和录制分组展示。
- `scrcpy_shortcut_reference.dart` — 展示 scrcpy 窗口获得焦点后可用的跨平台快捷键。

#### 其他服务

- `log_stream.dart` — WebSocket logcat，`Stream<LogEntry>` 广播 + 连接状态流

### 5.4 数据模型

#### Device (`models/device.dart`)

```dart
class Device {
  final String serial;
  final String model;
  final String state;
  final String product;
  final String transportId;
}
```

#### DeviceStatus (`models/device_status.dart`)

实时设备指标，对应后端 `/api/device-status`：

```dart
class DeviceStatus {
  String serial;
  double cpuPercent;
  int memUsedKb, memTotalKb;
  int batteryLevel, batteryTemperature;
  String storageUsed, storageTotal;
  String foregroundPackage;
  DateTime capturedAt;
}
```

#### LogFilter & LogEntry (`models/device.dart`)

```dart
class LogFilter {
  String keyword;
  String tag;
  String pids;
  String priority;
}

class LogEntry {
  String line;
  String priority;
  String tag;
  DateTime timestamp;
}
```

#### FileItem (`models/file_item.dart`)

```dart
class FileItem {
  String name;
  String path;
  bool isDirectory;
  int size;
  String permissions;
  String lastModified;
}
```

#### AppPackage (`models/app_package.dart`)

```dart
class AppPackage {
  String packageName;
  String apkPath;
  bool isSystemApp;
}
```

#### TestSession (`models/test_session.dart`)

```dart
enum TestSessionStatus { running, finished }

class TestSession {
  String id, name, type, deviceSerial, deviceModel, packageName;
  TestSessionStatus status;
  DateTime startedAt, endedAt?;
  List<TestSessionEvent> events;
  List<TestSessionArtifact> artifacts; // screenshot, video, log
  List<TestSessionIssue> issues;
  List<TestSessionNote> notes;
  List<TestSessionPlanItem> testPlan; // configured flow/step snapshot
}
```

`TestSession` 的 CRUD、附件归档、报告生成、ZIP 导出由 `providers/test_session_provider.dart` 承担，附件落盘 / 报告格式化 / 翻译注入拆到同目录的 `test_session/` 子包模块。

#### TestSessionProvider (`providers/test_session_provider.dart`)

ChangeNotifier 模式，管理测试会话完整生命周期：

- `startSession()` — 创建会话，建立目录结构（logs/screenshots/videos/），保存测试流程/步骤快照并持久化 session.json
- `updateTestPlanItem()` — 标记测试步骤通过/失败，并保存失败原因或备注
- `markIssue()` / `addNote()` — 记录问题/备注，关联最近附件
- `saveScreenshotBytes()` / `saveVideoBytes()` / `saveLogcat()` — 附件归档
- `finishSession()` — 结束会话，生成 report.md
- `exportSession()` — 导出为 ZIP
- `scanHistory()` — 扫描 `ADBToolData/sessions/` 返回历史会话列表
- `loadHistoricalSession(id)` — 只读加载历史会话
- `deleteSession(id)` — 删除会话目录
- `deleteArtifact(id)` — 删除单个附件（仅 running 会话）
- 支持中英双语翻译注入

---

## 六、macOS 平台特定代码

### Go 后端

- `embed_darwin.go` — `//go:build darwin`，嵌入 macOS ADB 包
- `adb.go` — 运行时 `runtime.GOOS` 选择 `adb` 二进制名

### Flutter

- `server_launcher.dart` — macOS App Bundle 路径解析，`lsof` 端口管理
- `mac_drop.dart` — `platform.isMacOS` + MethodChannel 拖放

### macOS 原生 (Swift)

- `MainFlutterWindow.swift` — 窗口大小、最小尺寸、`DropOverlayView` 拖放叠加层
- `AppDelegate.swift` — 最后窗口关闭退出应用

---

## 七、关键设计模式

1. **Embed 资源模式** — ADB 和 APK 嵌入 Go 二进制，运行时提取，单文件分发
2. **前后端分离** — Go REST API + WebSocket，Flutter HTTP 调用
3. **进程内嵌模式** — Flutter 启动 Go 后端作为子进程，localhost 通信
4. **平台通道模式** — MethodChannel 桥接原生拖放
5. **环形缓冲日志** — 后端日志固定大小环形缓冲区
6. **Hash 路由缓存** — `serial_navitem` 键缓存页面实例

---

## 八、构建流程

### 环境依赖

| 构建目标 | 必需环境 | 说明 |
|---|---|---|
| 通用后端 | Go 1.26.3+ | 根据目标平台设置 `GOOS`/`GOARCH`，后端会嵌入对应平台的 platform-tools ZIP 和 `clipboard-helper.apk` |
| Flutter 桌面 | Flutter SDK 3.4+ | 需要启用对应桌面平台支持；macOS 使用 `flutter build macos`，Windows 使用 `flutter build windows` |
| Android 辅助 APK | JDK 11+、Android SDK、Gradle Wrapper | `adb_tool_app/gradlew` 或 `gradlew.bat assembleDebug` 生成 `app-debug.apk`，复制为 `backend/clipboard-helper.apk` 后再编译 Go 后端 |
| macOS 打包 | macOS、Xcode、CocoaPods（Flutter macOS 依赖需要时） | Xcode 提供 macOS 原生编译链和签名工具；当前脚本输出 `.app`，发布包可再压缩为 ZIP |
| Windows 打包 | Windows、Visual Studio Build Tools/C++ 桌面工具链、Windows SDK | Flutter Windows runner 依赖 CMake、MSBuild 和 Windows SDK，必须在 Windows 上构建 |
| Windows MSI | .NET SDK、WiX Toolset 5.0.2、`WixToolset.UI.wixext` 5.0.2 | `scripts/build.ps1` 使用 `wix build` 生成 MSI；不建议使用 WiX 7+，会涉及 OSMF EULA 接受流程 |
| GitHub Actions | `windows-latest`、`macos-latest` | Windows job 安装 WiX 后执行 `scripts/build.ps1`；macOS job 使用 Xcode 环境构建 `.app` |

#### Windows WiX 安装示例

```powershell
dotnet tool install --global wix --version 5.0.2
wix extension add WixToolset.UI.wixext/5.0.2
```

#### Flutter 桌面平台初始化

```bash
# macOS
cd flutter_app
flutter create --platforms=macos .

# Windows
cd flutter_app
flutter create --platforms=windows .
```

### 主构建脚本: `scripts/build.sh`

支持 `--platform` 和 `--mode` 参数，在 macOS 上构建。

```bash
# 用法
./scripts/build.sh --platform macos|windows --mode debug|release [--arch arm64|amd64]

# 示例
./scripts/build.sh --platform macos --mode debug
./scripts/build.sh --platform macos --mode release
./scripts/build.sh --platform macos --mode release --arch amd64
```

#### macOS 构建流程 (`--platform macos`)

```
1. [可选] 编译 Android APK → backend/clipboard-helper.apk
     - 仅在 adb_tool_app/ 存在时执行
     - 执行: ./gradlew assembleDebug (跳过 lint)
     - 从 adb_tool_app/app/build/outputs/apk/debug/app-debug.apk 复制
2. 编译 Go 后端
     - GOOS=darwin GOARCH=自动检测 (arm64/amd64)
     - -ldflags="-s -w" 去除调试信息
     - 输出: flutter_app/macos/Runner/adb-tool
3. 编译 Flutter macOS
     - flutter build macos --debug 或 --release
     - 输出: build/macos/Build/Products/{Debug|Release}/*.app
4. 复制后端二进制到 .app/Contents/MacOS/adb-tool
```

> 注意: `--platform windows` 在 macOS 上运行会提示 "Windows 版 Flutter 需要在 Windows 上构建"，需在 Windows 上执行 `scripts/build.ps1`

---

### Windows 构建: `scripts/build.ps1`

在 Windows 上执行，参数略有不同（使用 PowerShell 命名参数）。

```powershell
# 用法
.\scripts\build.ps1 -Mode Release -Platform Windows [-GoArch amd64|arm64] [-ProductVersion 1.0.0]

# 示例
.\scripts\build.ps1 -Mode Debug
.\scripts\build.ps1 -Mode Release -GoArch amd64 -ProductVersion 1.0.0
```

#### IDEA 一键打包配置

项目根目录的 `.run` 目录提供可共享的 JetBrains/IDEA 运行配置：

| 配置名 | 执行内容 |
|---|---|
| Package Debug | 调用 `scripts/idea-build.ps1 -Mode Debug -Platform Windows` |
| Package Release | 调用 `scripts/idea-build.ps1 -Mode Release -Platform Windows` |

在 IDEA 顶部运行配置下拉框选择 `Package Debug` 或 `Package Release` 后即可一键打包。实际打包逻辑仍复用 `scripts/build.ps1`，避免 IDEA 配置和命令行构建流程分叉。

#### Windows 构建流程

```
1. 准备 Android 剪贴板辅助 APK → backend/clipboard-helper.apk
     - 设置了 ANDROID_HOME 时执行 gradlew.bat assembleDebug (跳过 lint)
     - 从 adb_tool_app/app/build/outputs/apk/debug/app-debug.apk 复制
     - 未设置 ANDROID_HOME 时跳过 Gradle，使用已有 backend/clipboard-helper.apk
     - 未设置 ANDROID_HOME 且已有 APK 不存在时直接报错
2. 编译 Go 后端 runtime.exe
     - GOOS=windows GOARCH=amd64 (默认)
     - -ldflags="-s -w"
     - 输出: flutter_app/windows/runner/Resources/runtime.exe
     - 编译时嵌入 Windows platform-tools ZIP 和 clipboard-helper.apk
3. 编译 Flutter Windows launcher.exe
     - flutter build windows --debug 或 --release
     - CMake 将 runtime.exe 安装到 Flutter 构建输出目录
4. 编译卸载入口 uninstall.exe
     - go build ./uninstall/
     - 通过 MSI UpgradeCode 查找已安装产品并调用 msiexec /x
5. 生成 WiX 源文件
     - 扫描 Flutter Windows 输出目录
     - 生成 dist/windows/installer.generated.wxs
6. 生成 MSI
     - wix build -ext WixToolset.UI.wixext
     - 输出: dist/windows/ADBToolSetup-{ProductVersion}-windows-{GoArch}.msi
```

> 注意: 执行前确保 `flutter_app/windows` 目录存在，若不存在需先在 `flutter_app` 目录下执行：
> ```powershell
> flutter create --platforms=windows .
> ```

---

## 九、Windows 平台特定代码

### Go 后端

- `embed_windows.go` — `//go:build windows`，嵌入 Windows ADB 包
- `adb.go` — 运行时 `runtime.GOOS` 选择 `adb.exe` 后缀

### Flutter

#### ServerLauncher (server_launcher.dart)

- `findServerBinary()` — Windows 路径支持：
  1. `<exe_dir>/runtime.exe`
  2. `<exe_dir>/Resources/runtime.exe` (Windows runner 资源位置)
  3. `../Resources/runtime.exe` 等相对路径
  4. `windows/runner/Resources/runtime.exe`
- `start()` — Windows PATH 设置 `%SystemRoot%\System32`
- `_killPortListeners()` — Windows 使用 `netstat -ano` 查找端口 PID (替代 lsof)

#### 拖放支持

- `win_drop.dart` — MethodChannel `win_drop`，`WinDropTarget` Widget (同 mac_drop API)
- `drop_target.dart` — 统一 `DropTarget` Widget，内部包装 MacDropTarget + WinDropTarget

### Windows 原生 (C++)

- `flutter_window.h/cpp` — 集成 `DropTarget` (IDropTarget COM)，`OleRegisterDragDrop`
- `drop_target.h/cpp` — IDropTarget COM 实现，MethodChannel `win_drop` 双向通信
- `main.cpp` — `OleInitialize` 替代 `CoInitializeEx`
- 文件拖放事件流程：
  ```
  IDropTarget::DragEnter → MethodChannel "dragEntered" → Flutter → onDragEntered
  IDropTarget::Drop      → MethodChannel "dragDone"    → Flutter → onDragDone (XFile[])
  ```

### 构建

- `build.ps1` — 编译 Android 辅助 APK、Go 后端 `runtime.exe`、Flutter Windows `launcher.exe`、卸载入口 `uninstall.exe`，并通过 WiX 生成 MSI
- 后端资源路径: `flutter_app/windows/runner/Resources/runtime.exe`
- Flutter 构建输出: `flutter_app/build/windows/{x64|arm64}/runner/{Debug|Release}/`
- MSI 输出路径: `dist/windows/ADBToolSetup-{ProductVersion}-windows-{GoArch}.msi`

---

## 十、跨平台差异说明

| 特性 | macOS | Windows |
|---|---|---|
| 桌面入口 | `.app` bundle | `launcher.exe` |
| 后端二进制名称 | `adb-tool` | `runtime.exe` |
| 后端查找路径 | `Contents/MacOS/`、`macos/Runner/` | 安装目录、`Resources/`、`windows/runner/Resources/` |
| 打包格式 | `.app` / ZIP | MSI |
| 打包工具链 | Xcode、Flutter macOS | Visual Studio Build Tools、Windows SDK、WiX |
| 端口 PID 查找 | `lsof -nP -iTCP:port` | `netstat -ano` |
| PATH 环境变量 | `/usr/bin:/bin:...` | `%SystemRoot%\System32` |
| 拖放 MethodChannel | `mac_drop` | `win_drop` |
| 拖放原生实现 | NSView + NSDraggingInfo (Swift) | IDropTarget COM (C++) |
| COM 初始化 | 无 | `OleInitialize()` |
