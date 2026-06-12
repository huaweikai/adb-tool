# ADB Tool 项目架构文档

## 一、项目概述

跨平台 ADB (Android Debug Bridge) 桌面工具，通过 **Go 后端 + Flutter 前端** 提供图形化界面，用于管理 Android 设备。

### 技术栈三层架构

| 层 | 技术栈 | 路径 | 作用 |
|---|---|---|---|
| Android APP | Kotlin + Gradle (AGP 9.1.1) | `adb_tool_app/` | 剪贴板辅助 APK，安装在目标 Android 设备上 |
| 后端 | Go 1.26.3 | `backend/` | HTTP 服务器 + WebSocket，封装所有 ADB 命令 |
| 前端 | Flutter 3.4+ (Dart) | `flutter_app/` | 桌面 GUI（主要目标平台 macOS，待扩展 Windows） |

---

## 二、目录结构

```
/Users/huaweikai/AndroidStudioProjects/adb tool/
├── scripts/
│   ├── build.sh                        # 主构建脚本 (macOS)
│   └── build.ps1                       # Windows 构建脚本
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
│   ├── embed_darwin.go                 # //go:build darwin
│   ├── embed_windows.go                # //go:build windows
│   ├── embed_fallback.go               # //go:build !darwin && !windows
│   ├── embed_clipboard_apk.go          # 嵌入 clipboard-helper.apk
│   ├── clipboard-helper.apk
│   ├── platform-tools-latest-darwin.zip
│   ├── platform-tools-latest-windows.zip
│   ├── build.sh / build.bat
│   ├── web/index.html
│   └── internal/server/
│       ├── server.go                   # HTTP 路由 + API 处理
│       ├── adb.go                      # ADB 命令封装
│       ├── log_stream.go               # WebSocket logcat 流
│       └── backend_logger.go           # 环形缓冲日志 (500条)
└── flutter_app/                        # Flutter 桌面应用
    ├── pubspec.yaml                    # web_socket_channel, http, file_selector, cross_file
    ├── lib/
    │   ├── main.dart                   # 入口
    │   ├── models/
    │   │   ├── device.dart             # Device, LogFilter, LogEntry
    │   │   ├── file_item.dart          # FileItem
    │   │   └── app_package.dart        # AppPackage
    │   ├── services/
    │   │   ├── api_client.dart         # HTTP API 客户端
    │   │   ├── log_stream.dart         # WebSocket logcat 流
    │   │   ├── server_launcher.dart    # 后端进程管理
    │   │   └── mac_drop.dart           # macOS 拖放支持
    │   └── screens/
    │       ├── home_screen.dart        # 主界面 (侧边栏 + 内容区)
    │       ├── logcat_screen.dart      # Logcat 日志
    │       ├── file_browser_screen.dart# 文件浏览器
    │       ├── app_manager_screen.dart # 应用管理
    │       ├── device_info_screen.dart # 设备信息
    │       ├── clipboard_screen.dart   # 剪贴板
    │       └── backend_log_screen.dart # 后端日志
    ├── macos/                          # macOS 原生层
    │   └── Runner/
    │       ├── AppDelegate.swift
    │       ├── MainFlutterWindow.swift
    │       └── ...
    └── test/widget_test.dart
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
| embed_fallback.go | `//go:build !darwin && !windows` | 回退 macOS 包 |
| embed_clipboard_apk.go | 通用 | 嵌入 clipboard-helper.apk |

### 4.3 HTTP API 完整列表

所有 API 基于 `http://localhost:9876`，通过 `ApiClient` (Flutter端) 调用。

#### 设备管理

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/devices` | GET | 获取已连接设备列表 | 无 | Device[] (JSON) |
| `/api/info` | GET | 获取设备属性 (getprop) | `?serial=` | 属性键值对 JSON |
| `/api/device-detail` | GET | 获取设备所有属性 | `?serial=` | 完整属性 JSON |
| `/api/package-pid` | GET | 根据包名查 PID | `?serial=&pkg=` | PID 文本 |
| `/api/running-packages` | GET | 获取运行中应用列表 | `?serial=` | 包名列表 JSON |
| `/api/identify` | GET | 服务标识 (健康检查) | 无 | 标识、PID、启动时间 |

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
| `/api/push-file` | POST | 推送文件到设备 | `?serial=&path=` + multipart file | 结果 JSON |
| `/api/pull-file` | GET | 从设备拉取文件 | `?serial=&path=` | 文件二进制流 |
| `/api/screenshot` | GET | 截图 | `?serial=` | PNG 图片 |

#### 录屏

| 路由 | 方法 | 功能 | 参数 | 返回值 |
|---|---|---|---|---|
| `/api/screen-record` | GET | 录屏控制 | `?serial=&action=` (start/stop/status) | 状态 JSON |
| `/api/screen-record-video` | GET | 获取录屏视频 | `?serial=` | MP4 视频流 |

#### Logcat

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/clear` | GET | 清理 logcat 缓冲区 | `?serial=` |
| `/ws/logs` | WebSocket | 实时 logcat 流 | JSON 命令: start/stop/pause/resume/clear/filter |

#### 剪贴板

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/clipboard-check` | GET | 检查助手是否安装 | `?serial=` |
| `/api/clipboard-install` | POST | 安装剪贴板助手 | `?serial=` |
| `/api/clipboard-send` | POST | 发送文本到剪贴板 | `?serial=&text=` |
| `/api/clipboard-uninstall` | POST | 卸载剪贴板助手 | `?serial=` |

#### 系统

| 路由 | 方法 | 功能 | 参数 |
|---|---|---|---|
| `/api/adb-path` | GET | 获取 ADB 路径 | 无 |
| `/api/backend-logs` | GET | 获取后端操作日志 | 无 |
| `/` | GET | 静态文件 (web/index.html) | 无 |

### 4.4 ADB 命令封装 (adb.go)

核心函数：
- `FindOrExtractADB()` — 提取 ADB 二进制，chmod 0755
- `Devices()` — `adb devices -l` 解析
- `StartLogcat()` / `ClearLogcat()` — logcat 控制
- `ListFiles()` / `ReadFile()` / `PullFile()` / `PushFile()` — 文件操作
- `InstalledPackages()` — `pm list packages -f` 解析
- `InstallPackage()` — 安装 APK（自动处理签名冲突）
- `UninstallPackage()` — 卸载
- `Screenshot()` — `exec-out screencap`
- `Shell()` — 通用 shell 命令
- `StartScreenRecord()` / `StopScreenRecord()` — 录屏
- `InstallClipboardHelper()` / `SendClipboard()` / `IsClipboardHelperInstalled()` / `UninstallClipboardHelper()`

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

- 6 个功能页面，侧边栏导航
- 中英双语（`_loc` 字典）
- 暗/亮主题切换（持久化 `~/.adb_tool_prefs.json`）
- HTTP REST + WebSocket 与后端通信

### 5.2 页面功能

| 页面 | 文件 | 功能 |
|---|---|---|
| Home | `home_screen.dart` | 240px 侧边栏，设备树，语言/主题切换，服务重启 |
| Logcat | `logcat_screen.dart` | 实时日志，Tag/优先级/关键词/PID 过滤，暂停/自动滚动 |
| File Browser | `file_browser_screen.dart` | 列表/网格视图，上传/下载，截图，录屏(≤30min)，路径面包屑 |
| App Manager | `app_manager_screen.dart` | APK 拖放安装，搜索，卸载确认，错误详情弹窗 |
| Device Info | `device_info_screen.dart` | 系统属性分组，搜索，截图 |
| Clipboard | `clipboard_screen.dart` | 文本发送，自动安装/卸载助手 |
| Backend Logs | `backend_log_screen.dart` | 2 秒轮询日志，错误高亮，命令过滤 |

### 5.3 核心服务

#### ServerLauncher (server_launcher.dart)

后端进程生命周期管理：

- `findServerBinary()` — 查找二进制路径：
  1. macOS App Bundle `../..` (Contents/MacOS/)
  2. App 同级目录
  3. 项目 `macos/Runner/` 目录
  4. `build/` 等其他目录
- `start()` — 启动后端进程，设置 PATH 环境变量
- `stop()` — 终止进程
- `_stopOldServerIfAny()` — HTTP shutdown + `lsof` 杀端口 (macOS 专用)

#### mac_drop.dart

macOS 拖放平台通道：

- MethodChannel `mac_drop` 通信
- `MacDropTarget` Widget：`onDragEntered`, `onDragExited`, `onDragDone` 回调
- 仅 `TargetPlatform.macOS` 激活
- 活跃注册机制管理拖放监听

#### 其他服务

- `api_client.dart` — 封装所有 REST API 调用
- `log_stream.dart` — WebSocket logcat，`Stream<LogEntry>` 广播

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

#### Windows 构建流程

```
1. 编译 Android 剪贴板辅助 APK → backend/clipboard-helper.apk
     - 仅在 adb_tool_app/ 存在且 gradlew.bat 可用时执行
     - 执行: gradlew.bat assembleDebug (跳过 lint)
     - 从 adb_tool_app/app/build/outputs/apk/debug/app-debug.apk 复制
     - 若 APK 构建失败，则沿用已有 backend/clipboard-helper.apk
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
