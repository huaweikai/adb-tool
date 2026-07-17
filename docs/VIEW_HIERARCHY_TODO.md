# View Hierarchy 后续功能规划

本文记录 View Hierarchy 调试页面已完成优化与尚未实现的调试点。
当前分支 `feat/view-hierarchy` 已经做的优化见 git log，不再重复。

## 一、剩余调试点（按价值排序）

### 1. 反向选中（点击截图 → 选中节点）

**当前问题**：只能在左侧树面板点击节点选中，截图只读。
**目标**：在截图区域点击某点，自动找到 dump 坐标空间中**包含该点、面积最小**的节点，选中它并在树面板滚动到该行。

**实现要点**
- 截图区域包一层 `GestureDetector`，`onTapUp` 拿到 `localPosition`。
- 把屏幕坐标换回到 dump 坐标：`dumpX = (localX - canvasOffsetX) / scale`，其中 `scale` 是 `_buildScreenshotPanel` 里算出的缩放比，`canvasOffsetX` 是 `InteractiveViewer` 平移后的偏移（可从 `TransformationController` 取）。
- 遍历 `<hierarchy>` 整棵树，筛选 `bounds != null && bounds.contains(Offset(dumpX, dumpY))`，按面积升序取第一个；优先 `clickable == true` 的节点更符合用户直觉。
- 选中后调用树面板的 `ScrollController.ensureVisible`，让该行可见。

**复杂度**：单次树遍历，节点上千也只需几毫秒。

### 2. 节点操作按钮

**目标**：选中节点后，在右下角弹出工具条，提供：
- **Tap** —— 后端 `adb shell input tap <cx> <cy>`，cx/cy 取 bounds 中心
- **Long press** —— `adb shell input swipe <x> <y> <x> <y> 1000`
- **输入文本** —— 弹输入框，`adb shell input text "<escaped>"`
- **滚动到可见** —— `adb shell uiautomator scroll-to <resource-id>` 或 swip
- **复制 resource-id** —— 走剪贴板辅助 APK 写入
- **复制 XPath** —— 形如 `//node[@resource-id=\"…\" and @bounds=\"…\"]`

**后端新接口**
```
POST /api/view-hierarchy/action?serial=…  body: {type, target}
  type ∈ {tap, long-press, text, scroll-to}
  target 可选；tap/long-press 用 bounds 中心，text 接 body.text
```

### 3. 过滤 / 搜索

**当前问题**：节点上百后左侧树很难找。
**目标**：在 toolbar 加搜索框，输入关键词后：
- 按 `resource-id` / `text` / `content-desc` / `class` 子串匹配
- 不匹配的行变灰低亮，匹配的行展开父链
- 节点数显示改为"N 个 · M 个匹配"

**实现**：搜索时把可见行列表赋值成 "匹配 + 匹配行祖先链"，其余折叠。可以复用 `_rowsCache` 机制，加一个 `_query` 字段触发重建。

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

- `lib/screens/view_hierarchy_screen.dart` 约 510 行，离 "60K + 新功能不属独立 widget" 的拆分阈值还有距离。第三步"过滤搜索"加上去后估计到 ~650 行，那时再考虑：
  - 提一个 `widgets/view_hierarchy_tree.dart` 把 tree panel 拆出去
  - 提一个 `widgets/view_hierarchy_inspector.dart` 把 screenshot overlay 拆出去
- "反向选中"或"节点操作按钮"要加更多状态时，应优先考虑把 `_selectedNode` / `_screenshot*` 抽成一个轻量 `ValueNotifier<ViewNode?>` 而不是继续撑 State —— State 重建会触发整个 ListView 重新 dispose/build，对滚动干涉大。