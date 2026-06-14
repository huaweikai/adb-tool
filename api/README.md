# ADB Tool API 响应协议

后端 JSON API 统一使用响应 envelope。客户端先根据 HTTP 状态判断请求是否成功，再读取 JSON 里的 `ok` 和 `data`。

## 通用 JSON 响应

成功响应：

```json
{
  "ok": true,
  "data": {}
}
```

失败响应：

```json
{
  "ok": false,
  "data": null,
  "error": "serial required"
}
```

字段含义：

- `ok`：接口业务处理是否成功。成功为 `true`，失败为 `false`。
- `data`：接口业务数据。不同接口的字段不同；失败时通常为 `null`，部分接口会带上可用于展示或诊断的补充字段。
- `error`：失败原因。`ok=false` 时给前端展示或记录；`ok=true` 时通常省略。

HTTP 状态码含义：

- `200`：接口成功，且 `ok=true`。
- `400`：请求参数错误、ADB 命令执行失败、安装失败等可预期业务错误。
- `403`：请求来源不允许，例如关停接口不是本机回环地址。
- `405`：请求方法错误，例如要求 `POST` 的接口使用了其他方法。
- `409`：当前状态冲突，例如正在录屏时再次开始录屏。
- `499`：客户端主动取消上传、下载或安装。
- `500`：后端或 ADB 执行过程中出现未归类错误。

## 非 JSON 成功响应例外

以下接口成功时直接返回二进制内容，不包 envelope：

- `GET /api/screenshot`：返回 `image/png`。
- `GET /api/pull-file`：返回 `application/octet-stream`，通过 `Content-Disposition` 附带文件名。
- `GET /api/screen-record-video`：返回 `video/mp4`。

这些接口失败时仍返回统一 JSON 错误 envelope。

`/ws/logs` 是 WebSocket 接口，不使用 HTTP JSON envelope。连接建立后的消息仍按 WebSocket 消息格式传输。

## 主要接口 data 字段

### 设备与基础信息

`GET /api/devices`

`data` 是设备数组：

- `serial`：设备序列号或无线连接地址。
- `state`：ADB 设备状态，例如 `device`、`offline`、`unauthorized`。
- `model`：设备型号。
- `brand`：设备品牌。
- `sdk`：Android SDK 版本。

`GET /api/adb-path`

- `path`：当前后端使用的 ADB 可执行文件路径。

`GET /api/info`

- `props`：设备 `getprop` 原始输出文本。

`GET /api/device-detail`

- `props`：设备属性键值表，来源于 `getprop`。

`POST /api/shutdown`

- `status`：固定为 `shutting down`，表示后端已接受关停请求。

`GET /api/identify`

- `name`：后端服务名称。
- `pid`：后端进程 ID。
- `started`：后端启动时间，RFC3339 格式。

### Logcat 与进程

`GET /api/clear`

- `status`：固定为 `ok`。

`GET /api/package-pid`

- `pid`：指定包名对应的进程 ID。

失败时 `data.pid` 可能为空字符串。

`GET /api/running-packages`

- `packages`：当前运行中的包名数组。

失败时 `data.packages` 可能为空数组。

### 文件管理

`GET /api/files`

- `files`：文件条目数组。

文件条目字段：

- `name`：文件名。
- `path`：设备端完整路径。
- `size`：文件大小，单位字节。
- `isDir`：是否为目录。符号链接目前也按可进入项处理。
- `permissions`：`ls -la` 输出里的权限字符串。
- `modified`：修改时间文本。

`GET /api/file-content`

- `content`：文本文件内容。

`POST /api/push-file`

- `status`：固定为 `ok`。

`POST /api/file-delete`

- `status`：固定为 `ok`。

`POST /api/file-rename`

- `status`：固定为 `ok`。

`POST /api/file-mkdir`

- `status`：固定为 `ok`。

`POST /api/file-touch`

- `status`：固定为 `ok`。

`GET /api/file-stat`

- `stat`：单个文件或目录的详情。

`stat` 字段：

- `name`：文件名。
- `path`：设备端完整路径。
- `size`：文件大小，单位字节。
- `isDir`：是否为目录。
- `permissions`：权限字符串。
- `modified`：修改时间文本。
- `raw`：原始 `ls -ld` 输出，便于排查解析问题。

### 应用管理

`GET /api/packages`

- `packages`：已安装应用数组。

应用字段：

- `packageName`：包名。
- `sourceDir`：APK 安装路径；部分设备或降级命令下可能为空。

`POST /api/uninstall-package`

- `status`：固定为 `ok`。

`POST /api/install-package`

成功时：

- `status`：固定为 `ok`。
- `output`：ADB install 原始输出。

失败时：

- `error`：转换后的安装失败原因，适合直接展示。
- `data.raw`：ADB install 原始输出。

### ADB 命令与无线 ADB

`POST /api/adb-exec`

成功时 `data`：

- `ok`：命令是否成功。
- `output`：ADB 原始输出。

失败时：

- `error`：失败原因。
- `data.ok`：固定为 `false`。
- `data.output`：失败时的 ADB 原始输出。

`POST /api/adb-wireless-pair`

- `ok`：配对命令是否成功。
- `output`：ADB 原始输出。

`POST /api/adb-wireless-connect`

- `ok`：连接命令是否成功。
- `output`：ADB 原始输出。

`POST /api/adb-wireless-disconnect`

- `ok`：断开命令是否成功。
- `output`：ADB 原始输出。

### 后端日志

`GET /api/backend-logs`

- `logs`：后端 ADB 执行日志数组。

日志条目字段由后端日志结构决定，通常包含命令、输出、错误和耗时等信息。

### 剪贴板助手

`GET /api/clipboard-check`

- `installed`：剪贴板助手是否已安装。

`POST /api/clipboard-install`

- `status`：固定为 `ok`。

`POST /api/clipboard-send`

- `status`：固定为 `ok`。

`POST /api/clipboard-uninstall`

- `status`：固定为 `ok`。

### 录屏

`GET /api/screen-record?action=start`

- `status`：固定为 `recording`。
- `serial`：正在录屏的设备序列号。

`GET /api/screen-record?action=stop`

- `status`：固定为 `stopped`。
- `elapsed`：录屏持续时间，单位秒。

`GET /api/screen-record?action=status`

未录屏时：

- `recording`：`false`。

正在录屏时：

- `recording`：`true`。
- `serial`：正在录屏的设备序列号。
- `elapsed`：当前已录制时间，单位秒。
