# Device identity / transport 代码审查记录

## 背景

本次审查针对当前工作区中关于“稳定设备身份 stable serial”和“ADB transport address”拆分的改动。核心目标是：

- `SavedDevice.serial` / `DeviceSerialScope.serial` / session key 使用稳定身份，通常是 `ro.serialno`。
- 后端执行 adb 命令时才解析到当前在线 transport，例如 USB adb serial 或无线 `ip:port`。
- 无线 ADB 端口变化时不应创建重复设备。
- USB 和 Wi-Fi 同时在线时，应作为同一台物理设备处理，并在需要执行普通 adb 命令时默认优先 USB。
- 断开无线连接这类操作需要明确使用 Wi-Fi transport，而不是默认首选 transport。

本文档是给后续 AI / 人工 review 的审查记录，优先列出可能导致功能回归的问题。

## 当前审查结论

整体方向正确，尤其是以下部分：

- `DeviceProvider` 已经引入 stable identity 和 transport 聚合逻辑。
- `ApiClient` 已经成为 stable serial 到在线 adb serial 的解析边界。
- `LogStreamService` 在重连时重新解析当前在线 adb address，避免无线端口变化后卡在旧地址。
- `MirrorStateProvider` 使用 `_activeStable` 隔离 UI 稳定身份和后端 adb serial。
- v9 migration 的思路合理：新增 `saved_devices.address`，把旧 `serial` 复制到 `address`，设备下次在线时再尝试升级 primary key。

但是当前仍有一个高优先级阻断项需要先修。

## 高优先级问题：无线断开按钮和断开地址使用了错误的身份字段

### 位置

- `flutter_app/lib/screens/home_screen.dart`
- `_buildDeviceNode`
- `_disconnect`

相关代码大约在：

```dart
if (isConnected &&
    (d.serial.contains(':') || d.serial.contains('_tcp')))
  _disconnectButton(context, d),
```

以及：

```dart
final adbAddress =
    context.read<DeviceProvider>().onlineAddressFor(d.serial);
...
final result = await api.disconnectWirelessAdb(adbAddress);
```

### 问题说明

当前改造后，`SavedDevice.serial` 被定义为 stable identity，例如：

```text
d.serial = R5CT70AHPDR
d.address = 192.168.1.5:42187
```

所以 `d.serial.contains(':')` 对迁移后的无线设备通常为 `false`。这会导致已经在线的无线设备不显示“断开无线连接”按钮。

更严重的是，在 USB + Wi-Fi 同时在线时，当前 `_disconnect` 使用：

```dart
onlineAddressFor(d.serial)
```

但 `onlineAddressFor` 的策略是 USB 优先。也就是说如果同一台设备同时有：

```text
USB transport: USB123456
Wi-Fi transport: 192.168.1.5:42187
stable serial: R5CT70AHPDR
```

`onlineAddressFor('R5CT70AHPDR')` 会返回 `USB123456`，而 `disconnectWirelessAdb` 需要的是无线 `ip:port`。这会把 USB serial 传给无线断开接口，导致断开失败或行为错误。

### 建议修复

`HomeScreen` 判断是否显示无线断开按钮时，应基于当前在线 transports，而不是 `SavedDevice.serial` 字符串形态。

可以在 `DeviceProvider` 中增加：

```dart
Device? wifiTransportFor(String stableSerial) {
  return transportsFor(stableSerial)
      .where((d) => transportTypeForSerial(d.serial) == DeviceTransportType.wifi)
      .firstOrNull;
}

bool hasWifiTransport(String stableSerial) {
  return wifiTransportFor(stableSerial) != null;
}
```

然后 UI 使用：

```dart
final hasWifi = context
    .watch<DeviceProvider>()
    .hasWifiTransport(d.serial);

if (isConnected && hasWifi) {
  _disconnectButton(context, d);
}
```

断开时应明确取 Wi-Fi transport：

```dart
final wifi = context.read<DeviceProvider>().wifiTransportFor(d.serial);
if (wifi == null) {
  // show failure snackbar
  return;
}

final result = await api.disconnectWirelessAdb(wifi.serial);
```

不要用 `onlineAddressFor` 做无线断开，因为它的语义是“普通 adb 命令的首选在线 transport”，当前设计明确 USB 优先。

### 建议补测试

建议补一个测试覆盖：

- 同一 stable serial 同时有 USB 和 Wi-Fi transport。
- 设备列表节点应显示无线断开按钮。
- 点击断开时调用 `disconnectWirelessAdb` 的参数应为 Wi-Fi `ip:port`，不是 USB serial。

如果直接写 widget test 成本较高，至少为 `DeviceProvider` 增加 `wifiTransportFor` 的单元测试：

```dart
expect(provider.onlineAddressFor(stable), usbSerial);
expect(provider.wifiTransportFor(stable)?.serial, wifiAddress);
```

这个测试能防止未来再次把“普通命令首选 transport”和“无线断开目标 transport”混在一起。

## 中优先级问题：legacy row 升级测试名称与实际覆盖不一致

### 位置

- `flutter_app/test/saved_devices_reconcile_test.dart`
- 测试名：`wireless device reconnects on a port we have NEVER seen: legacy row upgraded via PK rename`

当前测试逻辑大约是：

```dart
const oldAdbSerial = '192.168.31.141:55555';
await db.savedDevicesDao.upsertSavedDevice(
  serial: oldAdbSerial,
  address: oldAdbSerial,
  ...
);

final device = _device(adbSerial: oldAdbSerial);
final legacy = await db.savedDevicesDao.getByAddress(device.serial);
```

### 问题说明

测试名说“新端口从未见过”，但实际代码里设备重新上线使用的仍然是 `oldAdbSerial`。所以这个测试只覆盖：

> 旧 legacy row 的 `address` 和当前上线 adb serial 相同时，可以通过 `getByAddress` 找到并升级 primary key。

它没有覆盖：

> 旧 legacy row 是 `192.168.31.141:11111`，设备下次上线变成 `192.168.31.141:22222`，是否还能归并。

按当前实现，如果 offline legacy row 只有旧 `ip:port`，而下次上线使用全新 `ip:port`，在拿到 `hardwareSerial` 前没有可靠方法证明它和旧 row 是同一台物理设备。当前代码会找不到旧 `address`，然后插入 stable row，旧 legacy row 会残留。

这可能是可接受的限制，但测试名和文档应说清楚，避免后续 reviewer 误以为“任意端口变化的旧 legacy row 都能升级”。

### 建议处理

推荐选择下面之一：

#### 方案 A：接受限制，修正测试名和说明

把测试名改成类似：

```text
legacy wireless row is upgraded when the current adb address matches its saved address
```

并在文档中明确：

> 对于迁移前已经离线、且只保存了旧 `ip:port` 的无线设备，如果它下次上线时端口已经变化，当前实现无法无损识别它和旧 row 的关系。系统会创建 stable row，旧 legacy row 需要用户手动清理或后续提供更强匹配机制。

这是更保守且安全的方案。

#### 方案 B：实现更强的 legacy 清理机制

例如用 model / brand / sdk / last seen 等字段尝试匹配旧 row。但这存在误合并风险，尤其是同型号多设备场景，不建议简单实现。

## 低优先级问题：局部静态检查不干净

执行命令：

```bash
dart analyze lib/providers/device_provider.dart \
  lib/services/api_client.dart \
  lib/services/log_stream.dart \
  lib/providers/logcat_state_provider.dart \
  lib/providers/mirror_state_provider.dart \
  lib/db/database.dart \
  lib/db/dao/saved_devices_dao.dart \
  test/device_transport_resolution_test.dart \
  test/saved_devices_reconcile_test.dart \
  test/device_matches_identity_test.dart
```

结果：

```text
warning - test/saved_devices_reconcile_test.dart:12:8 - Unused import: 'package:adb_tool/db/dao/saved_devices_dao.dart'. Try removing the import directive. - unused_import
warning - test/saved_devices_reconcile_test.dart:17:8 - Unused import: 'package:drift/drift.dart'. Try removing the import directive. - unused_import
info - lib/db/database.dart:124:3 - Parameter 'executor' could be a super parameter. Trying converting 'executor' to a super parameter. - use_super_parameters
```

建议：

- 删除 `saved_devices_reconcile_test.dart` 中两个未使用 import。
- `use_super_parameters` 是 style info，不一定阻塞；如果 CI 将 info 视作失败，也应修掉。

## 已运行验证

### 通过

```bash
flutter test test/device_transport_resolution_test.dart \
  test/saved_devices_reconcile_test.dart \
  test/device_matches_identity_test.dart
```

结果：全部通过。

### 通过

```bash
go test ./internal/server
```

结果：通过。

### 未通过

```bash
dart analyze ...
```

失败原因见上一节，主要是两个 unused import 和一个 style info。

## Review 中看起来合理的部分

### DeviceProvider

文件：`flutter_app/lib/providers/device_provider.dart`

合理点：

- `stableIdentityFor(Device device)` 优先使用 `hardwareSerial`，否则 fallback 到 adb serial。
- `transportsFor(stableSerial)` 使用 `matchesIdentity` 聚合同一 stable identity 的多个在线 transport。
- `onlineAddressFor(stableSerial)` 明确只返回在线 transport，并按 USB > Wi-Fi > unknown 排序。
- `_reconcileOnlineDevice` 按 stable row、legacy address row、新设备三种路径处理。

注意点：

- `onlineAddressFor` 不应被无线断开逻辑使用，因为其 USB 优先策略适合普通 adb 命令，不适合 Wi-Fi disconnect。

### ApiClient

文件：`flutter_app/lib/services/api_client.dart`

合理点：

- `resolveAdbSerial` 在有 `DeviceProvider` 注入时只使用在线地址。
- 找不到在线 transport 时抛 `DeviceOfflineException`，避免继续使用 stale DB address。
- 未注入 `DeviceProvider` 时 fallback 到传入 serial，兼容测试或旧构造路径。

### LogStreamService

文件：`flutter_app/lib/services/log_stream.dart`

合理点：

- channel 以 stable serial 为 key。
- 每次 websocket ready 后重新通过 `DeviceProvider.onlineAddressFor(stableSerial)` 解析当前 adb address。
- 这能避免无线端口变化后 logcat stream 卡在旧 address。

注意点：

- 如果设备离线，当前逻辑会创建 websocket 后再发现没有 adb address，然后安排重连。这不是本次阻断项，但后续可以考虑在 connect 前先判断，减少无效 websocket 连接。

### MirrorStateProvider

文件：`flutter_app/lib/providers/mirror_state_provider.dart`

合理点：

- 使用 `_activeStable` 表示当前 UI 归属的稳定设备身份。
- 离线事件通过 `hardwareSerial` 匹配 `_activeStable`，避免直接比较后端 scrcpy adb serial。

### DB migration / DAO

文件：

- `flutter_app/lib/db/database.dart`
- `flutter_app/lib/db/dao/saved_devices_dao.dart`
- `flutter_app/lib/db/tables/saved_devices.dart`

合理点：

- schema version 升到 9。
- v9 migration 新增 `address` 并 backfill 为旧 `serial`。
- `renamePrimaryKey` 使用“插入新 row → 更新 child FKs → 删除旧 row”的顺序，避免 FK 约束问题。
- `updateAllDevicesConnection` 使用 stable identity set 更新连接状态，和新的 `saved_devices.serial` 语义一致。

注意点：

- `renamePrimaryKey` 只迁移了 `test_sessions` 和 `scrcpy_options`。如果未来还有其他表用 `saved_devices.serial` 做持久引用，需要同步纳入迁移。

## 建议修复顺序

1. 修复 `HomeScreen` 无线断开按钮显示条件：改为基于 Wi-Fi transport。
2. 修复 `_disconnect`：传 `wifiTransport.serial` 给 `disconnectWirelessAdb`，不要用 `onlineAddressFor`。
3. 为 `DeviceProvider` 增加 `wifiTransportFor` / `hasWifiTransport`，并补单元测试。
4. 修正 `saved_devices_reconcile_test.dart` 中 misleading 的测试名或测试内容。
5. 删除 unused imports。
6. 重跑：

```bash
flutter test test/device_transport_resolution_test.dart \
  test/saved_devices_reconcile_test.dart \
  test/device_matches_identity_test.dart

dart analyze lib/providers/device_provider.dart \
  lib/services/api_client.dart \
  lib/services/log_stream.dart \
  lib/providers/logcat_state_provider.dart \
  lib/providers/mirror_state_provider.dart \
  lib/db/database.dart \
  lib/db/dao/saved_devices_dao.dart \
  test/device_transport_resolution_test.dart \
  test/saved_devices_reconcile_test.dart \
  test/device_matches_identity_test.dart

go test ./internal/server
```

## 给后续 reviewer 的重点问题

请重点确认：

1. `onlineAddressFor` 的语义是否只用于普通 adb 命令。如果是，无线断开必须另走 Wi-Fi transport。
2. 迁移前离线无线设备在“端口变化后才上线”的场景，产品是否接受旧 legacy row 残留。
3. `renamePrimaryKey` 是否覆盖了所有持久引用 `saved_devices.serial` 的表。
4. `ApiClient` 未注入 `DeviceProvider` 时 fallback 到原 serial 是否只出现在测试/兼容路径，不会绕过生产离线保护。
5. UI 是否还有通过字符串形态判断无线设备的地方，例如 `serial.contains(':')`，这些在 stable serial 改造后通常都不可靠。
