# ADB Tool — UI/UX 升级产品逻辑设计

版本：v1（2026-10-02）· 适用分支：`feat/ui-visual-polish`
状态：**待评审的单一事实源**。本文件取代 `docs/UI_IMPROVEMENT_PLAN.md`（后者保留作历史，不再更新）。

配套能力地图（带证据锚点，可在浏览器打开）：`docs/qgraphflow/flutter-ui-usecase/index.html`

---

## 0. 为什么要有这份文档

上一轮升级的做法是"新建一套 `lib/design/`，然后逐页美化"。结果是：设计系统落地 6 个文件、30KB，**只有 DashboardView 一页真的用了它**；`colorScheme` 被读 354 次而 `context.palette` 只被读 22 次；`cards.dart` 333 行和 `AppCard` 156 行是零实例化的死代码。也就是说升级的"体量"上不去，不是因为设计不好看，而是**缺少一份规定"什么必须一致、谁来保证一致"的产品契约**。

所以本文件的重点不是视觉，而是三件事：**能力边界（页面做什么、前置条件是什么）、一致性契约（设计系统三层）、可验证的落地方式（棘轮 + 每页 DoD）**。

### 度量口径（升级是否有效，只看这三个数）

| 指标 | 定义 | 当前值 | 目标 |
|---|---|---|---|
| 设计系统覆盖率 | 引用 `lib/design/` 的 UI 文件数 ÷ UI 文件数 | 17/58 = 29% | 全部工作区页面 ≥ 1 |
| 硬编码样式点 | `scripts/check_design_style.py` 统计的六类数字字面量 | 507 处 / 40 文件 | ≤ 150 |
| 颜色单轨符合度 | `context.palette` 与 `colorScheme` 引用比 | 22 : 354 | 已由桥接统一，禁止新增 seed 派生色 |

前两个数字是**可自动回归的**（见 §9），任何"升级有效"的说法必须能用它们证明。

---

## 1. 产品定位与非目标

**一句话**：给 Android 测试/开发人员的本地桌面调试台——把 USB/WiFi ADB、scrcpy 投屏、日志、文件、视图层级、测试会话记录，收进一个不需要打开终端和 Android Studio 的窗口。

**用户与频次**（决定优先级，来自侧边栏分组 `home_screen.dart:49-65`）：

| 角色 | 分组 | 高频任务 | 低频任务 |
|---|---|---|---|
| 日常调试者 | mainMenu | 看设备状态、装卸 APK、拉文件 | 查设备参数 |
| 测试工程师 | debug + 测试会话 | 抓 logcat、发快捷指令、投屏操作、跑测试会话并记证据 | 无线 ADB 配对 |
| 工具维护者 | advanced | 模拟器引擎/镜像/实例/JDK、后端日志、外观 | — |

**非目标（明确不做，越界即算超范围）**：
- 不做设备集群管理、不做 CI 编排、不做远端多用户协作。
- 不引入 Flutter 之外的 UI 框架、不引入动画/状态第三方大库（现有 `provider` + `drift` 不变）。
- 不为了"看起来现代"重排已验证可用的三分组导航。
- 不在没有触发条件时重构 `AGENTS.md` 列出的胖文件（见 §10）。
- 不做移动端/触屏适配。桌面唯一，最小窗口宽度按 1100px 设计。

---

## 2. 信息架构

```
WindowChrome（自绘标题栏，常驻）
└─ HomeScreen（壳层，唯一路由拥有者）
   ├─ AppSidebar（三分组：mainMenu / debug / advanced）
   └─ 内容区
      ├─ DashboardView          ← 默认页（_activeKey = dashboard）
      ├─ IndexedStack(工作区页) ← 已打开的页面保持挂载，切页不丢状态
      └─ 全局页(不保活)         ← backendLogs / testConfig / emulator
```

**两类页面，规则不同**（这条必须遵守，否则状态语义会冲突）：

| 类型 | 成员 | 生命周期 | 约束 |
|---|---|---|---|
| 工作区页 | status / apps / files / info / logcat / command / clipboard / hierarchy / mirror / session | `IndexedStack` 保活 | 不得在 `dispose` 里丢用户状态；切回即恢复 |
| 全局页 | backendLogs / testConfig / emulator | 进入才创建（`home_screen.dart:67` `_globalKeys`） | 不得假设设备已选中；必须自带"未选设备"引导 |

**决策 D1（待你拍板，推荐先做）**：`DashboardView` 的 `realtimePerformance`（`dashboard_view.dart:935`）与 `connectedDevices`（:1152）两个区块，和 `DeviceStatusScreen` 的目标完全重叠。建议 **DeviceStatusScreen 降级为 Dashboard 的一个可展开 section，并从侧边栏 mainMenu 移除独立入口**（14 个入口 → 13 个）。收益：少一个页面要迁移、消除两处各自演化的实时状态视图。代价：老用户少一个书签。

**决策 D2**：`DeviceInfoScreen` 与 `DeviceStatusScreen` 同样偏"参数罗列"，建议合并为"设备"单页的两个 tab。与 D1 一起做最省。

---

## 3. 能力契约（产品逻辑核心）

每个能力都必须能回答这五行。缺任何一行的页面，视为**未完成**，不接受"先上再说"。

| # | 能力 | 入口 | 前置条件 | 数据源 | 失败态要求 |
|---|---|---|---|---|---|
| 1 | 总览设备并快捷行动 | 侧边栏 dashboard（默认） | 无（无设备时走空态） | `DeviceProvider` + `saved_devices` DAO | 设备离线时 `DisconnectedBanner`；快捷行动禁用并说明原因 |
| 2 | 查看设备实时状态 | D1 后并入 #1 | 设备在线 | `device_provider` 轮询 | CPU/内存取不到 → 显示"—"，不得显示 0 |
| 3 | 管理设备应用 | 侧边栏 apps | 设备在线 + 已选设备 | `app_manager` API | 卸载失败保留列表原状并 toast；APK 拖放失败要区分"文件不是 APK"和"设备拒绝" |
| 4 | 浏览并传输设备文件 | 侧边栏 files | 设备在线 | `file_browser` API | 传输中必须有 `TransferProgressOverlay`，取消必须可中断 |
| 5 | 抓取并过滤运行日志 | 侧边栏 logcat | 设备在线 | `logcat_state` + WS | 后端断连 → `backendOffline` 文案 + 自动重连；过滤正则非法 → 就地校验，不得清空列表 |
| 6 | 执行 ADB 快捷指令 | 侧边栏 command | 设备在线 | `adb_command` API | 单条命令失败不得污染后端健康状态（见 `backendLogsContextHint`） |
| 7 | 检视界面层级结构 | 侧边栏 hierarchy | 设备在线 | `view_hierarchy` API + uiautomator dump | dump 超时须可取消并保留上一次结果 |
| 8 | 镜像并操作设备屏幕 | 侧边栏 mirror | 设备在线 + scrcpy 可解压 | `mirror_state` / `scrcpy_*` | scrcpy 启动失败 → 显示后端原始错误；断流须自动重连一次 |
| 9 | 执行测试会话 | 侧边栏 session → hub → active | 设备在线 + 已选测试 App | `test_session_provider` | 会话中设备离线 → `recordingInterruptedOffline` 并保存已有证据 |
| 10 | 管理模拟器运行环境 | 侧边栏 emulator | 无（本机环境） | 6 个 `emulator_*` provider | JDK/镜像缺失 → 给可执行的修复动作，不只报错 |
| 11 | 切换主题与外观 | 设置对话框外观面板 | 无 | `ThemeProvider` → prefs.json | 见 §6，浅色值由 palette 定义 |

**跨能力硬规则**：
1. **后端可达性是独立状态**，不能等同于"设备离线"。`/healthz` 不可达 → 顶部 banner + 全部需要后端的入口禁用；仅设备离线 → 只禁用设备相关操作，全局页仍可用。
2. **一切破坏性操作**（卸载、清缓存、清空配置、断开设备、关闭服务）走 `SafeDialog` 二次确认，且文案必须说明影响范围。
3. **任何等待都必须能取消**。当前 877→507 处硬编码之外，最容易踩的是不可中断的 `CircularProgressIndicator`。
4. **禁止假数据**。没有活动流就不编造活动行（`_RecentActivity` 现在渲空态，是对的）。

---

## 4. 设计系统契约（三层，每层一条单轨规则）

```
第 1 层 token    AppSpacing / AppRadius / AppFontSize / AppDuration / AppElevation
第 2 层 color    AppPalette（ThemeExtension）→ toColorScheme() → Material
第 3 层 component AppPanel / AppTopbar / AppSectionLabel / AppSidebar / AppBackground / WindowChrome
```

**第 1 层**：尺寸只能来自 token。`check_design_style.py` 的 `fontSize` / `radius` / `insets` / `duration` 四类就是在管这一层。`AppDuration`、`AppElevation` 目前几乎没人用（各 3 处），动画与阴影也一律走 token，不要再写 `Duration(milliseconds: 200)`。

**第 2 层**：**颜色只有一个来源**。屏幕可以读 `colorScheme.X`（已派生自 palette），也可以读 `context.palette.X`，但**禁止**任何新的 `ColorScheme.fromSeed` / `colorSchemeSeed` / `Color(0x...)`。深色值与 Ardot 设计稿 1:1 冻结（`app_palette.dart` 注释已声明不可漂移）；浅色值是本产品的新规范，只准改 `AppPalette.light` 一处。

**第 3 层**：组件契约。

| 组件 | 职责 | 现在被用 | 缺口 |
|---|---|---|---|
| `AppTopbar` | 页面头部（64px，title/subtitle/actions） | 仅 DashboardView | 其余 9 个工作区页各自手写 header |
| `AppPanel` | 唯一内容容器（panel 底 + hairline 边 + radius.lg） | 仅 DashboardView | `settings_dialog.dart:327` 的私有 `_Panel` 是它的复制，先删这个 |
| `AppSectionLabel` | 内容区分节标题（14/w600） | 仅 DashboardView | `scrcpy_settings_panel.dart:342` 的 `_SectionHeader` 重复 |
| `AppNavGroupLabel` | 侧边栏分组标签 | app_sidebar.dart | **应迁入 `lib/design/`**，否则分组标签规则散落两处 |
| `AppStatusBadge` | 状态点 + 文本（在线/离线/设备名） | **不存在** | DashboardView `:166-180` 正在手写这个 dot+name；`test/app_surfaces_test.dart` 曾假定它存在。**这是第一个要补的组件** |
| `AppTopbarIconButton` | 头部图标按钮 + tooltip | **不存在** | 同上，头部操作目前各处自己拼 |

**决策 D3**：组件层优先补 `AppStatusBadge` 与 `AppTopbarIconButton`（两者都有现成手写实现可提炼），再按页面队列迁移，**不要先扩组件库**——先扩只会增加第二套孤岛。

---

## 5. 状态与反馈规范（每页五态）

每个页面必须显式声明并实现这五个态，用现成组件：

| 态 | 用什么 | 规则 |
|---|---|---|
| 未初始化/未选目标 | `EmptyState` + 引导动作 | 全局页必须能独立成立，不假设设备已选 |
| 加载中 | `LoadingView` / `Skeleton` | 列表用骨架，单操作用就地 spinner；全屏遮罩只用于不可取消的启动过程 |
| 空结果 | `EmptyState` | 必须区分"没有数据"与"筛选后没有数据"，后者给清除筛选入口 |
| 错误 | `ErrorView` / toast | 必须区分本地（后端/adb/scrcpy）与设备侧错误；显示原始 stderr 供复制 |
| 离线 | `OfflineGuard` / `DisconnectedBanner` | 禁用而非隐藏入口，并写明恢复条件 |

## 6. 主题与无障碍

- 对比度门槛：正文 ≥ 4.5:1，大号文本/图标 ≥ 3:1。已由 `app_palette_color_scheme_test.dart` 锁住 `onAccent`；新增语义色必须补等价断言。
- 最小字号 9px（`AppFontSize.xs`）只允许用于徽章与图例，正文不得小于 `AppFontSize.body` = 12。
- 深浅两套都必须走查：`AppBackground` 的辉光是全局层，浅色下面板故意半透明（`panel = 0xE6FBFCFE`）以让辉光透出。**约束**：对话框、菜单、弹层不得继承半透明 surface；若出现透底可读性问题，给 overlay 单独取不透明色，不得回退 palette。
- Windows 字体固定 `Microsoft YaHei`，macOS 走系统字体；等宽场景显式声明 `Noto Sans Mono`。

## 7. 桌面交互规范

| 交互 | 规则 | 现状 |
|---|---|---|
| 命令面板 | `Ctrl/Cmd+K`，条目来自导航目标 × 已保存设备 | `home_screen.dart:484/761`，已实现 |
| 数字键切页 | `Ctrl/Cmd+1..9` 映射侧边栏可见项 | `home_screen.dart:88-98`，已实现；D1 删项后必须同步 |
| 拖放 | APK/文件拖入相应页面 | 平台层 `mac_drop` / `win_drop`；失败原因要分类 |
| Hover | 桌面必须有 hover 反馈，用 `AppElevation` 而非改色 | Dashboard 已有，其余页面缺失 |
| 录屏 | `RecordingFab` + 计时来自 `_ElapsedLabel` | 定时器必须在 dispose 取消（已发生过测试挂起） |
| 右键 | 文件列表、层级树必须给上下文菜单 | `file_sheet_actions.dart` 已有，未覆盖 hierarchy |

## 8. i18n 与文案

- 所有面向用户的字符串走 `tr()`，中英文字典按页分文件。分组标签此前硬编码中文，已修（`a75c674`）。
- **禁止**用 `tr(someVariable)` 传动态 key——`check_i18n_tr_keys.py` 只扫字面量，动态查查看不见缺key。例外必须集中声明（侧边栏分组是现有唯一例外，已在中英双表补 key）。
- 文案分工：错误文案说"发生了什么 + 下一步"；hint 说前置条件；按钮动词用祈使（"导出配置"，不用"配置导出"）。

---

## 9. 迁移路线（可执行，按 PR 切）

**已完成（本分支 `020d091..84ab8fc`）**：颜色单轨、死代码清除、样式棘轮 + CI 护栏、侧边栏 i18n、两处真实缺陷（对比度、设备行溢出）。

**P1：按页迁移队列**（排序依据 = 收益确定性 × 使用频率；硬编码点数只作规模参考，不是排序键）：

| 顺序 | 目标 | 硬编码点 | 动作 |
|---|---|---|---|
| 1 | `widgets/settings_dialog.dart` | 13 | 私有 `_Panel` → `AppPanel`；3 处 `Color(0x)` → palette |
| 2 | `widgets/emulator_engine_card.dart` | 58 | header/section → `AppTopbar`/`AppSectionLabel`；字号与圆角走 token |
| 3 | `screens/logcat_screen.dart` | 44 | header + 工具条 → 组件；字号 |
| 4 | `screens/test_session/test_session_hub_screen.dart` | 29 | `_StartCard`/`_HistoryPanel`/`_SessionPreviewPanel` → `AppPanel` |
| 5 | `screens/app_manager_screen.dart` | 33 | 同上 |
| 6 | 其余工作区页 | 各 <30 | 每页一个 PR |

**每页 DoD（验收即这五条，缺一不算完成）**：
1. 头部用 `AppTopbar`，分节用 `AppSectionLabel`，容器用 `AppPanel`。
2. 该页 `check_design_style.py` 计数下降，且基线用 `--update` 收紧。
3. 五态齐全（§5），并能在断开后端/拔设备两种故障注入下走通。
4. 字符串全部 `tr()`，`check_i18n_tr_keys.py` 通过。
5. 深浅两主题人工走查一次（截图附在 PR），对比度不破。

**P2：结构性收敛**（只在 P1 覆盖过半后启动）：D1/D2 页面合并；`AppNavGroupLabel` 迁入 design 层；`widgets/` 业务卡片群与 `design/` 的边界规则写进 `AGENTS.md`。

---

## 10. 护栏与回归

- **棘轮**：`python scripts/check_design_style.py`（超基线即失败）+ `check_i18n_tr_keys.py`，由 `.github/workflows/ui-guardrails.yml` 在 push/PR 执行。降低基线只能走 `--update`，即**每次改善都要留下证据**。
- **测试卫生**：widget 测试里对 drift 的真实异步必须包在 `tester.runAsync()`；测试体结束时先 `pumpWidget(SizedBox())` 再 `pump()` 冲刷清理定时器，否则 `flutter test` 会失败并挂住不退出（`c44e8aa` 有完整说明）。
- **功能回归防线（重要）**：`32f094f` 把测试配置从 JSON 迁到 drift 时，**丢掉了 `de407a3` 刻意实现的"按 packageName 合并导入"逻辑**，导致重复导入变成追加副本、当前选择丢失。教训写进规则：**迁移底层存储时必须逐分支翻译旧实现，并在 PR 里列出旧新分支对照表**；纯重写不接受。

---

## 11. 待你确认的决策

| 编号 | 内容 | 推荐 | 影响面 |
|---|---|---|---|
| D1 | `DeviceStatusScreen` 并入 Dashboard section，侧边栏减一项 | 做 | 导航 + 1 页迁移工作量 |
| D2 | `DeviceInfoScreen` 与设备状态合并为双 tab | 做（与 D1 同批） | 同上 |
| D3 | 组件层先只补 `AppStatusBadge` / `AppTopbarIconButton` | 做 | design 层 +2 文件 |
| D4 | 是否先修 §10 的导入合并回归再启动 P1 | 先修（它是产品缺陷，不是 UI 债） | provider + 2 测试 |
| D5 | `.gitignore` 的 `.*/` 是否加 `!.github/` | 加，否则新 workflow 需持续 force-add | 1 行 |
