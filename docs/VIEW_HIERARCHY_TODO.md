# View Hierarchy 后续功能规划

本文记录 View Hierarchy 调试页面已完成优化与尚未实现的调试点。
当前分支 `feat/view-hierarchy` 已经做的优化见 git log，不再重复。

## 一、剩余调试点（按价值排序）

> 这些项目已全部完成，详见文末第三章“后续完成的增强”。
> 以下原始描述保留为历史参考。

### ~~1. 反向选中（点击截图 → 选中节点）~~ ~~已完成~~

**原始目标**：在截图区域点击某点，自动找到 dump 坐标空间中**包含该点、面积最小**的节点，选中它并在树面板滚动到该行。

**实际实现**
- 截图区域包一层 `GestureDetector`，`onTapUp` 拿到 `localPosition`。
- 因 GestureDetector 位于 `InteractiveViewer` 内部，Flutter 命中测试已经反变换过用户的 pan/zoom，`localPosition` 就是 child 自身坐标系（canvas 空间）。只需 `localPosition / scale` 得到 dump 坐标——再 `toScene()` 会双重反变换算错。
- 遍历 `<hierarchy>` 整棵树，筛选 `bounds != null && bounds.contains(point)`，按面积升序取最小，**优先 clickable 节点**。逻辑提为 `ViewNode.hitTest` 静态方法，单测覆盖三类场景。
- 选中后调 `_selectAndReveal`：展开所有祖先 → 复用 post-frame `Scrollable.ensureVisible` 让该行可见。

### ~~2. 节点操作按钮~~ ~~已完成（不含 scroll-to）~~

**实际实现**
- 选中节点后，在截图面板底部居中弹出 Material 工具条：
  - **Tap** —— 走现有 `/api/adb-exec`（`AdbCommandApi.executeAdbCommand`），args = `["shell","input","tap","<cx>","<cy>"]`, cx/cy 取 bounds 中心整数。
  - **Long press** —— `["shell","input","swipe","<cx>","<cy>","<cx>","<cy>","1000"]`。
  - **输入文本** —— `AlertDialog + TextField`，写入时把空格替换为 `%s`（`adb shell input text` 的标准转义）。
  - **复制 resource-id** —— `Clipboard.setData`，再 SnackBar。
  - **复制 XPath** —— `ViewNode.toXPath()` 生成 `//node[@resource-id=\"…\" and @bounds=\"…\"]` 或 class+bounds 回退。
- **未实现**：原 proposal 提的 **scroll-to**（依赖 `uiautomator scroll-to` 命令在标准 Android 上不存在，且当前没用 UiAutomator2 helper）以及“走剪贴板辅助 APK” 复制 path（桌面端 `Clipboard.setData` 已经够用）。
- **未做后端新接口**：因为 `/api/adb-exec` 已经过 dangerous-command guard + DeviceOffline 保护，没有动力为 view-hierarchy 加专用 endpoint。让 view-hierarchy 走通用 adb-exec 与现有 `setShowTouches` 一致。

### ~~3. 过滤 / 搜索~~ ~~已完成~~

**实际实现**
- 树面板上方加 `TextField`（`onChanged -> _onQueryChanged`），右侧带 clear 按钮。
- `ViewNode.matchesQuery` 按小写子串匹配 text/content-desc/resource-id/class。提为公开 API，配单测。
- `_flattenVisible` 改为双路径：query 为空时维持原 `_expanded` 行为；非空时先收集 matched 节点 + `ViewNode.ancestorChain` 求并集 `shown`，再按这个 set 递归扁平化。每个 `_FlatRow` 多带一个 `matches` 标志，行 widget 用 `Opacity` 给不匹配的变灰（保留 ancestor 链上的结构可读性）。
- Toolbar 节点数文案：query 为空 → “N 个节点”；query 非空 → “N 个节点 · M 个匹配”。

## 二、已完成的优化（本轮 commit）

- 后端 `uiautomator dump` + `pull` + 读盘合并成单次 `exec-out … cat …`，省一次 adb 往返。
- 后端 XML 解析补 `resource-id` / `instance` 属性，前端 model 跟进，`displayName` 优先用 resource-id 末段 —— 解决"很多都叫 ViewGroup"问题。
- 后端返回 `rotation`，用于截图旋转对齐 —— 横屏 / 系统截图方向不匹配时位置不再错。
- `decodeUTF16XML` 简化为 `string(utf16.Decode(runes))`，省一次逐 rune AppendRune 拷贝。
- 前端 model `bounds` getter 缓存 `Rect?`，避免每次 build 重跑 RegExp。
- 前端树面板由递归嵌套 `Column` 改为 `_FlatRow` 扁平化 + `ListView.builder`，大节点树不再全量构建 Widget；树行 widget 数从节点数级降到屏幕可见行数级。
- 前端节点数 `_countNodes` 结果缓存到 `_cachedNodeCount`。
- 前端 `_buildBoundsOverlays` 原来递归整棵树只为画一个选中框，改为直接用 `_selectedNode.bounds` 画单框。
- 前端截图面板从 `SingleChildScrollView` 改为 `InteractiveViewer`，支持平移缩放，便于看清滚出屏外的节点 bounds（NestedScrollView 顶部 item、CoordinatorLayout AppBar）。
- 前端 toolbar 加"重新截图"按钮（强制刷新，防止旧截图与当前 dump 不一致），显示当前 rotation 角度。
- 截图 overlay 改为画在 dump 坐标空间，Stack `clipBehavior: Clip.none`，滚动出屏的节点 bounds 仍可见。

## 三、架构债务（不动，记录当警钟）

- 选 ck 自动刷新延迟时长目前固定为 400ms，未来如果用户反映"截图截早了 / 晚了"可以考虑按命令类型（tap / swipe / text）分别调，或暴露一个可配置项。
- `lib/screens/view_hierarchy_screen.dart` 现 816 行，已超过原 ~650 行的拆分阈值。下一个明确触发再加（新增调用、新增节点操作、要求把树面板/截图面板拆出来给其它 screen 复用）：
  - 提一个 `widgets/view_hierarchy_tree.dart` 把 tree panel 拆出去
  - 提一个 `widgets/view_hierarchy_inspector.dart` 把 screenshot overlay 拆出去
- "反向选中"或"节点操作按钮"要加更多状态时，应优先考虑把 `_selectedNode` / `_screenshot*` 抽成一个轻量 `ValueNotifier<ViewNode?>` 而不是继续撑 State —— State 重建会触发整个 ListView 重新 dispose/build，对滚动干涉大。

## 四、后续完成的增强（本轮 commit）

实现以上三点后，文件从 ~510 行涨到 816 行。具体决策：

- 未拆 `view_hierarchy_tree.dart` / `view_hierarchy_inspector.dart` —— 工具条、搜索框、节点 tile、overlay 都是有 stateful 切片，但有 `_xformController` / `_treeScroll` / `_searchCtrl` / `_selectedRowKey` 4 个 controller 同生共死，拆出去彼此之间还要加接缝。等下一个明确触发再加。
- `_FlatRow` 增加 `matches` 字段，而不是另起 `Set<ViewNode> _matchMask` 在 widget 层查 —— `_FlatRow` 已经是 row→node 的唯一携带者，对齐字段更简单。
- 反向选中 / hit-test / XPath 构造逻辑全部下沉到 `ViewNode` 静态方法或 getter，配单测 `test/view_node_test.dart`（14 用例）覆盖：`matchesQuery`（5）/ `hitTest`（3）/ `ancestorChain`（3）/ `toXPath`（3）。screen 层不做坐标计算，纯做交互与 UI 反馈。
- 通用 `AdbCommandApi.executeAdbCommand` 复用现有 `/api/adb-exec` 危险命令守卫 + DeviceOffline 保护，不引后端新接口。与 `setShowTouches` 路径一致。
- **tap / long-press / text 操作后自动 refresh**：复用新加的 `_runAdbAndRefresh` helper —— 命令回来 400ms 后自动重新 dump 树 + 截图，令红框与截图同新状态。copy resource-id / XPath 不走 refresh 路径，保持纯剪贴板行为。如果某 app 转场动画超 400ms，用户仍可手动点 toolbar 的"刷新"按钮。