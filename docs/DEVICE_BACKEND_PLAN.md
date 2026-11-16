# Android 与 iOS 设备接入方案

Flutter 复用设备列表、导航、测试会话和附件导出。Go 后端按能力提供设备操作，由 Android ADB、iOS 真机和 iOS 模拟器分别实现。界面用设备声明的能力选择入口，连接状态用于判断已支持的操作当前是否可用。

## 第一阶段 · Android

1. 从设备发现和截图入手。`Server` 依赖两个小接口，生产环境注入现有 `AdbManager`。设备列表增加 `platform` 和 `capabilities`，设备标识、截图 URL 和 PNG 响应保持兼容。
2. Flutter 用能力控制设备菜单、命令面板、快捷键访问和截图按钮。旧后端与本地历史设备按 Android 兼容读取。沿用现有设备入库和测试会话关联逻辑。
3. 回归 ADB 设备发现、截图和会话。Android 专属操作由现有实现提供，日志、录屏和文件访问在第二个平台需要共享时按能力扩展。

## 第二阶段 · iOS 真机

iOS 真机统一使用 `pymobiledevice3`。安装包附带预打包的 CLI 和 Python 运行时，Go 后端通过安装目录里与后端相邻的可执行文件调用 CLI。首版通过 USB 连接。Windows 按上游要求配置 Apple Mobile Device Service，并单独验证连接。 [上游安装与平台说明](https://doronz88.github.io/pymobiledevice3/installation/)

1. 用 `usbmux list` 发现设备，用 `crash ls` 查看报告，用 `crash pull` 导出选中的原始报告并保留手机上的副本。先走通「发现 iPhone → 查看崩溃报告 → 附到测试问题」。 [崩溃报告命令](https://doronz88.github.io/pymobiledevice3/latest/cli/crash/)
2. 聚合 Android 和 iOS 设备列表，按目标设备分派操作。同一台 iPhone 按 UDID 识别，用带类型的稳定 ID 区分真机和模拟器，保留历史 Android 主键。入库时记录平台及已知能力，以支持离线导航。后端按设备身份和能力校验请求。
3. 用 QA 实际使用的 iOS 版本和安装包验证实时日志、截图和 App 容器访问，再开放相应入口。日志保留原文，文件入口按目标 App 可访问范围提供。录屏先支持导入并保留实际文件格式。工具内录屏单独验证屏幕流的系统要求和输出格式。 [日志、截图和屏幕流命令](https://doronz88.github.io/pymobiledevice3/guides/cli-recipes/)

`pymobiledevice3` 使用 GPL-3.0-or-later。桌面安装包以独立 CLI 交付，并附上 `pymobiledevice3-source.zip`，包含相关源码、许可文件、依赖版本和构建脚本。 [上游许可说明](https://github.com/doronz88/pymobiledevice3/blob/master/docs/index.md#license-and-credits)

iOS 模拟器使用 `simctl` 作为独立实现。
