# ADB Tool UI 改进方案

> 版本: v1 | 日期: 2026-07-05 | 预计总工时: ~15h

---

## 一、现状评估

### 1.1 优势

| 方面 | 说明 |
|------|------|
| 导航架构 | 侧边栏 + IndexedStack 缓存，多设备切换流畅 |
| 设备仪表盘 | 砖石网格自适应列数、热力色进度条、进程 CPU/MEM 条形图 |
| 录制 Overlay | 跨页面录屏状态浮层 FAB |
| 侧边栏交互 | 可拖拽调整宽度（200-400px）、可折叠至 56px、双击重置宽度、ValueNotifier 优化性能 |
| Material 3 | colorSchemeSeed(blue)、dark/light 双主题 |
| i18n 架构 | 按页面拆分字典文件，中英双语 |

### 1.2 问题清单

| # | 问题 | 严重程度 |
|---|------|----------|
| 1 | 侧边栏导航层级混乱：设备树与全局入口没有视觉分隔 | P0 |
| 2 | 缺少统一设计系统：间距/字号/圆角/卡片样式零散 | P0 |
| 3 | 设备仪表盘缺少摘要信息和时序趋势 | P1 |
| 4 | 缺少键盘快捷方式和命令面板 | P1 |
| 5 | 空状态/加载态体验原始，只有转圈和灰色文字 | P1 |
| 6 | Logcat 日志条目缺少优先级视觉标识 | P2 |
| 7 | 部分组件缺少 Hover/Active 态反馈 | P2 |
| 8 | i18n Key 命名风格混用（平铺 vs 命名空间） | P3 |

---

## 二、实施阶段

### 阶段 1：设计基础设施 ~3h

**目标**: 为后续所有改动建立统一的设计语言，不再使用硬编码数值。

#### 1.1 新建 `lib/design/design_tokens.dart`

```dart
/// 全局间距 Token
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// 全局圆角 Token
class AppRadius {
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const full = 9999.0;
}

/// 全局字号 Token
class AppFontSize {
  static const xs = 10.0;  // badge / caption
  static const sm = 11.0;  // label
  static const md = 12.0;  // body
  static const lg = 14.0;  // subtitle
  static const xl = 16.0;  // title
  static const xxl = 20.0; // headline
  static const metric = 28.0; // 仪表盘数值
}
```

#### 1.2 新建 `lib/design/cards.dart` — 三种卡片变体

- **MetricCard**: 图标 + 标题 + 大数值 + 进度条 + 左侧阈值色带
- **SettingCard**: 图标 + 标题 + 描述 + 操作按钮
- **ActionCard**: 图标 + 标题 + 点击跳转

#### 1.3 主题增强

**修改**: `lib/providers/theme_provider.dart`

- 将 dark/light 双主题定义从 `main.dart` 移到 `theme_provider.dart`，改为静态方法 `ThemeData _buildLightTheme()` / `_buildDarkTheme()`
- 添加 `cardTheme`、`inputDecorationTheme`、`dividerTheme` 等 M3 定制
- 定义 Elevation 语义: bg=0, sidebar=1, card=2, dialog=3

**修改**: `lib/main.dart`

- 删掉内联 `ThemeData`，改用 `themeProvider.lightTheme/darkTheme`

#### 1.4 状态组件

**修改**: `lib/widgets/loading_view.dart` — 加点可选 message 参数

**修改**: `lib/widgets/error_view.dart` — 展开错误详情

**新建**: `lib/widgets/empty_state.dart`

```dart
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
}
```

---

### 阶段 2：侧边栏重构 ~3h

**目标**: 设备树与全局入口视觉分离，加 Section 标题，加键盘导航。

#### 2.1 侧边栏分区

**修改**: `lib/screens/home_screen.dart` — `_buildSidebar()` 方法

布局变更:

```
Before:
┌──────────────────────┐
│ Header (按钮太多)    │
├──────────────────────┤
│ Device A  ▶          │
│ Device B  ▼          │
│   Status / Logcat... │
├──────────────────────┤
│ Test Config / Emu    │
│ Settings / Backend   │
└──────────────────────┘

After:
┌──────────────────────┐
│ Header (精简)        │
├──────────────────────┤
│ DEVICES (2)  ⟳ 📡   │  ← Section 标题 + 操作按钮
├──────────────────────┤
│ ● Pixel 7  ▼         │
│   Status Logcat ...  │
│ ● Mi 12              │
├──────────────────────┤
│ TOOLS                │  ← Section 标题
├──────────────────────┤
│ Test Config          │
│ Emulator Settings    │
│ Settings             │
│ Backend Logs         │
└──────────────────────┘
```

具体改动:
1. Header 瘦身: 只保留标题 + 语言切换 + 折叠按钮 + 主题切换
2. 刷新/无线ADB/重启/关闭 → 移到 Devices Section 标题行右侧的图标按钮
3. Section 标题用 `_buildSectionHeader(title, subtitle, actions)` 实现
4. Devices Section 显示设备数量徽章
5. 分隔线用 `Divider(indent: md, endIndent: md)`

#### 2.2 折叠模式改进

**修改**: `_buildCollapsedSidebar`

设备图标从 `Icons.phone_android` 改为 `CircleAvatar` 显示设备名首字母，保持连接状态圆点。

#### 2.3 键盘快捷键

**修改**: `lib/screens/home_screen.dart` 的 `build()` — 用 `Shortcuts` + `Actions` 包裹 body

| 快捷键 | 功能 |
|--------|------|
| `Cmd/Ctrl+1~9` | 切换到当前设备第 N 个功能页 |
| `Cmd/Ctrl+B` | 切换侧边栏折叠 |
| `Cmd/Ctrl+K` | 命令面板 |
| `Cmd/Ctrl+[/]` | 上一个/下一个设备 |

---

### 阶段 3：设备仪表盘增强 ~3h

**目标**: 增加设备摘要条 + 时序趋势图 + 阈值色标。

#### 3.1 设备摘要栏

**修改**: `lib/screens/device_status_screen.dart` — `_buildDashboard` 上方增加 `_buildSummaryHeader`

```
┌─ 摘要栏 ──────────────────────────────────────────────┐
│ 📱 Pixel 7 Pro    Android 14 (SDK 34)                  │
│ ⏱ 3d 12h   🟢 Health OK   ⚡ Charging                 │
└───────────────────────────────────────────────────────┘
```

**前置**: 确认 `DeviceStatus` 模型是否有 `model`、`androidVersion`、`sdkLevel` 字段。没有的话需要: 后端 `adb_status.go` + 前端 `device_status.dart` 同步添加。

#### 3.2 Sparkline 时序图

**新建**: `lib/widgets/sparkline.dart` — 纯 `CustomPaint` 迷你折线图，不依赖第三方包。

**修改**: 在 `_DeviceStatusScreenState` 内部维护 `List<double> _cpuHistory` / `_memHistory`（最大 30 点），每次 `_loadStatus()` 成功后 push。

#### 3.3 阈值色标

MetricCard 左侧 3px 色带:
- 进度 < 50% → green
- 50%-80% → amber
- > 80% → red (error)

---

### 阶段 4：命令面板 ~3h

**目标**: Cmd/Ctrl+K 弹出搜索框，可模糊搜索设备/功能/设置。

#### 4.1 新建 `lib/widgets/command_palette.dart`

```
┌─ CmdK ─────────────────────────────────┐
│  > scr|                                 │  自动 focus
├────────────────────────────────────────┤
│  Screen Mirror — Pixel 7            ↵  │  键盘上下选择
│  Screen Record — Pixel 7               │
│  Settings — Recording Settings          │
└────────────────────────────────────────┘
  ↑↓ 选择  ↵ 确认  Esc 关闭
```

搜索范围:
- device.serial × NavItem (8 个功能页)
- 全局入口 (Test Config, Emulator, Settings, Backend Logs)
- 快捷操作 (Refresh, Shutdown, Restart)

搜索算法: 全小写子串匹配即可

挂载: `home_screen.dart` 的 `Shortcuts` 中注册 `Cmd+K` → `CommandPalette.show(context)`

---

### 阶段 5：细节打磨 ~3h

#### 5.1 Logcat 优先级 Badge

**修改**: `lib/screens/logcat_screen.dart`

颜色映射: V=grey, D=blue, I=green, W=orange, E=red, F=purple

#### 5.2 空状态迁移

用 `EmptyState` 替换各页面空状态:

| 位置 | 当前代码 |
|------|----------|
| `device_status_screen.dart:136` | 灰色文字 "请先选择设备" |
| `home_screen.dart:514` ('_buildWelcome') | android 图标 + 文字 |
| 其他页面 | 需要排查确认 |

#### 5.3 卡片迁移

用阶段 1 的卡片 Widget 替换各页面现有 Card:

| 文件 | 卡片个数 | 替换为 |
|------|----------|--------|
| `device_status_screen.dart` | 10 | MetricCard |
| `settings_screen.dart` | 2 | SettingCard |
| `emulator_settings_screen.dart` | 4 | SettingCard |

#### 5.4 Hover 态

排查 `InkWell` / `GestureDetector` / `MouseRegion` 的使用，确保所有可交互元素正确显示 cursor 和 hover 背景色。

---

## 三、文件变更总览

| 文件 | 变更 | 阶段 |
|------|------|------|
| `lib/design/design_tokens.dart` | 新建 | 1 |
| `lib/design/cards.dart` | 新建 | 1 |
| `lib/widgets/empty_state.dart` | 新建 | 1 |
| `lib/widgets/sparkline.dart` | 新建 | 3 |
| `lib/widgets/command_palette.dart` | 新建 | 4 |
| `lib/providers/theme_provider.dart` | 修改 | 1 |
| `lib/main.dart` | 修改 | 1 |
| `lib/screens/home_screen.dart` | 修改 | 2, 4 |
| `lib/widgets/loading_view.dart` | 修改 | 1 |
| `lib/widgets/error_view.dart` | 修改 | 1 |
| `lib/screens/device_status_screen.dart` | 修改 | 3, 5 |
| `lib/screens/logcat_screen.dart` | 修改 | 5 |
| `lib/screens/settings_screen.dart` | 修改 | 5 |
| `lib/screens/emulator_settings_screen.dart` | 修改 | 1, 5 |
| `lib/screens/clipboard_screen.dart` | 修改 | 5 |
| `lib/screens/app_manager_screen.dart` | 修改 | 5 |

**不影响**: 后端代码、数据库 schema、API 协议、构建脚本。

---

## 四、验收清单

- [ ] 侧边栏显示 "DEVICES (n)" 和 "TOOLS" 两个 Section 标题
- [ ] 折叠模式设备图标用首字母区分
- [ ] `Cmd/Ctrl+1~9` 可切换功能页
- [ ] `Cmd/Ctrl+B` 可折叠/展开侧边栏
- [ ] 仪表盘顶部有摘要信息栏（型号/版本/运行时间/健康灯）
- [ ] CPU/内存卡片有 30 点 sparkline 趋势图
- [ ] 仪表盘卡片左侧有色标（绿/橙/红）
- [ ] `Cmd/Ctrl+K` 弹出命令面板可搜索
- [ ] Logcat 每行日志前有优先级 Badge
- [ ] 所有交互元素有 Hover 态和 Tooltip
- [ ] 空状态使用统一 `EmptyState` 组件
- [ ] `flutter analyze` 无新增 warning
- [ ] `flutter test` 全部通过
- [ ] 深色/浅色主题均正常

---

## 五、风险

1. **IndexedStack 存活策略**: 过渡动画不能替换 IndexedStack，只能叠加
2. **后端状态字段**: sparkline 依赖更多设备状态，需确认后端 `/api/device-status` 是否已有 `model`、`androidVersion`、`sdkLevel`
3. **快捷键双平台**: macOS = `Meta`, Windows = `Control`
4. **无新第三方依赖**: sparkline 和搜索功能都用手写实现
