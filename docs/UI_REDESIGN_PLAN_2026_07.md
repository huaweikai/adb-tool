# ADB Tool UI 重构方案（新设计稿落地）

> 版本: v1 | 日期: 2026-07-23 | 设计稿: Ardot 主文件 `706601156104862`
> 数据来源: 13 屏主稿 Page 1 骨架 + Sidebar 主件 34:52 完整结构 + 17:3(已连接设备) 完整屏视觉

---

## 一、调研发现

### 1.1 13 屏主稿统一骨架（每屏）

每屏都是一个 `FRAME` (HORIZONTAL, 1423×923) 容器，固定三层结构：

| 层 | 节点类型 | 规格 | 说明 |
|---|---|---|---|
| 背景光晕 | FRAME (NONE) | 1354×911, 溢出 -12,- | 绿色径向渐变 `GRADIENT_RADIAL` `#3DDC84` alpha 0.14→0 |
| Sidebar | INSTANCE / COMPONENT | 240×923 | 13 屏中 12 屏用 INSTANCE 引用主件 `34:52`；仅文件浏览器屏 `34:48` 内是主件本体 |
| 主内容区 | FRAME (VERTICAL, gap 44) | 1183×923 | Topbar (64 高) + 主容器 (815 高) |

### 1.2 Sidebar 主件 `34:52` 完整结构（最重要）

**容器**: 240×923, VERTICAL, gap 6, fill `#0E1118` (rgb 0.055,0.067,0.094), stroke `#1E2430` (rgb 0.118,0.141,0.188), counterAxisAlignItems MIN

**子节点**（从上到下）：

| # | 节点 | 类型 | 尺寸 | 说明 |
|---|---|---|---|---|
| 1 | Logo | FRAME HORIZONTAL gap 10 | 212×44 | 26×26 绿色矢量图标 + "ADB Tool" (Inter Bold 17, #F2F5F8) |
| 2 | **Device Switcher** | FRAME HORIZONTAL gap 12, cornerRadius 10, fill `#161B24`, stroke `#1E2430` | 212×60 | 设备头像(36×36+绿点) + 设备名/状态 + 下拉箭头 |
| 3 | 组标签"主菜单" | TEXT | 33×16 | Noto Sans SC Regular 11, fill `#5B6472` |
| 4-8 | Nav × 5（主菜单） | FRAME 212×40, gap 12, cornerRadius 8 | 仪表盘/设备信息/实时性能/文件浏览/应用管理 |
| 9 | 组标签"调试工具" | TEXT | 44×16 | 同上 |
| 10-14 | Nav × 5（调试） | 同上 | Logcat/投屏控制/剪贴板/无线调试/ADB 指令 |
| 15 | 组标签"高级" | TEXT | 22×16 | 同上 |
| 16-18 | Nav × 3（高级） | 同上 | 测试会话/设置/后端日志 |
| 19 | Spacer | FRAME | 212×81, layoutGrow 1 | 弹性占位 |
| 20 | Footer | FRAME HORIZONTAL gap 8, cornerRadius 8 | 212×20 | 8×8 绿点 + "本地后端 · 在线" (Noto Sans SC Regular 12, #9AA4B2) |

**导航项统一规范**（212×40, gap 12, cornerRadius 8）：
- 默认态：fill `#0E1118`（和 Sidebar 同色，看不出底）, icon stroke `#9AA4B2`, label fill `#9AA4B2`
- 激活态：fill `#162031`, icon stroke `#3DDC84`, label fill `#3DDC84`
- icon 容器 18×18，左 padding 12，label x=42，fontSize 14（中文 Noto Sans SC Regular, 英文 Inter Medium）

### 1.3 完整屏视觉（17:3 已连接设备屏）

| 区域 | 内容 |
|---|---|
| Topbar | 左：标题"仪表盘"（Inter SemiBold ~22）· 右：搜索框（Cmd+K 占位"搜索设备、指令、文件..."）+ 在线徽章 + 后端绿点 + 主题按钮 + 中按钮 |
| 设备摘要卡 | 大圆角卡（#0E1118）· 设备名 "Pixel 8 Pro" + Android 14·1A283C4D · 4 小指标（电量 86% / CPU 23% / 内存 4.2/8GB / 存储 128/256GB）· 在线徽章 + 开启投屏（绿） + 实时截图（暗） |
| 快捷操作 | 标题 + "常用调试任务" + "查看全部→"绿链接 · 2×3 网格 6 个彩色图标卡（录屏红/投屏绿/截图蓝/安装蓝/无线紫/剪贴板黄） |
| 已连接设备 | 标题"已连接设备 2" · 设备列表（绿点+名+serial+状态徽章）· 底部"扫描设备"按钮 |
| 实时性能 | 标题+ "实时"徽章 + "Pixel 8 Pro · CPU/内存" · 折线图（绿+青双线，深色背景，网格线）· 图例 + 副文 |
| 最近活动 | 标题 + "查看全部" · 4 条活动（彩色点 + 文字 + 时间） |

### 1.4 ⚠️ 设计债（验证存在）

**Sidebar 双亮 bug** —— 当前 17:3（已连接设备/仪表盘屏）截图里：
- "仪表盘" 绿底+绿字（当前屏正确激活）
- "文件浏览" 也绿底+绿字（**这是错的**，不在当前屏）

**根因**：master `34:52` 把 "文件浏览" 设为默认 active（fill `#162031`、icon/label `#3DDC84`）。文件浏览器屏 `34:48` 靠这个默认显示 active。但其他屏没显式 deactive，导致双亮。

**修法**：master 改回中性默认（在每屏的 Sidebar instance 上显式设置 active nav id，通过 componentProperty 或实例 override）。

---

## 二、现有 Flutter 代码对照

### 2.1 已有（可复用 / 需改造）

| 文件 | 现状 | 对照新设计稿 |
|---|---|---|
| `lib/design/design_tokens.dart` | AppSpacing/AppRadius/AppFontSize/AppDuration/AppElevation | ✅ 复用。但**缺颜色 token** —— 现有代码直接用 hex，需要新增 `AppColors` |
| `lib/design/cards.dart` | MetricCard / SettingCard / ActionCard | ⚠️ 改造。MetricCard 对应"统计小卡"但新版用 4 列 grid + 大数字，结构差异大；需新增 `StatTile` 或大改 MetricCard |
| `lib/widgets/empty_state.dart` | EmptyState | ✅ 复用（对应"未连接设备"空状态） |
| `lib/widgets/skeleton.dart` | Skeleton/SkeletonList | ✅ 复用 |
| `lib/widgets/info_row.dart` | InfoRow | ✅ 复用（详情/对话框） |
| `lib/widgets/loading_view.dart` | LoadingView | ✅ 复用 |
| `lib/widgets/error_view.dart` | ErrorView | ✅ 复用 |
| `lib/widgets/sparkline.dart` | Sparkline | ✅ 复用（对应实时性能折线图） |
| `lib/widgets/command_palette.dart` | CommandPalette | ✅ 复用（对应 Topbar Cmd+K 搜索框） |
| `lib/widgets/disconnected_banner.dart` | DisconnectedBanner | ⚠️ 改造（新版用"未连接设备"hero 整屏而非 banner） |

### 2.2 缺（需新增）

| # | 控件 | 对应设计稿节点 | 优先级 |
|---|---|---|---|
| 1 | `AppColors`（颜色 token） | 整套深色主题色 | **P0** |
| 2 | `AppSidebar`（主件） | 34:52 | **P0** |
| 3 | `AppDeviceSwitcher`（子件） | 61:1 | **P0** |
| 4 | `AppNavItem`（子件） | Nav × 13 | **P0** |
| 5 | `AppNavGroupLabel`（子件） | 组标签 × 3 | **P0** |
| 6 | **修复 Sidebar 双亮 bug** | master 改造 | **P0** |
| 7 | `AppTopbar`（主件） | 17:3/Topbar | P1 |
| 8 | `AppCard`（基础件） | 统一 Card 样式 cornerRadius 12 + #0E1118 | P1 |
| 9 | `AppBackground`（背景光晕） | 每屏背景光晕 | P1 |
| 10 | `AppStatTile`（统计小卡） | 设备摘要里的 4 个小指标 | P2 |
| 11 | `AppQuickActionCard`（快捷卡） | 6 个彩色图标卡 | P2 |
| 12 | `AppPrimaryButton` / `AppGhostButton` | "开启投屏"绿按钮 / "实时截图"暗按钮 | P2 |
| 13 | `AppStatusDot`（状态点） | Footer 绿点 / 已连接设备绿点 | P3 |
| 14 | `AppPageTitle`（页面标题） | Topbar 左侧大标题 | P3 |

---

## 三、实施顺序（建议）

### Phase 1 — 基础设施 + Sidebar（P0，约 6h）
1. 新增 `AppColors`（design_tokens 扩展，集中管理 12 个颜色）
2. 新增 `AppSidebar` 主件 + `AppDeviceSwitcher` + `AppNavItem` + `AppNavGroupLabel`
3. **修复 Sidebar 双亮 bug**（master 不再默认 active，靠实例显式设置）
4. 把 home_screen 切到新版 Sidebar，验证 13 屏

### Phase 2 — Topbar + Card + 背景（P1，约 4h）
1. 新增 `AppTopbar`（含 Cmd+K 命令面板接入）
2. 新增 `AppCard`（基础件）
3. 新增 `AppBackground`（背景光晕）
4. 在 home_screen 接入

### Phase 3 — 页面内组件（P2/P3，约 4h）
1. `AppStatTile` / `AppQuickActionCard` / 按钮样式 / 状态点
2. 改造设备状态屏（仪表盘）用新版组件
3. 改造其他屏

---

## 四、风险与注意事项

1. **IndexedStack 存活策略**：home_screen 用 IndexedStack 缓存页面，Sidebar 改造需保持 Navigator 不被重建
2. **状态管理**：Sidebar 的 active nav id 需要在 home_screen state 持有，传递到 AppSidebar
3. **i18n**：13 屏侧栏文字（设备名/状态/组标签/Nav 文字）需走 i18n 字典（`lib/i18n/sidebar.dart` 已存在）
4. **设备切换器交互**：下拉菜单（"已连接" vs "未连接"两个状态组件 `61:12` 和 `63:1`）— 已有 master，AppDeviceSwitcher 需支持两种状态切换
5. **设计系统漂移**：新增 `AppColors` 后，旧代码里的硬编码 hex 要分批替换（不要一次性全替换，按页推进）
6. **MCP 工具间歇抽风**：batch_read/capture_screenshot 间歇拒 array 参数，深读时遇到要重试或换工具

---

## 五、验证清单

- [ ] `AppColors` 集中管理颜色，无散落 hex
- [ ] Sidebar 在 13 屏只亮一个 nav（无双亮）
- [ ] 设备切换器支持已连接/未连接两种状态
- [ ] Topbar Cmd+K 可呼出命令面板
- [ ] 实时性能折线图用新版 sparkline
- [ ] 背景光晕在 13 屏统一
- [ ] `flutter analyze` 无新增 warning
- [ ] `flutter test` 全部通过
- [ ] 深色/浅色主题均正常（注意：当前设计稿是深色专用，浅色可能是另一种 token 体系）
