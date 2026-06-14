# ADB Tool

[English](README_EN.md)

ADB Tool 是一个面向 Android 调试与测试场景的跨平台桌面工具。它将常用 ADB 能力封装成图形化界面，适合日常查看设备、抓取日志、管理文件、安装应用、执行调试命令和进行无线 ADB 连接。

项目采用 **Flutter 桌面端 + Go 后端 + Android 剪贴板辅助 APK** 的结构：Flutter 负责桌面界面，Go 后端负责启动本地服务并封装 ADB 命令，Android 辅助 APK 用于部分系统剪贴板能力。

## 界面预览

### 设备主页

![设备主页](assets/main_screen.png)

### Logcat 实时日志

![Logcat 实时日志](assets/logcat_screen.png)

### 文件管理

![文件管理](assets/file_manage_screen.png)

### ADB 指令

![ADB 指令](assets/adb_cmd_screen.png)

## 主要功能

- **设备管理**：自动发现 USB / WiFi 连接的 Android 设备，展示设备型号、品牌、系统版本和连接状态。
- **Logcat 日志**：通过 WebSocket 实时采集日志，支持级别、标签、包名、PID、关键词过滤，以及暂停、继续、清空和自动滚动。
- **文件管理**：浏览设备文件系统，支持上传、下载、删除、重命名、新建文件、新建文件夹、复制路径、查看详情、截图和录屏保存。
- **应用管理**：查看已安装应用，搜索包名，拖放安装 APK，卸载应用，并对常见安装失败原因做友好提示。
- **设备信息**：查看设备属性、系统信息和 `getprop` 相关内容。
- **剪贴板工具**：安装辅助 APK 后，可从桌面端向 Android 设备发送剪贴板文本。
- **ADB 指令面板**：支持输入 ADB 参数或完整 ADB 命令，并提供设备信息、屏幕控制、按键模拟、调试诊断、存储网络、维护操作等快捷指令。
- **无线 ADB**：支持无线配对、连接和断开设备。
- **后端日志**：查看本地 Go 后端执行 ADB 操作时产生的运行日志。
- **主题与语言**：支持亮色 / 暗色主题切换，以及中文 / 英文界面切换。

## 技术架构

| 层级 | 技术 | 路径 | 说明 |
|---|---|---|---|
| 桌面端 | Flutter / Dart / Dio / WebSocket | `flutter_app/` | 提供 macOS、Windows 桌面 GUI |
| 后端 | Go / net/http / gorilla/websocket | `backend/` | 启动本地 HTTP 服务，封装 ADB 操作 |
| Android 辅助端 | Kotlin / Gradle | `adb_tool_app/` | 剪贴板辅助 APK，安装到目标设备 |
| 构建脚本 | PowerShell / Bash | `scripts/` | 打包后端、前端和平台产物 |
| API 文档 | Markdown | `api/README.md` | 说明后端统一响应协议和接口字段 |

运行时大致流程：

1. 桌面应用启动本地 Go 后端。
2. 后端提取或加载内置 platform-tools 中的 ADB。
3. Flutter 通过 `http://localhost:9876` 调用后端 API。
4. 后端执行 ADB 命令并返回统一 JSON 响应。
5. Logcat 通过 `/ws/logs` WebSocket 实时推送到前端。

## 项目结构

```text
.
├── adb_tool_app/            # Android 剪贴板辅助 APK 工程
├── api/                     # 后端 API 响应协议与接口字段文档
├── assets/                  # README 使用的界面截图
├── backend/                 # Go 后端服务与 ADB 操作封装
│   └── internal/server/     # HTTP 路由、WebSocket、ADB 分层实现
├── flutter_app/             # Flutter 桌面端工程
│   └── lib/
│       ├── models/          # 前端数据模型
│       ├── screens/         # 各功能页面
│       └── services/        # API、日志流、服务启动与拖放能力
├── scripts/                 # macOS / Windows 构建脚本
└── PROJECT_OVERVIEW.md      # 更详细的项目架构说明
```

## 环境要求

基础开发环境：

- Flutter 3.4+ / Dart 3.4+
- Go 1.26.3+
- Android SDK（需要重新构建剪贴板辅助 APK 时）
- macOS 或 Windows 桌面构建环境

Windows 安装包构建还需要：

- WiX Toolset v5
- 对应的 WiX UI 扩展

如果未设置 `ANDROID_HOME`，构建脚本会优先复用仓库中已有的 `backend/clipboard-helper.apk`。如果该 APK 不存在，则需要先配置 Android SDK 并重新构建。

## 开发运行

### 启动后端

```bash
cd backend
go run .
```

后端默认监听：

```text
http://localhost:9876
```

### 启动 Flutter 桌面端

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

Windows 开发环境下可以使用：

```powershell
cd flutter_app
flutter pub get
flutter run -d windows
```

## 构建

### macOS

```bash
./scripts/build.sh --platform macos --mode release
```

也可以构建调试版本：

```bash
./scripts/build.sh --platform macos --mode debug
```

### Windows

```powershell
.\scripts\build.ps1 -Mode Release -Platform Windows -GoArch amd64
```

调试版本：

```powershell
.\scripts\build.ps1 -Mode Debug -Platform Windows -GoArch amd64
```

## API 响应协议

后端 JSON API 使用统一 envelope：

```json
{
  "ok": true,
  "data": {}
}
```

失败响应：

```json
{
  "ok": false,
  "data": null,
  "error": "serial required"
}
```

二进制下载类接口成功时不包 envelope，例如截图、文件下载和录屏视频。详细字段说明见 [api/README.md](api/README.md)。

## 使用提示

- 首次连接设备时，请确保手机已开启开发者选项和 USB 调试。
- 如果设备显示 `unauthorized`，需要在手机上确认 USB 调试授权。
- 文件管理中的部分目录可能受 Android 权限限制，无法浏览时属于设备侧权限约束。
- 安装 APK 时如果遇到签名冲突，后端会尝试按策略处理并返回更易读的错误信息。
- 执行 ADB 指令面板中的重启、卸载、清空等操作前，请确认目标设备和命令内容。

## 更多文档

- [API 响应协议与接口字段](api/README.md)
- [项目架构说明](PROJECT_OVERVIEW.md)
