# 内置 Android 模拟器功能设计文档

> 创建日期: 2026-06-24
> 最后更新: 2026-06-24
> 项目: ADB Tool
> 分支: `feature/emulator-support` (已创建)

---

## 〇、关键决策 (Confirmed)

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 模拟器引擎 | **Google Android SDK Emulator** | 使用官方 `emulator` 二进制（内置 QEMU 库），而非标准 QEMU |
| SDK 管理 | **外部提供** | 用户已有 Android SDK，我们只调用 `sdkmanager`/`avdmanager` 工具 |
| 镜像来源 | **Google 官方** | 使用 Google 官方 system images (google_apis) |
| 下载方式 | **后端下载 + 断点续传** | 后端 Go 实现，支持 Range header 断点续传 |
| 目标平台 | **macOS arm64 + x86_64, Windows x86_64** | 跨平台支持 |
| AVD 管理 | **avdmanager** | 调用 `avdmanager create avd` 创建 AVD |

---

## 〇.1 关键概念澄清：为什么不是 QEMU，而是 Android SDK Emulator

### SDK 组件结构

项目已嵌入的 `platform-tools`（adb/scrcpy）和模拟器所需的 `emulator` 是独立的 SDK 组件：

```
Android SDK 根目录/
├── platform-tools/          ← 已嵌入 (~15MB)，包含 adb, fastboot
├── emulator/                ← 本功能需要的引擎 (~500MB+)
│   ├── emulator             ← 主程序（内置 QEMU 库）
│   ├── qemu/                ← QEMU 动态库（非独立 QEMU）
│   │   └── darwin-aarch64/
│   ├── lib64/               ← 平台动态库
│   └── package.xml
├── system-images/           ← Android 系统镜像 (每版本 1-5GB)
│   └── android-34/
│       └── google_apis/
│           └── arm64-v8a/
│               ├── system.img
│               ├── userdata.img
│               ├── ramdisk.img
│               ├── kernel-ranchu
│               └── vendor.img
├── cmdline-tools/           ← sdkmanager, avdmanager (~150MB, 创建/下载能力需要)
│   └── latest/bin/
│       ├── sdkmanager       ← SDK 组件下载管理（Java 工具）
│       └── avdmanager       ← AVD 创建/管理（Java 工具）
└── java-runtime/            ← 可选内置/下载的 JRE，用于运行 sdkmanager/avdmanager
    └── bin/java
```

### 为什么标准 QEMU 不能直接启动 Android 镜像

标准 QEMU 缺少 Android 必需的虚拟硬件：
- **goldfish/goldfish_pipe** — Android 虚拟设备核心通信通道
- **ranchu 虚拟平台** — QEMU2 上的 Android 虚拟主板
- **传感器、GPS、电池、radio** — Android 框架层依赖的专用虚拟设备
- **OpenGL ES 翻译层** — Android SurfaceFlinger 图形栈依赖

**结论**：本功能使用 Android SDK 中的 `emulator` 二进制（内建 QEMU 库），而非标准 `qemu-system-xxx`。

### 嵌入策略对比

| 策略 | 描述 | 体积 | 用户操作 | 推荐度 |
|------|------|------|----------|--------|
| 用户自行安装 | 让用户指定 `emulator` 路径 | 0MB (不嵌入) | 需手动安装 SDK | MVP ⭐ |
| sdkmanager 按需下载 | 集成 sdkmanager 自动拉取 | ~150MB (cmdline-tools) | 一键下载 | Phase 2 |
| 选择性嵌入 | 只嵌入 emulator 核心 | ~200MB | 开箱即用 | 后期可选 |

**MVP 采用方案1**：让用户指定 `emulator` 二进制路径或 `ANDROID_HOME` 根路径。

---

## 一、核心设计理念

- **不内置 SDK** — 用户提供 `emulator` 路径或 `ANDROID_HOME`，系统验证后使用
- **本地管理** — 镜像下载后存储在本地，支持展示和管理
- **一镜像多实例** — 同一系统镜像可创建多个独立 AVD 实例
- **与现有 ADB 生态融合** — 模拟器作为设备出现在现有设备列表中，操作与真机一致

---

## 二、数据模型设计

### 2.1 模拟器引擎配置 (EmulatorEngineConfig)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| androidHome | String | ANDROID_HOME 根路径 (或空) |
| emulatorPath | String | emulator 可执行文件完整路径 |
| avdmanagerPath | String | avdmanager 路径 |
| sdkmanagerPath | String | sdkmanager 路径 |
| javaPath | String | Java 可执行文件路径，用于运行 sdkmanager/avdmanager |
| javaVersion | String | `java -version` 输出 |
| version | String | `emulator -version` 输出 |
| isValid | bool | emulator/adb 路径是否有效 |
| toolchainReady | bool | cmdline-tools + Java 是否满足镜像下载与 AVD 创建需求 |
| lastVerified | DateTime | 最后验证时间 |

### 2.2 系统镜像 (EmulatorImage)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | String | 用户自定义名称 |
| apiLevel | int | API 级别 (33, 34, 35...) |
| arch | Enum | arm64-v8a / x86_64 |
| variant | String | google_apis / google_apis_playstore / default |
| sourceUrl | String | 下载地址 |
| localPath | String | 本地存储路径 (system-images 目录) |
| files | JSON | 镜像文件清单 (system.img, vendor.img, ramdisk.img, kernel-ranchu) |
| fileSize | int64 | 总文件大小 |
| checksum | String | SHA-256 校验和 |
| status | Enum | pending / downloading / ready / error |
| downloadProgress | double | 下载进度 0.0-1.0 |
| createdAt | DateTime | 创建时间 |
| lastUsedAt | DateTime | 最后使用时间 |

### 2.3 模拟器实例 (EmulatorInstance)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| imageId | UUID | 关联的镜像 ID |
| avdName | String | AVD 名称 (唯一) |
| avdPath | String | AVD 目录路径 (~/.android/avd/<name>) |
| config | JSON | 硬件配置 (CPU/内存/分辨率/density/sdcard) |
| status | Enum | stopped / starting / running / error |
| consolePort | int | 控制台端口 (5554, 5556...) |
| adbPort | int | ADB 端口 (控制台端口 + 1 = 5555, 5557...) |
| pid | int | emulator 进程 PID |
| serial | String | ADB serial (emulator-5554 或 localhost:5555) |
| snapshotId | UUID? | 关联快照 (可选) |
| createdAt | DateTime | 创建时间 |
| lastStartedAt | DateTime? | 最后启动时间 |

### 2.4 实例快照 (EmulatorSnapshot)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| instanceId | UUID | 关联的实例 ID |
| name | String | 快照名称 |
| description | String | 描述 |
| size | int64 | 快照文件大小 |
| createdAt | DateTime | 创建时间 |

---

## 三、核心模块划分

### 3.1 配置层 (Flutter)

| Provider | 职责 |
|----------|------|
| EmulatorEngineProvider | 管理 emulator 路径配置、版本验证、建议路径自动检测 |
| EmulatorJavaProvider | 管理 Java 运行环境检测、下载、安装和版本校验 |
| EmulatorImageProvider | 镜像列表、下载状态、进度管理 |
| EmulatorInstanceProvider | 实例生命周期、启动/停止、状态监控 |

### 3.2 下载服务 (Flutter)

| Service | 职责 |
|---------|------|
| DownloadService | 镜像下载，支持断点续传、进度回调、并发控制 |
| ChecksumVerifier | 下载完成后校验文件完整性 (SHA-256) |

### 3.3 模拟器后端 (Backend/Go)

| Service | 职责 |
|---------|------|
| EmulatorEngine | 验证 emulator 二进制、获取版本/能力信息 |
| JavaRuntimeManager | 检测本机 Java、下载/安装内置 JRE、为 sdkmanager/avdmanager 提供 javaPath |
| AvdManager | 创建/删除/列出 AVD，解析 config.ini |
| EmulatorLauncher | 启动/停止 emulator 进程，构建命令行参数 |
| PortAllocator | 管理控制台端口池 (5554-5584)，检测占用、自动分配 |
| EmulatorWatcher | 监控进程 PID、健康检查、异常检测 |
| ImageManager | 镜像文件存储、校验、清理 |

### 3.4 ADB 集成

- emulator 启动后通过 ADB daemon 自动发现或手动 `adb connect localhost:<adb_port>`
- 后端 `adb_devices.go` 已能识别 `emulator-5554` 格式的设备 serial
- 模拟器实例出现在 Flutter 设备列表中，带 🖥️ 图标区分于 📱 真机

### 3.5 与现有架构的关系

```
┌─────────────────────────────────────────────────────┐
│ Flutter UI (现有侧边栏设备树 + 新增模拟器设置页)     │
├─────────────────────────────────────────────────────┤
│ ApiClient (facade)  ← 新增 emulator_api.dart        │
├─────────────────────────────────────────────────────┤
│ Go Backend (:9876)                                   │
│ ├── internal/server/handlers_emulator.go  ← 新增     │
│ ├── internal/emulator/                    ← 新增     │
│ │   ├── engine.go       (验证 emulator 路径)         │
│ │   ├── avd.go          (AVD CRUD)                   │
│ │   ├── launcher.go     (进程启动/停止)               │
│ │   ├── watcher.go      (进程健康监控)                │
│ │   ├── port_allocator.go                            │
│ │   └── console.go      (控制台 telnet 通信)          │
│ ├── internal/server/adb_devices.go  ← 现有，复用      │
│ └── internal/server/handlers_devices.go ← 复用       │
└─────────────────────────────────────────────────────┘
```

---

## 四、UI 界面设计

### 4.1 模拟器设置页面 (新增侧边栏入口)

```
┌─────────────────────────────────────────────────────┐
│ 🖥️ Android 模拟器                                    │
├─────────────────────────────────────────────────────┤
│ 模拟器引擎                                          │
│ ┌─────────────────────────────────────────────────┐ │
│ │ ANDROID_HOME: [/Users/xxx/Library/Android/sdk] │ │
│ │ emulator 路径: [自动检测: /emulator/emulator  ] │ │
│ │ 版本: Android emulator 35.2.9                    │ │
│ │ 状态: ✅ 就绪                                    │ │
│ │ [重新检测]                [手动指定路径...]      │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 系统镜像                                            │
│ ┌─────────────────────────────────────────────────┐ │
│ │ [+ 添加系统镜像]   (URL 或本地路径)              │ │
│ └─────────────────────────────────────────────────┘ │
│                                                    │
│ 📦 Android 14 (API 34) google_apis arm64-v8a       │
│    5.1 GB | ✅ 就绪 | 2024-06-20              [删除]│
│                                                    │
│ 📦 Android 13 (API 33) google_apis arm64-v8a       │
│    4.2 GB | ⬇️ 下载中 78%...                [取消] │
├─────────────────────────────────────────────────────┤
│ 模拟器实例                                          │
│ ┌─────────────────────────────────────────────────┐ │
│ │ [+ 从镜像创建新实例]                             │ │
│ └─────────────────────────────────────────────────┘ │
│                                                    │
│ 🟢 Android-14-Dev-1         端口: 5555  [停止]    │
│    CPU: 4核 | 内存: 4GB | 分辨率: 1080x1920       │
│    AVD: Android-14-Dev-1 | PID: 12345              │
│                                                    │
│ 🟢 Android-14-Test         端口: 5557  [停止]     │
│    CPU: 2核 | 内存: 2GB | 分辨率: 720x1280        │
│                                                    │
│ ⚫ Android-13-Dev-2         端口: —     [启动]     │
│    CPU: 4核 | 内存: 4GB | 创建于 2024-06-18       │
└─────────────────────────────────────────────────────┘
```

### 4.2 设备选择下拉 (复用现有侧边栏设备列表)

- 已连接的模拟器实例出现在设备列表中，使用不同图标区分于 USB/WiFi 设备
- 点击后进入现有功能页面 (Logcat/文件/应用/截图/投屏)，操作与真机完全一致
- 模拟器 serial 格式: `emulator-5554` 或 `localhost:5555`

### 4.3 创建实例对话框

```
┌─────────────────────────────────────────────────────┐
│ 创建模拟器实例                                       │
├─────────────────────────────────────────────────────┤
│ 选择镜像: [Android 14 (API 34) ▼]                   │
│ AVD 名称: [Android-14-Dev-3_____________________]   │
│                                                     │
│ 硬件配置:                                            │
│ ├─ CPU 核心数: [4 ▼]  (1-8)                         │
│ ├─ 内存大小:   [4 GB ▼]  (512MB - 16GB)            │
│ ├─ 屏幕分辨率: [1080x1920 ▼]                        │
│ ├─ 屏幕密度:   [420 dpi ▼]                          │
│ └─ SD 卡大小:  [512 MB ▼]  (无 / 128MB - 2GB)      │
│                                                     │
│ 高级选项:                                            │
│ ├─ GPU 加速:   [auto ▼]  (auto/host/off)           │
│ └─ 启动快照:   [无 ▼]                               │
│                                                     │
│          [取消]              [创建 & 启动]            │
└─────────────────────────────────────────────────────┘
```

### 4.4 添加镜像对话框

```
┌─────────────────────────────────────────────────────┐
│ 添加系统镜像                                         │
├─────────────────────────────────────────────────────┤
│ 镜像来源:                                            │
│ ◉ URL 下载                                          │
│   URL: [https://...android-34-system-image.zip]     │
│                                                      │
│ ○ 本地路径                                          │
│   路径: [选择目录...]  (system-images/android-34/)  │
│                                                      │
│ 镜像信息 (自动识别或手动填写):                       │
│ ├─ 名称: [Android 14 (API 34)                       │
│ ├─ API 级别: [34 ▼]                                 │
│ └─ 架构: [arm64-v8a ▼]  (arm64-v8a / x86_64)      │
│                                                      │
│          [取消]              [确认添加]               │
└─────────────────────────────────────────────────────┘
```

---

## 五、后端 API 设计

### 5.1 模拟器引擎

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/emulator/engine/validate | 验证 emulator 路径，返回版本/能力 |
| PUT | /api/emulator/engine/config | 更新 emulator 路径配置 |
| GET | /api/emulator/engine/status | 获取引擎状态 (路径/版本/是否就绪) |
| GET | /api/emulator/java/status | 获取 Java 运行环境状态 |
| POST | /api/emulator/java/validate | 验证指定 javaPath 是否可用 |
| POST | /api/emulator/java/download | 下载并安装内置 JRE |
| GET | /api/emulator/java/download-progress | 获取 JRE 下载进度 (SSE) |

### 5.2 系统镜像

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/emulator/images | 添加镜像 (URL 或本地路径) |
| GET | /api/emulator/images | 列出所有镜像及状态 |
| GET | /api/emulator/images/:id | 获取单个镜像详情 |
| DELETE | /api/emulator/images/:id | 删除镜像文件 |
| GET | /api/emulator/images/:id/download-progress | 获取下载进度 (SSE) |
| POST | /api/emulator/images/:id/cancel-download | 取消下载 |

### 5.3 模拟器实例

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/emulator/instances | 创建实例 (AVD) |
| POST | /api/emulator/instances/:id/start | 启动实例 |
| POST | /api/emulator/instances/:id/stop | 停止实例 (graceful → force) |
| GET | /api/emulator/instances | 列出所有实例及状态 |
| GET | /api/emulator/instances/:id | 获取单个实例详情 (含实时状态) |
| PUT | /api/emulator/instances/:id | 更新实例配置 |
| DELETE | /api/emulator/instances/:id | 删除实例及 AVD 目录 |

### 5.4 快照 (Phase 3+)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/emulator/instances/:id/snapshots | 创建快照 |
| GET | /api/emulator/instances/:id/snapshots | 列出快照 |
| POST | /api/emulator/instances/:id/snapshots/:snapId/restore | 恢复快照 |
| DELETE | /api/emulator/instances/:id/snapshots/:snapId | 删除快照 |

### 5.5 WebSocket 状态推送

| 路径 | 说明 |
|------|------|
| /ws/emulator/status | 推送所有实例的运行状态变更 (started/stopped/error/health) |

---

## 六、技术实现要点

### 6.1 emulator 路径检测策略

后端启动后自动尝试以下路径 (优先级从高到低):

```go
// 检测顺序
candidates := []string{
    os.Getenv("ANDROID_HOME") + "/emulator/emulator",
    os.Getenv("ANDROID_SDK_ROOT") + "/emulator/emulator",
    homeDir + "/Library/Android/sdk/emulator/emulator",   // macOS
    homeDir + "/Android/Sdk/emulator/emulator",            // Linux
    homeDir + "/AppData/Local/Android/Sdk/emulator/emulator.exe", // Windows
}
```

验证标准:
```bash
$EMULATOR_PATH -version
# 期望输出包含 "Android emulator version"
# 返回版本号和构建信息
```

### 6.2 Java 运行环境检测与下载

创建 AVD 和下载 SDK 组件需要调用 `avdmanager` / `sdkmanager`，这两个工具本质上是 Java 程序。只启动已有 emulator 和使用 adb 不需要 Java，但本项目目标是让用户在已有镜像后可以在工具内自由创建 AVD，因此 Java 运行环境属于核心前置依赖。

检测顺序:

```go
javaCandidates := []string{
    configuredJavaPath,
    os.Getenv("JAVA_HOME") + "/bin/java",
    androidToolCache + "/java-runtime/bin/java",
    lookupPath("java"),
}
```

验证标准:

```bash
$JAVA_PATH -version
# 期望 exit code = 0
# 记录 vendor/version/arch，优先接受 Java 17，其次 Java 11；旧版 Android SDK tools 可兜底 Java 8
```

下载策略:

- 首选使用应用内资源清单或官方发行渠道下载平台匹配的 JRE/JDK 压缩包
- 下载到 `~/.adb-tool/emulator/cache/downloads/`
- 校验 SHA-256 后解压到 `~/.adb-tool/emulator/java-runtime/<vendor>-<version>-<platform>/`
- 将最终 `bin/java` 写入 `EmulatorEngineConfig.javaPath`
- 后端调用 `sdkmanager` / `avdmanager` 时显式设置 `JAVA_HOME` 和 `PATH`，不修改用户全局环境变量

UI 行为:

- 引擎配置区增加 Java 状态卡片：未检测到 / 已检测到 / 版本不兼容 / 正在下载 / 就绪
- 未就绪时，镜像下载和创建实例按钮置灰，并提示先安装 Java 运行环境
- 提供“自动下载 Java 运行环境”和“手动选择 java 可执行文件”两个入口

### 6.3 AVD 创建与管理

两种方案选型:

**方案 A: avdmanager (推荐 MVP)**
```bash
# 创建 AVD
JAVA_HOME=<java_home> \
avdmanager create avd \
  -n <avd_name> \
  -k "system-images;android-34;google_apis;arm64-v8a" \
  -d "pixel_6" \
  -p <custom_avd_path>

# 生成 config.ini，写入 CPU/内存/分辨率等硬件参数
```

调用前置条件:
- `javaPath` 可用
- `avdmanagerPath` 可用，优先使用 `$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager`
- 避免使用旧版 `$ANDROID_HOME/tools/bin/avdmanager`，仅作为兜底；旧版工具可能要求 Java 8，且无法解析新 SDK package.xml 字段

**方案 B: 直接构建 AVD 目录 (无 avdmanager 依赖)**
```bash
# 手动创建 AVD 目录和 config.ini
mkdir -p ~/.android/avd/<avd_name>.avd
cat > ~/.android/avd/<avd_name>.ini << EOF
avd.ini.encoding=UTF-8
path=<avd_path>
path.rel=avd/<avd_name>.avd
target=android-34
EOF

cat > ~/.android/avd/<avd_name>.avd/config.ini << EOF
hw.cpu.ncore=4
hw.ramSize=4096
hw.lcd.width=1080
hw.lcd.height=1920
hw.lcd.density=420
disk.dataPartition.size=8G
hw.gpu.enabled=yes
hw.gpu.mode=auto
image.sysdir.1=<system_image_path>
EOF
```

**当前建议**：Phase 1 采用方案 A（avdmanager + Java 运行环境），因为产品目标是让用户基于镜像自由创建 AVD；方案 B 保留为工具链不可用时的兜底实现和异常恢复手段。

### 6.4 启动命令

```bash
$EMULATOR_PATH \
  -avd <avd_name> \
  -port <console_port> \
  -no-window \
  -no-audio \
  -no-boot-anim \
  -netdelay none \
  -netspeed full \
  -gpu swiftshader_indirect \
  -memory <ram_mb> \
  -cores <cpu_cores> \
  -read-only \
  -snapshot <snapshot_name> \    # 可选
  -verbose
```

关键参数说明:
- `-port <console_port>` — 控制台端口，ADB 端口自动为 `console_port + 1`
- `-no-window` — 无头模式，不弹出 emulator GUI 窗口 (scrcpy 代替显示)
- `-no-audio` — 禁用音频，减少资源占用
- `-gpu swiftshader_indirect` — 软件渲染，兼容性最好
- `-snapshot <name>` — 从指定快照启动
- `-read-only` — 系统分区只读，退出不保存修改

### 6.5 ADB 连接

emulator 启动后，有两种自动连接方式:

1. **ADB daemon 自动发现** (推荐): emulator 注册到本地 ADB daemon，`adb devices` 自动列出 `emulator-5554`
2. **手动连接** (备选): `adb connect localhost:5555`

后端在启动 emulator 后轮询 `adb devices` 直到设备出现 (超时 60s):

```go
func waitForEmulator(adbPort int, timeout time.Duration) error {
    serial := fmt.Sprintf("emulator-%d", adbPort)
    deadline := time.Now().Add(timeout)
    for time.Now().Before(deadline) {
        devices, _ := Devices()
        for _, d := range devices {
            if d.Serial == serial && d.State == "device" {
                return nil
            }
        }
        time.Sleep(2 * time.Second)
    }
    return fmt.Errorf("timeout waiting for emulator %s", serial)
}
```

### 6.5 进程管理

```go
// 启动
cmd := exec.Command(emulatorPath, args...)
cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}  // 独立进程组
cmd.Start()

// 优雅停止: adb emu kill
adbExec(serial, "emu", "kill")

// 强制停止: SIGTERM -> 等待 10s -> SIGKILL
cmd.Process.Signal(syscall.SIGTERM)
time.Sleep(10 * time.Second)
if processRunning(cmd.Process.Pid) {
    cmd.Process.Signal(syscall.SIGKILL)
}
```

### 6.6 进程健康监控

emulator 进程崩溃检测:
- 每 5 秒检查 PID 是否存活
- 每 30 秒通过 `adb shell getprop sys.boot_completed` 检查启动完成
- 检查 ADB 连接是否仍然有效
- 异常时自动标记实例状态为 error，通知前端 (WebSocket)

### 6.8 端口分配策略

```
控制台端口范围: 5554, 5556, 5558, ..., 5584 (偶数端口，共 16 对)
ADB 端口:       控制台端口 + 1 (5555, 5557, ..., 5585)

分配逻辑:
1. 扫描当前所有实例占用的端口
2. 使用 lsof / netstat 检查端口是否被占用
3. 从池中分配第一个可用端口对
4. 如果端口池耗尽，报错提示用户停止不需要的实例
```

### 6.8 镜像下载 (Backend 端实现)

```
流程:
1. 接收 URL + 目标路径
2. 发起 HTTP GET，支持 Range header (断点续传)
3. 分块下载 (默认 4MB 块)，每块完成时更新进度到内存状态
4. 前端通过 GET /api/emulator/images/:id/download-progress (SSE/轮询) 获取进度
5. 下载完成后校验 SHA-256
6. 标记状态为 ready，解压 (如果是 zip)
7. 解析 system-images 目录结构，提取镜像文件清单
```

### 6.10 模拟器运行时控制（控制台 Telnet）

模拟器启动后在控制台端口（如 5554）上开启 telnet 服务，这是 Android Studio 修改 GPS/网络/电池等功能**完全相同的底层机制**。

#### 控制台通信协议

```go
// 连接控制台
conn, _ := net.Dial("tcp", fmt.Sprintf("localhost:%d", consolePort))
// 发送命令 (格式: "command args\n")
conn.Write([]byte("geo fix 121.4737 31.2304\n"))
// 读取响应 (OK 或 KO: error message)
buf := make([]byte, 1024)
n, _ := conn.Read(buf) // 返回 "OK\n" 或 "KO: ...\n"
```

#### 完整控制命令参考

| 分类 | 控制台命令 | 参数 | 说明 |
|------|-----------|------|------|
| **GPS 定位** | `geo fix <lon> <lat> [alt] [satellites]` | 经度/纬度/海拔/卫星数 | 设置单个 GPS 位置 |
| **GPS 轨迹** | `geo nmea <sentence>` | NMEA 0183 语句 | 回放轨迹 (GPX 可转 NMEA) |
| **GPS 状态** | `geo status` | — | 查询当前 GPS 状态 |
| **网络速度** | `network speed <profile>` | gsm/hscsd/gprs/edge/umts/hsdpa/hspa/lte/evdo/full | 模拟不同网络制式 |
| **网络延迟** | `network delay <profile>` | gprs(150-550ms)/edge(80-400ms)/umts(35-200ms)/none | 模拟网络延迟 |
| **网络延迟** | `network delay <milliseconds>` | 0-60000 | 自定义延迟毫秒数 |
| **网络状态** | `network status <state>` | up/down | 网络通断切换 |
| **网络恢复** | `network restore` | — | 恢复网络默认值 |
| **电池电量** | `power capacity <pct>` | 0-100 | 设置电量百分比 |
| **电池状态** | `power status <state>` | unknown/charging/discharging/not-charging/full | 充电状态 |
| **AC 电源** | `power ac <state>` | on/off | AC 充电器接入 |
| **无线充电** | `power wireless <state>` | on/off | 无线充电 |
| **电池健康** | `power health <state>` | good/dead/overheat/overvoltage/unknown | 电池健康 |
| **电量显示** | `power display` | — | 查看当前电源状态 |
| **信号强度** | `gsm signal-strength-profile <p>` | 如 `gsm signal-strength-profile 2` | 设置信号强度档位 |
| **信号强度** | `gsm signal <rssi> [ber]` | RSSI 值 (0-31, 99=未知) | 精确信号强度 |
| **语音状态** | `gsm voice <state>` | unregistered/home/roaming/searching/denied/off/on | 语音服务状态 |
| **数据状态** | `gsm data <state>` | unregistered/home/roaming/searching/denied/off/on | 数据服务状态 |
| **模拟短信** | `sms send <from> <text>` | 发件人号码 + 文本 | 向模拟器发送短信 |
| **短信列表** | `sms pdu <hex>` | PDU 格式 | 发送 PDU 格式短信 |
| **模拟来电** | `gsm call <number>` | 来电号码 | 模拟来电 |
| **通话控制** | `gsm accept\|cancel\|hold` | — | 接听/拒接/保持 |
| **通话列表** | `gsm list` | — | 列出当前通话 |
| **传感器状态** | `sensor status` | — | 列出所有传感器 |
| **设置传感器** | `sensor set <name> <x:y:z>` | 传感器名 + 三维值 | 设置传感器数值 |
| **物理传感器** | `sensor set physical <name> <x:y:z>` | 同上 | 设置物理传感器 |
| **指纹模拟** | `finger touch <id>` | 手指 ID | 模拟指纹识别 |
| **旋转屏幕** | `rotate` | — | 旋转屏幕方向 |
| **硬件事件** | `event send <type:code:value>` | Linux input 事件 | 发送硬件输入事件 |
| **AVD 名称** | `avd name` | — | 查询当前 AVD 名称 |
| **窗口缩放** | `window scale <factor>` | 缩放因子 | 调整窗口大小 |

#### 扩展 API (运行时控制)

在 `handlers_emulator.go` 中新增:

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/emulator/instances/:id/gps` | 设置 GPS 位置 `{"lon": 121.47, "lat": 31.23, "alt": 0}` |
| GET | `/api/emulator/instances/:id/gps` | 获取当前 GPS 状态 |
| POST | `/api/emulator/instances/:id/network` | 设置网络参数 `{"speed": "lte", "delay": 100}` |
| POST | `/api/emulator/instances/:id/network/restore` | 恢复网络默认值 |
| POST | `/api/emulator/instances/:id/power` | 设置电源参数 `{"capacity": 80, "status": "discharging"}` |
| POST | `/api/emulator/instances/:id/sms` | 发送模拟短信 `{"from": "10086", "text": "..."}` |
| POST | `/api/emulator/instances/:id/call` | 模拟来电 `{"number": "10086"}` |
| POST | `/api/emulator/instances/:id/call/action` | 通话操作 `{"action": "accept\|cancel\|hold"}` |
| POST | `/api/emulator/instances/:id/sensor` | 设置传感器 `{"sensor": "acceleration", "values": [0, 9.8, 0]}` |
| POST | `/api/emulator/instances/:id/fingerprint` | 模拟指纹 `{"fingerId": 1}` |
| POST | `/api/emulator/instances/:id/console` | 透传任意控制台命令 `{"cmd": "geo fix ..."}` |

#### 控制面板 UI 设计

```
┌─────────────────────────────────────────────────────┐
│ 模拟器运行时控制  [Android-14-Dev-1 :5555]           │
├─────────────────────────────────────────────────────┤
│ 📍 GPS                                              │
│ ┌─────────────────────────────────────────────────┐ │
│ │  经度: [121.4737____]  纬度: [31.2304____]      │ │
│ │  海拔: [0________] (可选)                        │ │
│ │  [📍 提交定位]                                   │ │
│ ├─────────────────────────────────────────────────┤ │
│ │  快捷位置: [上海 ▼] [北京] [深圳] [自定义]      │ │
│ │  当前: 121.4737, 31.2304                        │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 🌐 网络                                             │
│ ┌─────────────────────────────────────────────────┐ │
│ │  速度: [LTE ▼] (GSM/3G/4G/LTE/Full)            │ │
│ │  延迟: [100 ms ▼] (无/GPRS/EDGE/UMTS/自定义)   │ │
│ │  状态: [● 已连接]                               │ │
│ │  [应用设置]  [恢复默认]                          │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 🔋 电源                                             │
│ ┌─────────────────────────────────────────────────┐ │
│ │  电量: [━━━━━━━━━━━━━ 80%]                      │ │
│ │  状态: [正在放电 ▼]                              │ │
│ │  AC:  [○ 未连接]    无线充电: [○ 未连接]        │ │
│ │  [应用设置]                                      │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 📱 电话/短信                                        │
│ ┌─────────────────────────────────────────────────┐ │
│ │  模拟来电: [10086_________]  [📞 拨打]           │ │
│ │  发送短信:                                     │ │
│ │    发件人: [10086_________]                     │ │
│ │    内容:   [________________]                   │ │
│ │    [📩 发送短信]                                │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ ✋ 指纹                                             │
│   [Touch Finger 1]                                 │
└─────────────────────────────────────────────────────┘
```

---

## 七、文件结构建议

```
flutter_app/
├── lib/
│   ├── models/
│   │   ├── emulator_engine.dart       # EmulatorEngineConfig 模型
│   │   ├── emulator_image.dart        # EmulatorImage 模型
│   │   ├── emulator_instance.dart     # EmulatorInstance 模型
│   │   └── emulator_snapshot.dart     # EmulatorSnapshot 模型
│   │
│   ├── providers/
│   │   ├── emulator_engine_provider.dart     # 引擎配置 + 验证
│   │   ├── emulator_java_provider.dart       # Java 运行环境检测 + 下载状态
│   │   ├── emulator_image_provider.dart      # 镜像列表 + 下载状态
│   │   ├── emulator_instance_provider.dart   # 实例 CRUD + 启动/停止
│   │   └── emulator_download_provider.dart   # 下载进度实时更新
│   │
│   ├── services/
│   │   ├── emulator_api.dart          # REST API 调用
│   │   ├── download_service.dart      # 下载管理
│   │   └── emulator_status_stream.dart # WebSocket 状态推送
│   │
│   ├── screens/
│   │   └── emulator_settings_screen.dart    # 主设置页面
│   │
│   ├── widgets/
│   │   ├── emulator_engine_config_card.dart    # 引擎配置卡片
│   │   ├── emulator_image_card.dart            # 镜像卡片 (含进度条)
│   │   ├── emulator_instance_card.dart         # 实例卡片 (含状态指示)
│   │   ├── create_instance_dialog.dart         # 创建实例对话框
│   │   ├── add_image_dialog.dart               # 添加镜像对话框
│   │   └── emulator_control_panel.dart         # 运行时控制面板 (GPS/网络/电源/...)
│   │
│   └── i18n/
│       └── emulator.dart              # 国际化文本
│
backend/
├── internal/
│   ├── emulator/
│   │   ├── engine.go                  # emulator 二进制验证 + 能力查询
│   │   ├── java_runtime.go            # Java 检测、下载、安装、版本校验
│   │   ├── avd.go                     # AVD 创建/删除/列表/config.ini 解析
│   │   ├── launcher.go               # emulator 进程启动/停止
│   │   ├── watcher.go                # 进程健康监控 + 状态推送
│   │   ├── port_allocator.go         # 控制台端口分配管理
│   │   ├── image_manager.go          # 镜像存储路径管理
│   │   ├── downloader.go            # 镜像下载 (HTTP + 断点续传)
│   │   └── console.go               # 控制台 telnet 通信封装
│   │
│   └── server/
│       └── handlers_emulator.go      # API 路由处理
```

---

## 八、存储路径规划

```
~/.adb-tool/
├── emulator/
│   ├── java-runtime/                 # 下载/解压后的 Java 运行环境
│   │   └── <vendor>-<version>-<platform>/
│   │       └── bin/java
│   ├── system-images/                # 下载的系统镜像
│   │   └── android-34/
│   │       └── google_apis/
│   │           └── arm64-v8a/
│   │               ├── system.img
│   │               ├── vendor.img
│   │               ├── ramdisk.img
│   │               └── kernel-ranchu
│   └── avd/                           # AVD 数据目录
│       └── <avd_name>.avd/
│           ├── config.ini
│           ├── userdata.img
│           ├── sdcard.img
│           └── snapshots/
└── ...                                # 现有数据
```

---

## 九、实施计划

### Phase 1: 引擎配置 + 基础框架 (MVP) ✅ 已完成
1. 新建分支 `feature/emulator-support`
2. Flutter: 数据模型 + 数据库表
3. Flutter: EmulatorEngineProvider + 引擎配置 UI
4. Backend: `/api/emulator/engine/validate` + `/api/emulator/engine/config`
5. Backend: 模拟器数据模型 JSON 文件持久化 (SQLite 由 Flutter drift 管理)

**Phase 1 增强: SDK 多来源支持 (2026-06-24)**
- ✅ 支持扫描系统已有 SDK 路径 (`/api/emulator/sdk/detect`)
- ✅ 支持选择/指定 SDK 路径 (`/api/emulator/sdk/use`)
- ✅ 支持下载 SDK (`/api/emulator/sdk/download`)
- ✅ 支持导入 SDK 压缩包 (`/api/emulator/sdk/import`)
- ✅ Flutter UI 支持三种来源切换 + 实时进度

### Phase 2: Java 运行环境 + 工具链准备
1. Backend: JavaRuntimeManager 检测本机 Java、内置 JRE、版本兼容性
2. Backend: JRE 下载、断点续传、SHA-256 校验、解压安装
3. Flutter: Java 状态卡片 + 自动下载/手动选择入口
4. Backend: 检测 cmdline-tools/latest 下的 sdkmanager/avdmanager，旧版 tools/bin 仅作为兜底提示

### Phase 3: 镜像管理 + 下载
1. Backend: 镜像下载 (HTTP + 断点续传)
2. Flutter: 镜像列表 UI + 下载进度
3. Flutter: 添加镜像对话框 (URL/本地路径)
4. Backend: 镜像信息解析 (system-images 目录结构)

### Phase 4: 实例管理 (核心)
1. Backend: AVD 创建/删除 (方案 A: avdmanager + Java，方案 B: 直接构建目录兜底)
2. Backend: emulator 启动/停止/监控
3. Backend: PortAllocator 端口分配
4. Flutter: 创建实例对话框 + 实例列表 UI
5. Flutter: WebSocket 状态推送集成

### Phase 4: 运行时控制
1. Backend: console.go — telnet 控制台通信封装
2. Backend: GPS/网络/电源/电话短信/传感器 API
3. Flutter: emulator_control_panel.dart — 运行时控制面板
4. Flutter: GPS 快捷位置预设 + 地图选点 (可选)

### Phase 6: 融合 + 完善
1. 模拟器实例出现在设备列表中，与现有功能打通
2. 多实例并发运行支持
3. 实例配置编辑
4. 快照创建/恢复 (可选)
5. 性能优化 + macOS 平台兼容

---

## 十、关键技术风险

| 风险 | 等级 | 应对方案 |
|------|------|----------|
| macOS Apple Silicon 上 x86_64 模拟器需 Rosetta | 🔴 高 | 优先引导用户使用 arm64-v8a 镜像；检测架构并给出提示 |
| emulator 版本兼容性 | 🟡 中 | 启动前检查 `-version`，设定最低版本要求 (≥ 31.x) |
| Java 环境缺失或版本不兼容 | 🔴 高 | 内置 JavaRuntimeManager，支持自动下载 JRE、手动选择 javaPath、按工具链版本选择 Java 17/11/8 |
| 旧版 sdkmanager/avdmanager 与新 SDK 元数据不兼容 | 🟡 中 | 优先使用 cmdline-tools/latest，旧版 tools/bin 只做兜底并显示明确修复建议 |
| 系统镜像体积大，下载失败率高 | 🟡 中 | 必须支持断点续传 + SHA-256 校验 |
| 端口冲突 | 🟡 中 | PortAllocator 检测端口占用 + 冲突时自动换端口 |
| 模拟器启动慢 (首次 1-3 分钟) | 🟢 低 | 添加 loading 状态 + 启动日志透传 |
| 进程残留 (崩溃/强制退出) | 🟡 中 | 后端启动时扫描清理孤儿 emulator 进程 |
| macOS 上 Hypervisor.Framework 权限 | 🟡 中 | 检测 HVF 是否可用，fallback 到软件模拟 |
| AVD config.ini 参数在不同 emulator 版本间差异 | 🟡 中 | 按版本兼容的最低字段集合，核心参数标准化 |
| 已存在的 ANDROID_HOME 与 .adb-tool 数据目录冲突 | 🟢 低 | .adb-tool/emulator/ 作为独立数据目录 |

---

## 十一、与现有功能的集成点

| 现有功能 | 集成方式 |
|----------|----------|
| 侧边栏设备列表 | emulator 启动后自动出现在设备树中，与 USB/WiFi 设备并列 |
| Logcat | 复用现有 `/ws/logs` WebSocket，以 emulator serial 建立连接 |
| 文件管理 | 复用现有文件 API，模拟器文件系统与真机操作一致 |
| 应用管理 | 复用 APK 安装/卸载/列表 |
| 截图/录屏 | 复用现有 screenshot/screen-record API |
| scrcpy 投屏 | emulator 以 `-no-window` 启动，用 scrcpy 投屏显示画面 |
| 测试会话 (Test Session) | 模拟器实例作为测试目标设备，记录步骤/截图/logcat |
| 剪贴板同步 | 复用剪贴板助手 APK |

---

## 十二、测试策略

1. **单元测试**: Provider 状态转换、端口分配算法、config.ini 解析
2. **集成测试**: emulator 路径验证、AVD 创建/删除、启动/停止流程
3. **E2E 测试**: 完整流程 (配置引擎→添加镜像→创建实例→启动→ADB 连接→操作设备)
4. **异常测试**: 下载中断恢复、进程异常退出恢复、端口冲突处理

---

## 十三、后续可选：公司内部资源清单 manifest.json

在公司内部测试场景下，如果 emulator 引擎、Android system image、AVD 模板、测试场景模板等大文件可以统一放在 NAS 或内部文件服务上，则可以增加一个 `manifest.json` 资源清单机制。

该方案不作为初期必须能力，放在后续增强中考虑。它的目标是让测试人员可以在工具内直接选择公司标准配置，自动下载安装到本地缓存，并基于统一资源创建可复现的模拟器测试环境。

### 13.1 设计目标

- **统一测试环境** — 公司统一维护 emulator 版本、system image 版本、AVD 模板和测试场景模板
- **降低使用门槛** — 测试人员不需要手动安装 Android Studio 或手动配置 SDK 路径
- **本地缓存运行** — NAS/内部服务只作为资源分发源，下载后在本地运行，避免直接从 NAS 运行导致性能和稳定性问题
- **可复现测试** — 测试报告记录使用的 emulator、system image、AVD 模板、场景模板版本
- **后续可扩展** — 新增 Android 版本、设备模板、弱网/低电量等测试场景时，只需要更新 manifest，不一定需要客户端发版

### 13.2 推荐资源仓库结构

推荐使用内部 HTTP/HTTPS 文件服务暴露 NAS 文件，而不是让客户端直接访问 SMB 路径。

```text
NAS / 内部 HTTP 文件服务
├── manifest.json
├── emulator/
│   ├── macos-arm64/
│   │   └── emulator-35.4.9-macos-arm64.zip
│   ├── macos-x64/
│   │   └── emulator-35.4.9-macos-x64.zip
│   └── windows-x64/
│       └── emulator-35.4.9-windows-x64.zip
├── java-runtime/
│   ├── macos-arm64/
│   │   └── jre-17-macos-arm64.zip
│   ├── macos-x64/
│   │   └── jre-17-macos-x64.zip
│   └── windows-x64/
│       └── jre-17-windows-x64.zip
├── system-images/
│   ├── android-14/
│   │   ├── google_apis-arm64-v8a.zip
│   │   └── google_apis-x86_64.zip
│   └── android-15/
│       ├── google_apis-arm64-v8a.zip
│       └── google_apis-x86_64.zip
├── avd-templates/
│   ├── pixel_6_android_14.json
│   └── low_end_android_13.json
└── scenario-templates/
    ├── weak_network.json
    ├── low_battery.json
    ├── gps_shanghai.json
    └── sms_login.json
```

### 13.3 本地缓存结构

资源下载后应解压到本地缓存目录，模拟器运行时只访问本地文件。

```text
~/.adb-tool/
└── emulator/
    ├── engines/
    │   ├── emulator-macos-arm64-35.4.9/
    │   └── emulator-macos-arm64-36.1.2/
    ├── java-runtime/
    │   └── jre-17-macos-arm64/
    ├── system-images/
    │   ├── android-14-google-apis-arm64-r1/
    │   └── android-15-google-apis-arm64-r1/
    ├── avd/
    │   └── pixel6-api34-standard-001.avd/
    └── cache/
        ├── downloads/
        └── manifest.json
```

资源版本不应覆盖旧版本，应以目录隔离方式并存，方便测试报告复现和历史问题回放。

### 13.4 manifest.json 示例

```json
{
  "version": 1,
  "updatedAt": "2026-06-24T10:00:00Z",
  "emulators": [
    {
      "id": "emulator-macos-arm64-35.4.9",
      "platform": "macos-arm64",
      "version": "35.4.9",
      "url": "https://nas.company.com/android/emulator/macos-arm64/emulator-35.4.9.zip",
      "sha256": "xxxx",
      "size": 523000000,
      "minOsVersion": "macOS 13"
    },
    {
      "id": "emulator-windows-x64-35.4.9",
      "platform": "windows-x64",
      "version": "35.4.9",
      "url": "https://nas.company.com/android/emulator/windows-x64/emulator-35.4.9.zip",
      "sha256": "yyyy",
      "size": 610000000
    }
  ],
  "systemImages": [
    {
      "id": "android-14-google-apis-arm64-r1",
      "apiLevel": 34,
      "androidVersion": "14",
      "variant": "google_apis",
      "arch": "arm64-v8a",
      "url": "https://nas.company.com/android/system-images/android-14/google_apis-arm64-v8a.zip",
      "sha256": "zzzz",
      "size": 4600000000,
      "recommendedFor": ["macos-arm64"]
    },
    {
      "id": "android-14-google-apis-x86_64-r1",
      "apiLevel": 34,
      "androidVersion": "14",
      "variant": "google_apis",
      "arch": "x86_64",
      "url": "https://nas.company.com/android/system-images/android-14/google_apis-x86_64.zip",
      "sha256": "aaaa",
      "size": 4300000000,
      "recommendedFor": ["macos-x64", "windows-x64"]
    }
  ],
  "avdTemplates": [
    {
      "id": "pixel6-api34-standard",
      "name": "Pixel 6 / Android 14 标准测试机",
      "imageId": "android-14-google-apis-arm64-r1",
      "description": "公司标准 Android 14 测试环境",
      "config": {
        "cores": 4,
        "memoryMb": 4096,
        "width": 1080,
        "height": 2400,
        "density": 420,
        "dataPartitionSize": "8G",
        "gpuMode": "auto"
      }
    },
    {
      "id": "low-end-api34",
      "name": "Android 14 低端机配置",
      "imageId": "android-14-google-apis-arm64-r1",
      "description": "低内存、低分辨率性能测试环境",
      "config": {
        "cores": 2,
        "memoryMb": 2048,
        "width": 720,
        "height": 1280,
        "density": 320,
        "dataPartitionSize": "4G",
        "gpuMode": "swiftshader_indirect"
      }
    }
  ],
  "scenarioTemplates": [
    {
      "id": "weak-network-edge",
      "name": "弱网 EDGE + 高延迟",
      "description": "模拟低速网络和较高延迟，用于登录、支付、加载超时类测试",
      "commands": [
        { "type": "network", "speed": "edge", "delayMs": 800 },
        { "type": "power", "capacity": 20, "status": "discharging" }
      ]
    },
    {
      "id": "gps-shanghai",
      "name": "GPS 上海",
      "description": "设置模拟器定位到上海",
      "commands": [
        { "type": "gps", "lon": 121.4737, "lat": 31.2304, "alt": 0 }
      ]
    }
  ]
}
```

### 13.5 平台匹配规则

| 客户端平台 | 推荐 emulator | 推荐 system image |
|------------|---------------|-------------------|
| macOS Apple Silicon | macos-arm64 | arm64-v8a |
| macOS Intel | macos-x64 | x86_64 |
| Windows x64 | windows-x64 | x86_64 |

客户端拉取 manifest 后应自动识别当前平台，只展示或优先推荐兼容资源。

### 13.6 下载与校验流程

```text
1. 拉取 manifest.json
2. 校验 manifest 格式版本
3. 根据当前平台筛选 emulator 引擎和 system image
4. 用户选择 AVD 模板或测试配置
5. 检查本地缓存是否已存在对应版本
6. 如不存在，下载 zip 到 cache/downloads
7. 支持断点续传、进度、速度、剩余时间展示
8. 下载完成后校验 sha256
9. 解压到 engines/ 或 system-images/ 版本目录
10. 根据模板创建 AVD
11. 启动模拟器并记录资源版本信息
```

### 13.7 测试报告建议记录字段

如果后续与 Test Session 集成，建议在报告中记录以下环境信息：

```json
{
  "emulatorEngine": "emulator-macos-arm64-35.4.9",
  "systemImage": "android-14-google-apis-arm64-r1",
  "avdTemplate": "pixel6-api34-standard",
  "scenarioTemplate": "weak-network-edge",
  "runtimeControls": {
    "network": {
      "speed": "edge",
      "delayMs": 800
    },
    "power": {
      "capacity": 20,
      "status": "discharging"
    },
    "gps": {
      "lon": 121.4737,
      "lat": 31.2304
    }
  }
}
```

### 13.8 注意事项

- `manifest.json` 方案适合公司内部测试环境，不建议作为公开发行默认能力
- NAS/内部服务只作为下载源，不建议直接运行其中的 emulator 或 AVD
- 首次下载体积较大，必须支持断点续传、sha256 校验、磁盘空间预检查、失败清理
- Android SDK emulator 和 system image 的内部镜像缓存需要注意公司合规要求，特别是 Play Store 镜像
- 资源版本应保留历史版本，不要覆盖旧目录，保证历史测试报告可复现

---

*最后更新: 2026-06-24*
