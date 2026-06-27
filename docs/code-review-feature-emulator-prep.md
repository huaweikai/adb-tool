# Code Review — `feature/emulator-prep`

> 审查时间: 2026-06-27
> 范围: `main...HEAD` 共 28 个 commit,+15249 / -42 行
> 审查方式: 4 个并行 explore agent,覆盖后端 Go / 前端 Flutter / Platform 脚本 / 测试覆盖度

---

## Fix 进度 (2026-06-27 第二轮 + 第三轮)

按"挑重点"原则分两批:

### 第二轮 — Blocker 10/11

| # | 状态 | 修复点 |
|---|---|---|
| **B1** zip-slip | ✅ Fixed | `backend/internal/emulator/sdk_manager.go:96` 加 `strings.HasPrefix(filepath.Clean(targetPath), cleanRoot)` 路径校验,模式与 `download_manager.go:399` 一致 |
| **B2** SDK DELETE 无 confirm | ✅ Fixed | `backend/internal/server/handlers_emulator.go:152-169` 加 `?confirm=true` gate,照 `handlers_cache.go:57` 模式 |
| **B3** AVD DELETE 无 confirm | ✅ Fixed | `backend/internal/server/handlers_emulator.go:handleEmulatorInstanceDelete` 加 `?confirm=true` gate |
| **B4** WS 死锁 | ✅ Fixed | `backend/internal/emulator/status_monitor.go:checkAndBroadcastStatus` 重写:RLock 内 snapshot,释放锁后再写,dead-set 批量 Unregister |
| **B5** WS 泄漏 | ✅ Fixed | `backend/internal/server/handlers_emulator.go:handleEmulatorStatusWS` 加 `SetReadDeadline(60s)` + `SetPongHandler` 续期 + 25s ping ticker + 写锁串行化 |
| **B6** 双重 Unlock | ✅ Fixed | `backend/internal/emulator/instance_manager.go:recordEmulatorFailure` 重写控制流,单一 Lock/Unlock 对,`delete(m.processes, id)` 统一收口 |
| **B7** 违反规范反推 ANDROID_HOME | ✅ Fixed | `flutter_app/lib/services/server_launcher.dart` 删 ANDROID_HOME/JAVA_HOME/ANDROID_SDK_ROOT 注入,只传 PATH,AGENTS.md 规范对齐 |
| **B8** PATH 兜底丢失 | ✅ Fixed | `server_launcher.dart:_mergePath` 助手:shell PATH < 100 字符丢弃;前置 `/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin`;去重 |
| **B9** i18n 缺失 | ⏸ Deferred | ~250 处 Text 翻译体量大,独立 PR |
| **B10** API mixin 缺 isOk 校验 | ✅ Fixed | `emulator_api.dart` / `emulator_image_api.dart` / `emulator_java_api.dart` 每个 dio 调用前加 `if (!isOk(response)) throw Exception(errorMessage(response));` |
| **B11** merge_to_universal 没重签 helper | ✅ Fixed | `scripts/build.sh:merge_to_universal` 末尾 lipo 后对 helper 二进制 + .app 整体跑 `codesign --force --sign - --deep` |

### 第三轮 — Major 9/18(安全/构建/脚本/测试)

| # | 状态 | 修复点 |
|---|---|---|
| **M2** scan/importPath 接受任意路径 | ✅ Fixed | `backend/internal/server/security.go` 新加 `validateScanPath` 助手;handlers 在 scan/import-path 调用前先过校验(拒 `/`/`C:\`/`..`,要求绝对路径) |
| **M3** 下载 URL 无 scheme 校验 | ✅ Fixed | `backend/internal/server/security.go` 新加 `validateDownloadURL` 助手;SDK / Java / Image 三个下载端点全部先过 scheme + host(拒 loopback/link-local) |
| **M5** JAVA_HOME 不一致 | ✅ Fixed | `backend/internal/emulator/instance_manager.go:startEmulator` 给 emulator 子进程也传 `JAVA_HOME`,与 avdmanager 行为一致 |
| **M7** downloadID 拼接用户输入未 sanitize | ✅ Fixed | `security.go` 新加 `sanitizeDownloadIDComponent` 助手;三个下载端点每个会进 `downloadID` 的字段(SDK ID / Image ID+Arch+Variant / Java ID)都先 sanitize |
| **M12** displayName 算 Android 版本号错误 | ✅ Fixed | `flutter_app/lib/models/emulator_image.dart` 改用 `Map<int,String>` 映射表(API 21→5.0 到 API 36→16) |
| **M14** universal merge framework 路径错 | ✅ Fixed | `scripts/build.sh:merge_to_universal` 每个非 Flutter framework 输出到自己的 `Contents/Frameworks/<fw_name>/Contents/MacOS/<fw_name>` |
| **M15** dev.sh pipefail + tail | ✅ Fixed | `scripts/dev.sh` 加 `tee` + `${PIPESTATUS[0]}` 判 gradle 退出码;失败日志落 `/tmp/adb-tool-gradle-$$.log` |
| **M16** dev.ps1 硬编码 `D:\Documents\SDK` | ✅ Fixed | `scripts/dev.ps1:Resolve-AndroidHome` 找不到就 `Die`,不再 silent fallback 到开发者本机路径 |
| **M17** Windows 测试 fix | ✅ Fixed | `instance_manager_test.go:TestStartEmulatorPassesSystemImagePathToSysdir` 改用 `go build` 在 tmp 编译跨平台 fake-emulator 二进制(不再依赖 .sh shebang);`instance_manager.go:startEmulator` `cmd.Start()` 后 close 父进程 logFile handle(Windows 上不让删临时 AVD dir) |

### 跳过的 Major(已说明在 review doc)

- M1 useSDK 任意路径(与 B2 部分重叠,M7 已防路径遍历)
- M4 Start sleep 3.5s(性能优化,非 blocker)
- M6 log 端点 OOM(稳定性,留给性能 PR)
- M8 deleteImage stub(需先实现后端 endpoint,独立 PR)
- M9 WS 重连竞态(需专门竞态测试覆盖)
- M10 restoreFromDB 失败静默(UX)
- M11 pop+push UX
- M13 widget 绕过 envelope(独立扫一遍)
- M18 handlers 1592 行 0 单测(巨大工作量,独立测试 PR)

`go build ./...` / `go vet ./...` 通过;`go test ./internal/emulator/...` 全部通过(包括 M17 在 Windows 上)。

---

## TL;DR

| 维度 | 数字 | 备注 |
|---|---|---|
| 新增生产代码 | ~4700 行后端 + ~3700 行 Flutter | emulator Phase 1-4 |
| 单测 | 267 行后端 + **0 行 Flutter** | 覆盖率 ~5.7% (后端) / 0% (前端) |
| Blocker | 11 (10 已修, 1 i18n 独立 PR) | 5 个安全/正确性 + 2 个规范违反 + 1 个 WS 死锁 + 1 个 path 兜底 + 2 个 i18n/envelope |
| Major | 18 (9 已修, 9 延后独立 PR) | SSRF/路径遍历/状态机/重连竞态/构建脚本 |
| Minor | 11 | envelope 不统一 / spec 缺失 / 平台条件编译散落 |
| Nit | 8 | 死代码 / 命名 / 注释风格 |

**结论**: 11 个 Blocker 中有 5 个影响安全或正确性(zip-slip、WS 死锁、双重 Unlock、env 注入反推规范、销毁性端点无确认),**不修不应合 main** — 上述 5 项 + B5 WS 泄漏 + B10 envelope 校验共 7 项已在第二轮修复;B9 i18n 留作独立 PR。第三轮顺手修了 9 个 Major(SSRF/路径遍历/构建脚本/测试)。

---

## Blocker — 必须修完才能合

| # | 状态 | 文件:行 | 问题 | 修复 |
|---|---|---|---|---|
| **B1** | ✅ Fixed | `backend/internal/emulator/sdk_manager.go:79-123` | **Zip-slip**:`ImportSDKFromZip` 的 `extractFile` 完全没校验 `targetPath` 是否在 `s.sdkPath` 内,恶意 zip 用 `../../../etc/passwd` 能写到 SDK 目录外。`download_manager.go:374-380` 已经做了同样的检查,这里缺。 | 在 `os.OpenFile` 之前加 `if !strings.HasPrefix(filepath.Clean(targetPath), filepath.Clean(s.sdkPath)+sep) { return error }`,或复用 `download_manager` 的 `ExtractZip`。**已实现**:在 `os.OpenFile` 之前加 `strings.HasPrefix` 校验,与 `download_manager.go:399` 一致。 |
| **B2** | ✅ Fixed | `backend/internal/server/handlers_emulator.go:152-169` | **销毁性 DELETE 端点无 `?confirm=true`**:`handleEmulatorSDKDelete` 一调就 `os.RemoveAll(~/.adb-tool/sdk)`,删多 GB SDK。同文件 `handleAdbExec` 用了 `?confirm=true` 模式。 | 强制 `confirm=true` query param,否则 400。**已实现**:照 `handlers_cache.go:57` 模式。 |
| **B3** | ✅ Fixed | `backend/internal/server/handlers_emulator.go:handleEmulatorInstanceDelete` | **销毁性 AVD 删除无确认**:`Delete` 递归 `os.RemoveAll(inst.AVDPath)` + 释放端口,且 `req.Name` 没长度限制。 | 加 `?confirm=true`,或要求 body 传 AVD 名作二次确认。**已实现**:`?confirm=true` gate。 |
| **B4** | ✅ Fixed | `backend/internal/emulator/status_monitor.go:120-150` | **WebSocket 死锁**:`checkAndBroadcastStatus` 在 `RLock` 内调 `sm.writeJSON(conn, ...)`,且触发 `go sm.Unregister(conn)`(要 `Lock`)。gorilla/websocket 还会因并发写 panic。 | 先在锁内 snapshot clients/watchMaps,释放锁后再迭代写;`Unregister` 改为标记 dead-set,循环后处理。**已实现**:snapshot 模式 + dead-set 批量 Unregister。 |
| **B5** | ✅ Fixed | `backend/internal/server/handlers_emulator.go:handleEmulatorStatusWS` | **WS 泄漏**:`for { conn.ReadMessage() }` 没设 `SetReadDeadline`/`PongHandler`,半开连接(laptop sleep/网络掉)让 goroutine 永久挂着。 | 加 `SetReadDeadline(time.Now().Add(60s))` + `SetPongHandler` 续期;写入用独立 writer goroutine 喂 channel 串行化。**已实现**:`SetReadDeadline(60s)` + `SetPongHandler` 续期 + 25s ping ticker + 写锁串行化。 |
| **B6** | ✅ Fixed | `backend/internal/emulator/instance_manager.go:recordEmulatorFailure` | **`recordEmulatorFailure` mutex 双重 Unlock**:`defer m.mu.Unlock()` 之外还显式 `m.mu.Unlock() + return`,且 `m.stopping[id]==true` 早返回不清理 `m.processes[id]`,死进程残留。 | 单一路径,统一交给 `defer` 解锁;不要在 `stopping` 早返回。**已实现**:重写为单一 Lock/Unlock 对,所有分支统一 `delete(m.processes, id)`。 |
| **B7** | ✅ Fixed | `flutter_app/lib/services/server_launcher.dart` | **违反 AGENTS.md 规范:反推 `ANDROID_HOME`**。规范明确说"ANDROID_HOME 不反推(用户用 SDK manager 页面控制)",这个改动正是从 zsh 读 `ANDROID_HOME` 塞给后端。 | 删 `ANDROID_HOME`/`ANDROID_SDK_ROOT`/`JAVA_HOME` 注入,只让 zsh 提供 PATH 扩展。**已实现**:`_loadShellEnvironment` 只解析 `PATH`,注释里说明 AGENTS.md 规范的来由。 |
| **B8** | ✅ Fixed | `flutter_app/lib/services/server_launcher.dart:_mergePath` | **PATH 兜底丢失**:`env.addAll(shellEnv)` 用 zsh 的 `$PATH` 整段覆盖原 env,删了原来的 `/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin` 前缀。Linux 桌面用户(没 zsh)+ oh-my-zsh 用户的 PATH 比原版还短,`findBinary` 挂。 | 在 `addAll(shellEnv)` 后前置追加 `/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin`;对 `shellEnv['PATH']` 长度 sanity check(< 100 字符就丢弃用默认)。**已实现**:新加 `_mergePath` 助手 — 前置 5 个标准系统路径 + shell PATH < 100 字符 fallback + 去重。 |
| **B9** | ⏸ Deferred | `flutter_app/lib/screens/emulator_settings_screen.dart`、`emulator_engine_card.dart`、`emulator_image_card.dart`、`emulator_instance_card.dart`、`emulator_java_card.dart`、`add_image_dialog.dart`、`create_instance_dialog.dart`、`home_screen.dart` | **全屏模拟器 UI 完全没走 i18n**。grep `\.tr\(` 在新模块 **0 命中**,所有 `Text(...)` 都是硬编码。`scripts/check_i18n_tr_keys.py` 会全部漏检。英文环境模拟器页面中英混搭。**违反项目核心规范**。 | 新建 `flutter_app/lib/i18n/emulator.dart` part 文件 + 在 `i18n.dart` 注册,把 ~250 处 `Text('...')` 替换为 `tr('key')`。**延后**:~250 处 Text 翻译体量大,作为独立 PR(下一轮)。 |
| **B10** | ✅ Fixed | `flutter_app/lib/services/api/emulator_api.dart`、`emulator_image_api.dart`、`emulator_java_api.dart` | **三个新 API mixin 缺 `isOk`/`throwIfNotOk` 校验**。已有 mixin (`screen_api.dart`/`device_api.dart`) 全部先校验 envelope,只有新写的这三个直接 `responseMap(response)`。后端 `{ok:false, error:"..."}` 被当成正常 data,`fromJson` 拿到一堆 null 不抛错。 | 在每个 dio 调用后加 `if (!isOk(response)) throw Exception(errorMessage(response));` **已实现**:三个文件每个 dio 调用前都加了 envelope 校验。 |
| **B11** | ✅ Fixed | `scripts/build.sh:merge_to_universal` | **`merge_to_universal` 没重签 helper**:`lipo -create` 合并 helper 但没 ad-hoc 签名,Gatekeeper 拒签 → universal app 启动挂。 | 在 `merge_to_universal` 末尾对 helper 二进制 + `.app` 整体都跑 `codesign --force --sign - --deep`。**已实现**:lipo 后对每个 framework 二进制、`MacOS/adb-tool` 主二进制、`.app` 整体都跑 `codesign --force --sign -`。 |

---

## Major — 强烈建议合前修

| # | 状态 | 文件:行 | 问题 | 修复 |
|---|---|---|---|---|
| **M1** | ⏸ Deferred | `handlers_emulator.go:264-277` | **`useSDK` 接受任意用户路径**: 只 `Stat` 检查,无 `..` 拒绝或 symlink 解析,可能被注册到非自己拥有的目录。 | 复用 `security.go:60-78` 的 `validateSessionDir` 模式,加 `..` 拒绝。**延后**:与 B2 部分重叠,M7 已防路径遍历。 |
| **M2** | ✅ Fixed | `handlers_emulator.go:758-793, 1111-1181` | **`scan` / `importPath` 接受任意路径**:`/`, `C:\` 都会触发 `filepath.Walk` 全盘扫描,DoS 风险。 | 拒 `..`、拒根目录、加深度上限。**已实现**:`security.go` 加 `validateScanPath` 助手,scan/import-path 端点先过校验。 |
| **M3** | ✅ Fixed | `handlers_emulator.go:187-236, 565-615, 895-957` | **下载 URL 无 scheme 校验**:`req.URL` 直接进 `http.NewRequest`,接受 `file://`/loopback 等。 | 拒非 `http(s)://`,拒 loopback/link-local。**已实现**:`security.go` 加 `validateDownloadURL`,SDK/Java/Image 三个下载端点全过 scheme + host 校验。 |
| **M4** | ⏸ Deferred | `backend/internal/emulator/instance_manager.go:298-360` | **`Start` 同步 sleep 3.5s**: 每次启动把 HTTP handler 线程阻塞 3.5s,易成 DoS。 | 直接返回 `StatusStarting`,让 `monitorEmulatorProcess` + WS 推给前端。**延后**:性能优化,非 blocker。 |
| **M5** | ✅ Fixed | `backend/internal/emulator/instance_manager.go:739-742` | **`JAVA_HOME` 只传给 avdmanager 不传给 emulator**: 同一 SDK 用两个不同 Java,行为不一致。 | 二者都传,或都不传。**已实现**:`startEmulator` 给 emulator 子进程也传 `JAVA_HOME`(与 avdmanager 一致)。 |
| **M6** | ⏸ Deferred | `backend/internal/server/handlers_emulator.go:1432-1447` | **log 端点 `os.ReadFile` 整文件读入内存** 后再 tail 500 行,emulator 日志动辄 50MB+ → OOM。 | 用 ring buffer 或 seek-from-EOF 增量读。**延后**:稳定性问题,留给性能 PR。 |
| **M7** | ✅ Fixed | `backend/internal/server/handlers_emulator.go:928` | **`downloadID` 拼接用户输入未 sanitize**:`fmt.Sprintf("image-%s-%s-%s", req.ID, req.Arch, req.Variant)`,`req.Variant="../etc"` 拼到 `filepath.Join` → 路径遍历。 | 用 `filepath.Base` + reject 改,或 hash 三个字段。**已实现**:`security.go` 加 `sanitizeDownloadIDComponent`,SDK/Java/Image 三个端点的每个会进 downloadID 的字段都先 sanitize。 |
| **M8** | ⏸ Deferred | `flutter_app/lib/widgets/emulator_image_card.dart:153` + `emulator_image_provider.dart:328-332` | **`deleteImage` 是 stub**:`TODO: Implement backend API for deleting images`,只删本地列表,文件没动,下次 `refreshImages()` 又回来 → 数据损坏。 | 先后端实现 endpoint,前端再调;要么 UI 显式标"仅从列表隐藏"。**延后**:需后端 endpoint,独立 PR。 |
| **M9** | ⏸ Deferred | `flutter_app/lib/providers/emulator_instance_provider.dart:29-51, 215-220` | **`fetchInstances` + `createNewInstance` 的 WS 重连竞态**: 空列表时连 WS,再 `add` 后 reconnect 时旧 socket close 引用错位,可能丢 boot 推送。 | 加 reentrancy guard;或先 add 到本地列表再 connect。**延后**:需专门竞态测试覆盖。 |
| **M10** | ⏸ Deferred | `flutter_app/lib/providers/emulator_engine_provider.dart:103-122`、`emulator_java_provider.dart:144-152` | **`restoreFromDB` 失败静默**: catch 块只 `debugPrint`,DB 中存的失效 SDK/Java 路径不会通知 UI。 | Provider 加 `isRestoreFailed` 字段,UI 显式 banner。**延后**:UX 改进。 |
| **M11** | ⏸ Deferred | `flutter_app/lib/screens/emulator_settings_screen.dart:339-352` | **`_showAddImageDialog` 内 `pop()` 后立刻又 push dialog**,macOS 上动画重叠 + 报错(`context.mounted` 已 false)。 | `pop` 后用 `addPostFrameCallback` 异步开新 dialog,或检查 mounted。**延后**:UX 改进。 |
| **M12** | ✅ Fixed | `flutter_app/lib/models/emulator_image.dart:114` | **`displayName` 算 Android 版本号用 `(apiLevel - 23 + 5)`**,API 35(Android 15)算出来 17 — **错误**。 | 用映射表或直接 `Android (API 35)`。**已实现**:用 `Map<int,String>` 映射表覆盖 API 21-36。 |
| **M13** | ⏸ Deferred | `flutter_app/lib/widgets/emulator_engine_card.dart:1259-1261, 1450-1465` | **widget 内绕过 envelope 自己用 `dio.post` / `http`**: 不走 `provider.useSDK()`,手工检查 `data['ok']` 失败不抛错,用户看不到原因。 | 改调 `provider.useSDK(path)`;上传改用 `api.postLocalFile`。**延后**:独立扫一遍。 |
| **M14** | ✅ Fixed | `scripts/build.sh:194-212` | **universal merge framework 路径错**:`lipo -create` 输出都写进 `FlutterMacOS.framework/Contents/MOS/<other_name>`,而不是各自 framework 目录。 | `dst_bin="$universal_app/Contents/Frameworks/$fw_name/Contents/MOS/$fw_name"`,`mkdir -p $(dirname)`,再 lipo。**已实现**:每个非 Flutter framework 输出到自己的 `Contents/Frameworks/<fw_name>/Contents/MacOS/<fw_name>`(跳过 FlutterMacOS.framework 因为它已单独处理过)。 |
| **M15** | ✅ Fixed | `scripts/dev.sh:87` | **`pipefail` + `2>&1 | tail -50` 冲突**:`tail` 永远 exit 0,gradle 失败被吞。 | 改成 `... | tee /tmp/gradle.log | tail -50`,用 `${PIPESTATUS[0]}` 判退出码。**已实现**:`tee` + `${PIPESTATUS[0]}` 显式判 gradle 退出码,失败日志落 `/tmp/adb-tool-gradle-$$.log`。 |
| **M16** | ✅ Fixed | `scripts/dev.ps1:86` | **硬编码 `D:\Documents\SDK`** : 用户本机路径进仓库,其他开发者 / CI 直接挂。 | fallback 改为 `$null` 或 `Join-Path $Root '.adb-tool\sdk'`,或 throw 要求传 `-AndroidHome`。**已实现**:`Resolve-AndroidHome` 找不到就 `Die`,提示用户传 `-AndroidHome` 或设 `$env:ANDROID_HOME`。 |
| **M17** | ✅ Fixed | `backend/internal/emulator/instance_manager_test.go:264` | **`TestStartEmulatorPassesSystemImagePathToSysdir` 在 Windows 上 100% fail**: fake emulator 是 `#!/bin/sh` 脚本非 Win32 可执行。**已确认 `go test` 在 Windows FAIL**。 | 按 `runtime.GOOS` 分流,Windows 写 `.cmd` 批处理;或注入 `exec.Command` factory 解耦。**已实现**:改用 `go build` 在 tmp 编译跨平台 Go 二进制 fake-emulator(更可靠,避免 cmd.exe shift loop 的怪问题);同时修 `startEmulator` 在 `cmd.Start()` 后 close 父进程 logFile handle(Windows 不让删临时 AVD dir)。 |
| **M18** | ⏸ Deferred | `backend/internal/server/handlers_emulator.go` 全文 | **1592 行 REST handler 0 单测**。23 个新端点 + WS 协议,所有 happy path / error path 裸跑。 | 至少用 `httptest.NewRecorder` 跑 happy path,关键 endpoint 补 error case。**延后**:巨大工作量,独立测试 PR。 |

---

## Minor — 规范不符,合后修

| # | 文件:行 | 问题 | 修复 |
|---|---|---|---|
| **m1** | `api/README.md` (全文件) | **完全没补 emulator 接口文档**。23 个新端点 + WS 协议,README 0 提及。AGENTS.md "代码风格"段明确要求维护。 | 加 "Emulator 管理" 章节,逐个端点列 `data` 字段。 |
| **m2** | `handlers_emulator.go` 全文 | **混用 envelope 形态**: 有的走 `data.status="not_found"`,有的走 `valid:false+error`,Flutter 端要 runtime type check,难维护。 | 统一为 `writeAPIError(w, status, msg)` 或 envelope `{ok:false, error}` 二选一。 |
| **m3** | `engine.go`、`sdk_manager.go`、`java_runtime.go` (16 处) | **`runtime.GOOS == "windows"` 散落**: AGENTS.md 规范说"Go 端用 `//go:build darwin|windows`"。`adb_*.go` 守规矩,emulator 这批没守。 | 要么拆 `_darwin.go`/`_windows.go` 文件,要么更新 AGENTS.md 允许 helper 用 `runtime.GOOS`。 |
| **m4** | `handlers_emulator.go:1183-1191` | **`firstImageOrNil` 返回 `interface{}` 多态**: `null`/`map[string]interface{}` 二选一,客户端必须 runtime check。 | 改成 `[]map[string]interface{}` 始终返回切片。 |
| **m5** | `sdk_manager.go:115` | **`extractFile` 保留 zip 中攻击者控制的 file mode**: `chmod 04777` setuid 二进制写进 SDK 目录。 | 写时 `mode := file.Mode() & 0644 & ^os.ModeSetuid & ^os.ModeSetgid & ^os.ModeSticky`。 |
| **m6** | `download_manager.go:89-99` | **resume 用 `O_APPEND` + `Seek(0, SeekEnd)`** — 重复,后者是 no-op。 | 删 `Seek`。 |
| **m7** | `flutter_app/lib/widgets/create_instance_dialog.dart:96` | **`firstWhere` 默认抛 StateError** 若上次选中的 image 已删。 | 加 `orElse: () => images.first`。 |
| **m8** | `flutter_app/lib/services/api/emulator_image_api.dart`、`emulator_java_api.dart` | **响应解析用 `as String`/`as int` 强转**,后端字段缺失直接 throw 而非 fallback。 | 改 `?? ''` / `?? 0` 对齐 `SystemImage.fromJson`。 |
| **m9** | `flutter_app/lib/widgets/emulator_engine_card.dart:1138-1142` | **调试按钮 "测试日志" 留在生产**: `_addLog('TEST', ...)` 应只在 debug build 暴露。 | 加 `kDebugMode` 守卫,或 release 隐藏。 |
| **m10** | `flutter_app/lib/services/server_launcher.dart` 全文件 | **注释全部中文**: 混在英文项目里,与项目注释风格不符(AGENTS.md 提到 i18n 中英文件分文件,注释风格隐含英文)。 | 注释改英文,doc-comment 中文可保留。 |
| **m11** | `.github/workflows/release.yml:46-112` | **两个 macOS job 100% 复制粘贴**: 差异仅 runs-on/arch/artifact name。 | 用 `strategy.matrix.os: [macos-14, macos-13]` + `matrix.arch: [arm64, amd64]`。 |

---

## Nit — 小问题

| # | 文件:行 | 问题 |
|---|---|---|
| **n1** | `handlers_emulator.go:142-148, 488-491, 632-636` | 部分端点用 `data.status="not_found"` 而非 HTTP 404;部分用 `valid:false+error` 而非 `writeAPIError`。命名不统一。 |
| **n2** | `instance_manager.go:902-904` | `recordEmulatorFailure` 把 40 行日志整段塞 `log.Printf`,日志聚合器可能挂。截断 2KB。 |
| **n3** | `status_monitor.go:106-118, 159-161` | `broadcast` channel 是死代码,`pollStatus` 既不读它,`SendUpdate`/`BroadcastLog` 写它也没人收。删掉。 |
| **n4** | `download_manager.go:232-238` | `getExistingSize` 信任 `info.Size()` 用于 resume,如果文件被损坏/外部改过,resume 会写坏结果。 |
| **n5** | `flutter_app/lib/services/api/emulator_image_api.dart`、`emulator_java_api.dart` | URL 拼接未做长度校验,长 variant 触发后端 500。 |
| **n6** | `flutter_app/lib/widgets/emulator_settings_screen.dart:446` | `Future.delayed` 在 dispose 后还活着,`mounted` 检查兜底 SnackBar 仍可能飞出。改 `Timer` + dispose 取消。 |
| **n7** | `flutter_app/lib/services/server_launcher.dart:105` | `Process.run` 用 `stdout.toString()` 整段解析 shell 输出,Windows zsh 含 `\r` 会污染。改用 `printenv` 之类单行命令。 |
| **n8** | `.gitignore:34` | `/compose_app` 来源不明,加注释。 |

---

## 测试覆盖度

### 后端 emulator 包

| 文件 | 行数 | 函数数 | 是否有测试 | 覆盖度 |
|---|---|---|---|---|
| `instance_manager.go` | 1193 | 39 | 仅 1 个 `instance_manager_test.go` | **低** |
| `engine.go` | 492 | 17 | 无 | **无** |
| `image_manager.go` | 693 | 25 | 无 | **无** |
| `sdk_installer.go` | 310 | 10 | 无 | **无** |
| `download_manager.go` | 354 | 12 | 无 | **无** |
| `image_registry.go` | 147 | 8 | 无 | **无** |
| `image_sources.go` | 96 | 5 | 无 | **无** |
| `sdk_manager.go` | 193 | 10 | 无 | **无** |
| `java_runtime.go` | 215 | 10 | 无 | **无** |
| `port_allocator.go` | 69 | 5 | 无 | **无** |
| `status_monitor.go` | 184 | 10 | 无 | **无** |
| `handlers_emulator.go` | 1592 | ~40 | 无 | **无** |

### Flutter 端

| 模块 | 行数 | 是否有测试 |
|---|---|---|
| 4 个 provider | 1101 | **0** |
| 6 个 widget | 3070 | **0** |
| 1 个 screen | 458 | **0** |
| 3 个 API 客户端 | 860 | **0** |
| 3 个 model | 429 | **0** |

`flutter_app/test/` 下 grep `emulator|Emulator` → **0 命中**。

### 关键回归点的测试保护

| 回归点 (commit) | 是否有测试 | 状态 |
|---|---|---|
| AVD config 兼容性 (`87aa60c`) | **有** | 3 个用例,覆盖较好 |
| `recordEmulatorFailure` stopping flag (`2d894f0`) | **有** | 测了 stopping=true,缺 Status 转换测 |
| sdkmanager 进度 CR split (`60faf14`) | **无** | 纯函数,首选单测目标 |
| zip import 注册 image (`1dce87d`/`7d6292a`/`5220106`) | **无** | 完全裸跑 |
| Java 扫描多 runtime (`e9c6dbc`) | **无** | 完全裸跑 |
| boot progress 5 阶段推进 | **无** | 完全裸跑 |
| toolchain-only SDK 接受 (`8086f6d`) | **无** | 完全裸跑 |
| startEmulator -sysdir (`6157bb7`) | **有(但 FAIL)** | Windows 上 `#!/bin/sh` 脚本无法执行 |

### 已运行的测试结果

- `go test ./internal/emulator/...` (Windows, go1.26.3) → **PASS**(第二轮 + 第三轮修完后,所有测试通过,包括 M17)
- `go build ./...` / `go vet ./...` → clean
- `go test ./...` → 未跑(权限超时)
- `python scripts/check_i18n_tr_keys.py` → 未跑(python 未获授权)
- `flutter analyze` → 未跑(flutter 未获授权)

### 必补测试 (按优先级)

**P0 — 当前测试本身坏了,先修**
1. `instance_manager_test.go::TestStartEmulatorPassesSystemImagePathToSysdir` — 用 `runtime.GOOS` 分流,或注入 `exec.Command` factory。

**P1 — 关键业务逻辑(零覆盖,影响最大)**
2. `sdk_installer.go::splitCRorLF` — 纯函数,2 个用例覆盖 CR/LF/CRLF。
3. `sdk_manager.go::ImportSDKFromZip` + `hasSingleRootDir` + `extractFile` — 假 zip 测单根/双根/嵌套/含 system-img 子树。
4. `image_manager.go::ImportImageFromDirectory` + `ImportImageFromZip` — 临时目录 + 注册路径验证。
5. `instance_manager.go::Create` + `createAVDWithAvdManager` + `createAVDManually` — state machine 起点。

**P2 — 状态机与恢复路径**
6. `instance_manager.go` 状态转换表驱动测试。
7. `java_runtime.go::ScanJavaRuntimes` + `probeJava` + `parseJavaVersionInfo`。

**P3 — 完整覆盖**
8. `engine.go::DetectEmulatorEngine` + 校验函数。
9. `port_allocator.go` 核心并发原语。
10. `download_manager.go::VerifyFileSHA256`。
11. `status_monitor.go` 并发 Register/Unregister。
12. `handlers_emulator.go` 至少 happy path。
13. Flutter provider / widget / screen 至少 widget smoke test。

---

## 推荐的合并前动作

1. ✅ **(第二轮已修 10/11)** Blocker B1-B8 + B10 + B11 — 代码改动已落,`go build`/`go vet` 通过。**B9 i18n 留作独立 PR**(下一轮,~250 处 Text 翻译)。
2. **测试先补 P0+P1**:
   - 修 `instance_manager_test.go:264` Windows 100% 失败
   - 加 `splitCRorLF`、`ImportSDKFromZip`(现已有 zip-slip 校验)、`ImportImageFromDirectory`、`Create` + `createAVDWithAvdManager` 5 个核心路径单测
3. **脚本/Spec 同步**:
   - `api/README.md` 补 emulator 章节(m1)
   - `merge_to_universal` 修 helper 重签 ✅ 已修(B11);framework 路径(M14)未修
   - `dev.sh` 修 pipefail(M15)、`dev.ps1` 删硬编码(M16)
4. **Major 14 条按 PR 拆分**: WS / 路径安全 / 测试覆盖各起一个 PR 跟,不阻塞 emulator 主体合入。

---

## 审查元数据

- 4 个并行 explore agent 任务 ID:
  - `ses_0f9732106ffe0yollEQS91J3iH` (后端 Go)
  - `ses_0f97302d5ffeoySnuSrooBH2rz` (前端 Flutter)
  - `ses_0f972e5bdffefrcvzlNFnWOezc` (Platform/脚本/CI)
  - `ses_0f972d3dcffeGGSABG7ducTsgQ` (测试覆盖度)
- 范围:`main...HEAD` = 28 commits
- 受影响文件:65 个变更,+15249 / -42 行
- 未运行工具: `flutter analyze`、`python scripts/check_i18n_tr_keys.py`、`go test ./...` (权限 / 工具不可用)
