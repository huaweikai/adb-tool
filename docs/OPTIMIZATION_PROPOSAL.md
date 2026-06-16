# 设备断联 / 状态丢失 — 优化方案

> 范围：解决测试同事日常遇到的高频痛点 —— **设备断联 / 应用重启 / 后端重启时，前端状态全部丢失，tab 回到 welcome 页，正在进行的 session 无法续接**。
>
> 状态：待评审。未改任何代码。
>
> 作者：Mavis · 日期：2026-06-17

---

## 1. 根因分析

整条触发链路上有 4 个串联的坑点，按触发顺序列出：

### 1.1 后端无设备状态缓存
**位置**：`backend/internal/server/adb_devices.go:17-42`

```go
func (m *AdbManager) DevicesContext(ctx context.Context) ([]Device, error) {
    // ...
    out, err := m.runRawContext(listCtx, "devices", "-l")
    // ...
}
```

每次调用都直接跑 `adb devices -l`，**没有内存缓存、没有"最近一次已知状态"**。

**后果**：设备 USB 抖动 1 秒 → 后续 `/api/devices` 立刻查不到 → Flutter 端以为设备没了。

### 1.2 DeviceProvider 一报错就把 activeSerial 置空
**位置**：`flutter_app/lib/providers/device_provider.dart:66-71`

```dart
void _markOffline() {
  _online = false;
  _devices = [];
  _activeSerial = null;  // ← 元凶之一
  notifyListeners();
}
```

`_refresh()` 内部把 DioException / 后端 / 网络任何错误都归为"backend offline"。

**后果**：网络抖一下、API 卡一下，`_activeSerial` 立刻变 null。

### 1.3 HomeScreen 看到 activeSerial 没了就立刻 prune
**位置**：`flutter_app/lib/screens/home_screen.dart:220-243`

```dart
void _schedulePruneDisconnectedScreens(List<Device> devices) {
  final onlineSerials = devices
      .where((device) => device.isOnline)
      .map((device) => device.serial)
      .toSet();
  final removedSerials = _screens.values
      .map((screen) => screen.serial)
      .whereType<String>()
      .where((serial) => !onlineSerials.contains(serial))  // ← 元凶之二
      .toSet();
  if (removedSerials.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    setState(() {
      _screens.removeWhere((_, screen) =>
          screen.serial != null && removedSerials.contains(screen.serial));
      _expandedSerials.removeWhere(removedSerials.contains);
      if (_activeKey != null && !_screens.containsKey(_activeKey)) {
        _activeKey = null;  // ← 直接把当前 tab 抹掉
      }
    });
  });
}
```

`isOnline` 判定只看 `state == 'device'`，无法区分"短暂掉线"和"真离线"。

**后果**：1 秒抖动 → tab 屏幕从 `_screens` Map 里被删掉 → `_activeKey` 变 null → 渲染 `_buildContent` 走 fallback 的 welcome 页。

### 1.4 所有 UI state 纯内存，无持久化
**位置**：
- `flutter_app/lib/screens/home_screen.dart:79` — `String? _activeKey;`（无默认值加载）
- `flutter_app/lib/screens/home_screen.dart:77` — `final Set<String> _expandedSerials = {};`（无持久化）
- `flutter_app/lib/providers/device_provider.dart:20` — `String? _activeSerial;`（无持久化）
- `flutter_app/lib/providers/test_session_provider.dart` — 会话在内存中持有 running state，崩溃后无任何 hint

**后果**：Flutter 进程崩溃 / 用户主动退出 / 后端重启 / 电脑睡眠唤醒 → 所有"我刚才选中哪台设备、在哪个 tab、session 跑到哪一步"全部归零。

### 1.5 Logcat WebSocket 无重连（次要根因）
**位置**：`flutter_app/lib/services/log_stream.dart:65-72`

```dart
onError: (e) {
  _controller.addError(e);
  _connectionController.add(false);  // ← 一报错就停
},
onDone: () {
  _connectionController.add(false);  // ← 一断开就停
},
```

**后果**：设备短暂掉线时 logcat 也会断，必须用户手动重连（即使 tab 状态保住了，logcat 流也是死的）。

### 触发链路示意

```
[USB 抖动 1 秒]
      ↓
[后端 adb devices 查不到]
      ↓
[Flutter DeviceProvider._markOffline()  → _activeSerial = null]
      ↓
[DeviceProvider 通知 listeners]
      ↓
[HomeScreen._schedulePruneDisconnectedScreens()  → _screens.removeWhere + _activeKey = null]
      ↓
[_buildContent 走 welcome fallback]
      ↓
[Logcat WebSocket 同步 onDone  → logcat 流死]
      ↓
[用户在测试中途丢掉了 100% 状态]
```

---

## 2. 方案分级

按"投入 / 收益"分三档。**A 是建议先做的**，B 是治本，C 是锦上添花。

### A. 最小修复（半天到 1 天）— 治标，解决 80% 痛苦

只动前端，不改后端。目标是：**设备短暂掉线不丢 tab、应用重启不丢 activeSerial。**

#### A.1 DeviceProvider：区分"backend 离线"和"设备短暂掉线"

**改动文件**：`flutter_app/lib/providers/device_provider.dart`

具体动作：
- `_refresh` 失败时**只清空 `_devices` 和 `_activeSerial` 当且 `!_online` 持续超过 N 秒**（如 10 秒）。期间保留 `_activeSerial`。
- 引入"软状态"：设备从 `devices` 列表消失时不立即 prune，等连续 K 次（K=3，对应 15 秒）刷新都查不到再 prune。
- `notifyListeners` 频率：5 秒轮询一次不变，但 UI 层渲染时自己看时间戳判断。

伪代码：

```dart
DateTime? _lastSuccessfulRefresh;
String? _activeSerialSnapshot;  // 最后一次看到 activeSerial 在 devices 里的时间
static const _gracePeriod = Duration(seconds: 15);

void _markOffline() {
  _online = false;
  // 不再清空 _devices 和 _activeSerial
  // 让 UI 层根据 _lastSuccessfulRefresh 自己判断
  notifyListeners();
}

Future<void> _refresh(ApiClient api) async {
  try {
    if (!await api.isReady()) {
      _markOffline();
      return;
    }
    final devices = await api.getDevices();
    _devices = devices;
    _online = true;
    _lastSuccessfulRefresh = DateTime.now();
    if (_activeSerial != null && devices.any((d) => d.serial == _activeSerial)) {
      _activeSerialSnapshot = _activeSerial;  // 重新确认
    }
    notifyListeners();
  } catch (_) {
    _markOffline();
  }
}
```

#### A.2 HomeScreen：保留 disconnected 设备的屏幕

**改动文件**：`flutter_app/lib/screens/home_screen.dart`

具体动作：
- 引入 `Set<String> _disconnectedSerials = {}`。
- `_schedulePruneDisconnectedScreens` 改成：发现设备从 devices 消失时，**先把它从侧边栏标灰（"刚刚断开 15s 前还在"）**，超过 grace period 才真的 prune。
- 给 _buildContent 加 fallback：`_activeKey` 对应的 screen 被 prune 时，**渲染一个 "设备 X 已断开，3 秒后自动重试" 的占位页**（带手动 "重试设备" 按钮），而不是直接回 welcome。

伪代码：

```dart
Widget _buildContent() {
  if (_activeKey == null) {
    return _buildWelcome();
  }
  final screen = _screens[_activeKey];
  if (screen == null) {
    return _buildWelcome();
  }
  // 新增：如果 activeSerial 对应设备已掉线
  if (screen.serial != null && _disconnectedSerials.contains(screen.serial)) {
    return _buildDeviceReconnecting(screen.serial!);
  }
  return /* 正常渲染 */;
}

Widget _buildDeviceReconnecting(String serial) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.usb_off, size: 48),
        Text('设备 $serial 已断开，正在自动重试…'),
        FilledButton(onPressed: () => dp.refresh(api), child: Text('立即重试')),
        TextButton(onPressed: () => _pruneSerialNow(serial), child: Text('放弃并返回')),
      ],
    ),
  );
}
```

#### A.3 DeviceProvider 持久化 _activeSerial

**改动文件**：`flutter_app/lib/providers/device_provider.dart` + 新增 `lib/services/prefs.dart`

引入 `shared_preferences`（已经在 pubspec 里检查，可能没装，没装就加）。把 `_activeSerial` 落地到 `adb_tool.active_serial` key。

伪代码：

```dart
class DeviceProvider extends ChangeNotifier {
  static const _kActiveSerial = 'adb_tool.active_serial';
  final SharedPreferences _prefs;
  String? _activeSerial;

  DeviceProvider(this._prefs) {
    _activeSerial = _prefs.getString(_kActiveSerial);
  }

  void select(String? serial) {
    if (_activeSerial == serial) return;
    _activeSerial = serial;
    if (serial == null) {
      _prefs.remove(_kActiveSerial);
    } else {
      _prefs.setString(_kActiveSerial, serial);
    }
    notifyListeners();
  }
}
```

#### A.4 HomeScreen 持久化 _activeKey + _expandedSerials

**改动文件**：`flutter_app/lib/screens/home_screen.dart`

类似 A.3，启动时 `initState` 异步加载，恢复上次 activeKey 和 expandedSerials。

#### A.5 Logcat WebSocket 加自动重连

**改动文件**：`flutter_app/lib/services/log_stream.dart`

伪代码：

```dart
Timer? _reconnectTimer;
int _reconnectAttempt = 0;
static const _maxBackoff = Duration(seconds: 30);

void _scheduleReconnect() {
  _reconnectAttempt++;
  final delay = Duration(
    seconds: min(30, 1 << min(_reconnectAttempt, 5)),  // 2/4/8/16/30s
  );
  _reconnectTimer?.cancel();
  _reconnectTimer = Timer(delay, () {
    if (_serial.isNotEmpty) connect(_serial, _filter ?? LogFilter());
  });
}

// 在 onError / onDone 里调 _scheduleReconnect()
```

**A 档总工作量估算**：
- A.1 + A.2：3-4 小时（核心逻辑，但要小心 UI 状态机不要搞乱）
- A.3 + A.4：2-3 小时（持久化 + 启动恢复）
- A.5：1-2 小时
- 测试 + 自测：半天

**总：1-1.5 天**。

---

### B. 完整方案（2-3 天）— 治本，含"session 进程崩溃后能续接"

在 A 基础上加：后端软状态缓存 + session 续接。

#### B.1 后端加设备状态缓存（可选，但强烈建议）

**改动文件**：`backend/internal/server/adb_devices.go`

具体动作：
- 在 `AdbManager` 里加 `lastKnownDevices map[string]Device` + `lastSeenAt map[string]time.Time`。
- 每次成功 `DevicesContext` 后更新缓存。
- 增加 `/api/devices?include_recent=true` 参数，返回当前在线 + 最近 5 分钟内见过的设备。
- 这让前端在设备短暂掉线时仍能查到 "last seen at 12:34:56, state: device"。

**好处**：前端不用瞎猜"设备是不是真没了"，直接看后端时间戳。

#### B.2 TestSessionProvider 支持 "resume" 模式

**改动文件**：`flutter_app/lib/providers/test_session_provider.dart`

现状：`startSession` 内存里持有 `_currentSession`，崩溃即丢。

具体动作：
- `startSession` 时立即把 session 元数据（id, name, type, serial, model, packageName, startedAt）落到 `ADBToolData/sessions/<id>/session.json`，**这一步当前代码已经做了**（`_persist()`）。但 `_currentSession` 这个内存引用没恢复。
- 加 `Future<TestSession?> resumeRunningSession()`：启动时扫描 `ADBToolData/sessions/` 找到 status=running 的，**自动 load 进来作为 `_currentSession`**。
- 启动时自动调一次，并 notifyListeners，UI 自动跳到 TestSessionScreen。

伪代码：

```dart
class TestSessionProvider extends ChangeNotifier {
  TestSessionProvider({this.baseDirectory, ...}) {
    _tryResume();
  }

  Future<void> _tryResume() async {
    if (_currentSession != null) return;
    final running = await scanHistory();
    final ongoing = running.where((s) => s.status == TestSessionStatus.running).toList();
    if (ongoing.isEmpty) return;
    if (ongoing.length == 1) {
      _currentSession = ongoing.first;
      notifyListeners();
    } else {
      // 多个 running session：弹个选择 dialog 让用户挑
      _pendingResumeList = ongoing;
      notifyListeners();
    }
  }
}
```

#### B.3 后端日志落盘

**改动文件**：`backend/internal/server/backend_logger.go`

具体动作：
- 当前 500 条内存环形 buffer 保留（API 实时拉不变）。
- 同步写一份到 `~/Library/Application Support/ADBTool/backend.log`（mac）或 `%APPDATA%\ADBTool\backend.log`（win），**最大 50MB 自动 rotate**。
- 后端启动时记录 rotate 启动事件。
- `/api/backend-logs` 加 `?file_tail=N` 参数返回磁盘文件末尾 N 行。

**好处**：测试同事能回头追 30 分钟前那次失败。

---

### C. 增强（按需）

#### C.1 测试 session 开始前设备预检
**位置**：`test_session_screen.dart:_showCreateDialog`

session 创建时调几个后端 API：
- `/api/clipboard-check?serial=xxx` → helper 是否安装
- `adb devices -l` → 设备 state
- `adb shell getprop ro.build.version.sdk` → SDK 版本
- 设备存储空间、电池电量

弹个"预检报告"，有问题阻断或警告。

#### C.2 测试步骤耗时统计
**位置**：`test_session_provider.dart:updateTestPlanItem`

在 `TestSessionPlanItem` 加 `duration` 字段，记录步骤开始/结束时间差。`finishSession` 写进 `report.md`。

#### C.3 危险命令黑名单
**位置**：`backend/internal/server/server.go:handleAdbExec`

`adb shell` 后如果是 `rm -rf`、`reboot`、`pm uninstall` 等关键字，强制要 query 参数 `?confirm=true` 才执行。

#### C.4 多设备并行 session
不推荐，复杂度太高，性价比低。先不动。

---

## 3. 推荐实施顺序

按"高频痛点优先、改动局部、风险可控"：

| 顺序 | 内容 | 工作量 | 优先级 | 风险 |
|---|---|---|---|---|
| 1 | A.5 Logcat 重连 | 0.5 天 | 🔴 最高 | 极低 |
| 2 | A.1+A.2 软状态 + 占位页 | 1 天 | 🔴 最高 | 中（要小心 UI 状态机） |
| 3 | A.3+A.4 持久化 activeSerial / activeKey | 0.5 天 | 🟠 高 | 低 |
| 4 | B.2 session 续接 | 1 天 | 🟠 高 | 中 |
| 5 | B.1 后端设备缓存 | 0.5 天 | 🟡 中 | 低 |
| 6 | B.3 后端日志落盘 | 0.5 天 | 🟡 中 | 低 |
| 7 | C.1 预检 | 1 天 | 🟢 低 | 低 |
| 8 | C.2 步骤耗时 | 0.5 天 | 🟢 低 | 极低 |
| 9 | C.3 危险命令 | 0.5 天 | 🟢 低 | 中（要列名单） |

**建议**：A 全部（2-3 天工作量）一次做完再上 beta，B 后续迭代。

---

## 4. 验收标准（A 档）

| 场景 | 期望行为 |
|---|---|
| 测试中途 USB 抖动 1-2 秒 | tab 屏幕不消失，logcat 自动重连 |
| 测试中途 USB 断开 30 秒再插回 | tab 屏幕保留，设备回来后自动恢复 |
| Flutter 进程崩溃后用户重开 | 上次的 activeSerial + activeKey + expandedSerials 全部恢复 |
| 后端重启 | Flutter 自动重连后 tab 屏幕保留 |
| 设备永久拔走（30 秒不回） | 设备从侧边栏消失，对应 tab 屏幕显示"设备已断开"占位页，提供"放弃"和"立即重试" |

---

## 5. 不在本方案范围内

- 后端 CI 跑单测（独立项，#2.2 的补强）
- Flutter 端单测（独立项，#2.3 的补强）
- 拆 test_session_screen / file_browser_screen 上帝文件（独立项 #5）
- i18n 拆分 + CI 校验（独立项 #5.3）

这些虽然重要，但和"设备断联"是平行问题，分开做更清爽。

---

## 6. 附录：相关文件路径速查

**后端**
- `backend/internal/server/adb_devices.go` — 设备列表
- `backend/internal/server/adb_exec.go` — adb exec 封装
- `backend/internal/server/backend_logger.go` — 日志 buffer
- `backend/main.go` — 启动入口

**前端 - 状态/数据**
- `flutter_app/lib/providers/device_provider.dart` — 设备状态
- `flutter_app/lib/providers/test_session_provider.dart` — session 状态
- `flutter_app/lib/services/api_client.dart` — REST 客户端

**前端 - UI**
- `flutter_app/lib/screens/home_screen.dart` — 主框架 + sidebar
- `flutter_app/lib/screens/test_session_screen.dart` — session UI
- `flutter_app/lib/services/log_stream.dart` — WebSocket logcat
- `flutter_app/lib/main.dart` — 入口 + ServerBootScreen

**CI / 构建**
- `.github/workflows/release.yml` — 当前只跑 tag 构建
