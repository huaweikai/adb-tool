// Emulator module i18n.
//
// Covers all user-facing strings in:
//   - lib/screens/emulator_settings_screen.dart
//   - lib/widgets/emulator_engine_card.dart
//   - lib/widgets/emulator_image_card.dart
//   - lib/widgets/emulator_instance_card.dart
//   - lib/widgets/emulator_java_card.dart
//   - lib/widgets/add_image_dialog.dart
//   - lib/widgets/cleanup_cache_dialog.dart
//
// Code-review item B9: emulator modules shipped with hard-coded Chinese
// Text()/Tooltip()/label: strings, bypassing the i18n scaffolding entirely.
// This file plus the edits in those modules bring them under the standard
// tr()/setLang() flow.
//
// Key naming: <module>.<element>.<when>. Module is the widget/file; element
// is the UI piece; `when` is an optional sub-state (e.g. downloadError
// vs downloadDone vs downloadPreparing). Interpolation uses {name}
// placeholders that `tr()` substitutes via the args map.
part of 'package:adb_tool/i18n.dart';

const _locEmulatorZh = <String, String>{
  // ── screens/emulator_settings_screen.dart ────────────────────────────
  'emulatorSettings.title': 'Android 模拟器',
  'emulatorSettings.cleanupTooltip':
      '清理所有 adb-tool 缓存(SDK 保留)',
  'emulatorSettings.instanceSection': '模拟器实例',
  'emulatorSettings.installEmulatorHint':
      '请先在上方 SDK 引擎卡片中安装 emulator + system-image',
  'emulatorSettings.createInstance': '创建实例',
  'emulatorSettings.emptyInstance': '暂无模拟器实例',
  'emulatorSettings.emptyInstanceHint': '创建实例以开始使用模拟器',
  'emulatorSettings.imageSection': '系统镜像',
  'emulatorSettings.addImage': '添加镜像',
  'emulatorSettings.emptyImage': '暂无系统镜像',
  'emulatorSettings.emptyImageHint': '点击上方按钮添加镜像',
  'emulatorSettings.install.downloadError':
      '下载失败: {error}',
  'emulatorSettings.install.downloadDone': '{pkg} 下载完成',
  'emulatorSettings.install.downloadPreparing': '正在准备...',
  'emulatorSettings.import.success': '镜像导入成功',
  'emulatorSettings.import.failure':
      '镜像导入失败: {error}',
  'emulatorSettings.install.kickoff': '开始下载: {package}',
  'emulatorSettings.install.kickoffError': '启动下载失败: {error}',
  'emulatorSettings.install.completed': '镜像安装完成: {package}',
  'emulatorSettings.install.failed':
      '镜像下载失败: {error}',
  'emulatorSettings.common.unknownError': '未知错误',
  'emulatorSettings.delete.titleManaged': '删除镜像文件',
  'emulatorSettings.delete.titleRegistryOnly': '移除镜像记录',
  'emulatorSettings.delete.bodyManaged':
      '此镜像位于 adb-tool 管理目录下，确认后会永久删除磁盘文件。\n'
      '{name}\n'
      '{sizeLine}'
      '{pathLine}'
      '此操作不可恢复。',
  'emulatorSettings.delete.bodyRegistryOnly':
      '此镜像不在 adb-tool 管理目录下，确认后只会从 images.json 中移除记录，不会删除磁盘文件。\n'
      '{name}\n'
      '{pathLine}',
  'emulatorSettings.delete.sizeLine': '占用空间：{size}\n',
  'emulatorSettings.delete.pathLine': '路径：{path}\n',
  'emulatorSettings.delete.pathLineNoNl': '路径：{path}',
  'emulatorSettings.delete.cancel': '取消',
  'emulatorSettings.delete.confirmManaged': '删除文件',
  'emulatorSettings.delete.confirmRegistryOnly': '移除记录',
  'emulatorSettings.delete.inUse':
      '无法删除：以下实例正在使用此镜像{users}，请先删除实例',
  'emulatorSettings.delete.failure': '删除失败：{error}',

  // ── widgets/emulator_engine_card.dart ───────────────────────────────
  'engineCard.selectedSDKInvalid':
      '上次选择的 SDK 已失效，请重新选择或扫描',
  'engineCard.noSDKConfigured': '尚未配置 SDK',
  'engineCard.pathCopied': '路径已复制',
  'engineCard.copyPath': '复制路径',
  'engineCard.emulatorInstalled': 'Emulator {version}',
  'engineCard.emulatorMissing': 'Emulator (未安装)',
  'engineCard.installFailed': '下载失败',
  'engineCard.retry': '重试',
  'engineCard.installCompleted': 'emulator 已安装，正在刷新状态...',
  'engineCard.installEmulator': '下载 emulator',
  'engineCard.installEmulatorViaSdkmanager':
      '使用 sdkmanager 下载 emulator（含 qemu）',
  'engineCard.installEmulatorNeedsCmdline':
      '需要先安装 cmdline-tools 才能下载 emulator',
  'engineCard.status.processing': '处理中',
  'engineCard.status.ready': '就绪',
  'engineCard.status.partialReady': '部分就绪',
  'engineCard.status.notConfigured': '未配置',
  'engineCard.action.scan': '扫描检测',
  'engineCard.action.pickPath': '选择路径',
  'engineCard.action.downloadSDK': '下载 SDK',
  'engineCard.action.importZip': '导入压缩包',
  'engineCard.status.processingDots': '处理中...',
  'engineCard.scanTitle': '扫描说明',
  'engineCard.scanIntro': '将扫描以下位置查找 Android SDK：',
  'engineCard.scanLoc1': 'Android Studio 默认路径',
  'engineCard.scanLoc2': '外置硬盘（如有）',
  'engineCard.scanLoc3': '我们管理的 SDK（如有）',
  'engineCard.scanLoc4': '环境变量路径',
  'engineCard.scanning': '扫描中...',
  'engineCard.startScan': '开始扫描',
  'engineCard.rescan': '重新扫描',
  'engineCard.scanHint': '点击上方按钮扫描系统中的 SDK',
  'engineCard.scanningDots': '正在扫描...',
  'engineCard.scanResultCount': '扫描结果（{count} 个）',
  'engineCard.inUse': '使用中',
  'engineCard.useThisSDK': '使用此 SDK',
  'engineCard.useThisSDKNoEmulator': '使用此 SDK（需安装 emulator）',
  'engineCard.invalidSDKDir':
      '此目录既没有 emulator 也没有 avdmanager，不是有效的 Android SDK',
  'engineCard.unavailable': '不可用',
  'engineCard.manualPickTitle': '手动输入 SDK 路径',
  'engineCard.browse': '浏览',
  'engineCard.pathHint': '输入 Android SDK 根目录路径',
  'engineCard.useThisPath': '使用此路径',
  'engineCard.whereIsIt': '不知道在哪？',
  'engineCard.downloadSDKTitle': '下载 Android SDK',
  'engineCard.officialPage': '官方下载页面',
  'engineCard.urlHint': '输入 SDK 下载 URL',
  'engineCard.urlHelp':
      '从 Android 开发者官网下载 Command Line Tools 后粘贴下载链接',
  'engineCard.startDownload': '开始下载',
  'engineCard.zipHint': '输入 SDK 压缩包路径 (.zip)',
  'engineCard.browseZip': '选择 ZIP 文件',
  'engineCard.zipHelp': '解压到 ~/.adb-tool/sdk/',
  'engineCard.importingDots': '导入中...',
  'engineCard.startImport': '开始导入',
  'engineCard.debugLogTitle': '调试日志',
  'engineCard.clearLog': '清空',
  'engineCard.testLogEntry': '这是一条测试日志 - {time}',
  'engineCard.detectedPathEntry': '检测到路径: ~/Library/Android/sdk',
  'engineCard.testLog': '测试日志',
  'engineCard.noLog': '暂无日志',
  'engineCard.scanLog.start': '开始扫描...',
  'engineCard.scanLog.found': '检测到 {count} 个 SDK',
  'engineCard.scanLog.failed': '扫描失败: {error}',
  'engineCard.useSDKLog.header': '========== 切换 SDK ==========',
  'engineCard.useSDKLog.target': '目标路径: {path}',
  'engineCard.useSDKLog.request': '发送 POST /api/emulator/sdk/use',
  'engineCard.useSDKLog.response':
      '收到响应: 状态码={code}',
  'engineCard.useSDKLog.responseBody': '响应体: {body}',
  'engineCard.useSDKLog.backendOk': '✅ 后端确认成功!',
  'engineCard.useSDKLog.refresh': '调用 provider.refreshStatus()...',
  'engineCard.useSDKLog.refreshDone': '✅ refreshStatus 完成',
  'engineCard.useSDKLog.stateNow': '当前 engine 状态:',
  'engineCard.useSDKLog.switched': '已切换到: {path}',
  'engineCard.useSDKLog.backendFailed':
      '❌ 后端返回失败: {error}',
  'engineCard.useSDKLog.done': '========== 切换 SDK 完成 ==========',
  'engineCard.useSDKLog.exception': '❌ 异常: {error}',
  'engineCard.useSDKLog.stack': '堆栈: {stack}',
  'engineCard.installLog.header': '========== 安装 emulator ==========',
  'engineCard.installLog.started': '✅ 启动成功: jobId={id}',
  'engineCard.installLog.completed': '✅ emulator 安装完成',
  'engineCard.installLog.done': 'emulator 安装完成',
  'engineCard.installLog.failed': '❌ 安装失败: {error}',
  'engineCard.installLog.pollException': '轮询异常: {error}',
  'engineCard.installLog.startFailed': '❌ 启动失败: {error}',
  'engineCard.installLog.kickoffFailed': '启动安装失败: {error}',
  'engineCard.downloadLog.needURL': '请输入下载 URL',
  'engineCard.cancelFailed': '取消失败: {error}',
  'engineCard.importLog.needZip': '请输入压缩包路径',
  'engineCard.importLog.fileMissing': '文件不存在: {path}',
  'engineCard.importLog.failedBody': '导入失败: {body}',
  'engineCard.importLog.success': 'SDK 导入成功！',
  'engineCard.importLog.failed': '导入失败: {error}',

  // ── widgets/emulator_image_card.dart ────────────────────────────────
  'imageCard.unknownSize': '未知大小',
  'imageCard.notReady': '镜像不可用',
  'imageCard.delete': '删除',
  'imageCard.downloading': '下载中',
  'imageCard.error': '错误',
  'imageCard.pending': '等待中',

  // ── widgets/emulator_instance_card.dart ─────────────────────────────
  'instanceCard.boot.preparing': '正在准备 emulator…',
  'instanceCard.boot.startingEmulator': '正在启动 emulator…',
  'instanceCard.boot.startingKernel': '正在启动内核…',
  'instanceCard.boot.androidStarting': 'Android 正在启动…',
  'instanceCard.boot.adbConnecting': '正在连接 ADB…',
  'instanceCard.boot.ready': '启动完成',
  'instanceCard.boot.starting': '正在启动…',
  'instanceCard.cancelStart': '取消启动',
  'instanceCard.viewStartLog': '查看启动日志',
  'instanceCard.openInExplorer': '在资源管理器中查看',
  'instanceCard.logLoadFailed': '加载日志失败',
  'instanceCard.logEmpty': '暂无日志输出',
  'instanceCard.close': '关闭',
  'instanceCard.deleted': '实例已删除',
  'instanceCard.noLocalPath': '该实例没有可用的本地路径',
  'instanceCard.pathMissing': '路径不存在: {path}',
  'instanceCard.openFailed': '打开失败: {error}',

  // ── widgets/emulator_java_card.dart ────────────────────────────────
  'javaCard.title': 'Java 运行环境',
  'javaCard.notFound': '未找到',
  'javaCard.detecting': '检测中...',
  'javaCard.unknown': '未知',
  'javaCard.notDetected': '未检测到 Java 运行环境',
  'javaCard.runtimeListPrompt':
      '检测到 {count} 个 Java 运行环境，选择一个使用：',
  'javaCard.downloaded': '已下载',
  'javaCard.unknownVersion': '未知版本',
  'javaCard.selectedInvalid':
      '之前选择的 Java 运行环境已失效，请重新选择',
  'javaCard.cancelDownload': '取消下载',
  'javaCard.redetect': '重新检测',
  'javaCard.downloadJava': '下载 Java',
  'javaCard.importZip': '导入 Zip',
  'javaCard.importZipTitle': '导入 Java Zip',
  'javaCard.filePicked': '文件: {name}',
  'javaCard.runtimeID': '运行时 ID',
  'javaCard.runtimeIDHint': '仅允许字母/数字/._-',
  'javaCard.import': '导入',
  'javaCard.importedSnack': '已导入 Java: {id}',
  'javaCard.importFailed': '导入失败: {error}',
  'javaCard.downloadTitle': '下载 Java 运行环境',
  'javaCard.downloadHelp':
      '下载 Eclipse Temurin (Adoptium) - 跨平台官方构建',
  'javaCard.versionLabel': 'Java 版本',
  'javaCard.urlLabel': '下载 URL',
  'javaCard.urlHint': '默认使用 Temurin 镜像，可手动替换',
  'javaCard.sourceLabel': '来源: {name}',
  'javaCard.kickoff': '开始下载 Java {version}...',
  'javaCard.kickoffFailed': '启动下载失败: {error}',

  // ── widgets/add_image_dialog.dart ───────────────────────────────────
  'addImage.tabSDK': 'SDK 下载',
  'addImage.title': '添加系统镜像',
  'addImage.source': '镜像来源',
  'addImage.tabURL': 'URL 下载',
  'addImage.tabLocal': '本地路径',
  'addImage.urlLabel': '镜像下载 URL',
  'addImage.urlHint': '提示: 下载完成后会自动解压到缓存目录，并解析镜像信息',
  'addImage.historyTitle': '历史下载地址',
  'addImage.removeFromHistory': '从历史中移除',
  'addImage.config': '镜像配置',
  'addImage.apiLevel': 'API 级别',
  'addImage.arch': '架构',
  'addImage.variant': '变体',
  'addImage.variantGooglePlay': 'Google Play (推荐)',
  'addImage.variantDefault': 'Default (无 Google 服务)',
  'addImage.sdkHint':
      '提示: 选好后会用 sdkmanager 下载到本地 system-images 目录，\n'
      '完成会自动出现在镜像列表里',
  'addImage.pickFolder': '选择文件夹',
  'addImage.pickZip': '选择 Zip',
  'addImage.folderLabel': '镜像文件夹',
  'addImage.zipLabel': '镜像 Zip 文件',
  'addImage.folderHint': '包含 system.img / config.ini 的目录',
  'addImage.zipFileHint': '系统镜像压缩包 (.zip)',
  'addImage.localHint': '提示: 镜像信息（API 级别、架构、变体）会从所选内容自动探测',
  'addImage.confirm': '添加',
  'addImage.folderPickFailed': '选择文件夹失败: {error}',
  'addImage.filePickFailed': '选择文件失败: {error}',
  'addImage.validator.folder': '请选择镜像文件夹',
  'addImage.validator.zip': '请选择镜像 Zip 文件',

  // ── widgets/cleanup_cache_dialog.dart ───────────────────────────────
  'cleanupCache.cacheRootHint':
      '系统 TempDir 下的 adb-tool-cache(避免每次启动重新解压)',
  'cleanupCache.adbTemp': '录屏、剪贴板、push/pull 临时文件',
  'cleanupCache.emuInstanceLogs': '模拟器实例日志',
  'cleanupCache.emuInstanceLogsPath':
      '~/.adb-tool/emulator/instances/<id>/logs/*.log (AVD 文件保留)',
  'cleanupCache.backendLogs': '后端日志',
  'cleanupCache.backendLogsPath':
      '~/Library/Application Support/ADBTool 或 %APPDATA%\\ADBTool',
  'cleanupCache.flutterDb': 'Flutter 端数据库 + 会话附件',
  'cleanupCache.flutterDbPath':
      '%APPDATA%\\com.example.ADB Tool\\ 等',
  'cleanupCache.flutterEngine': 'Flutter 引擎缓存 (ADBToolData)',
  'cleanupCache.flutterEnginePath':
      '~/ADBToolData 或 flutter_app/ADBToolData (best-effort)',
  'cleanupCache.sdkKeepHint':
      '~/.adb-tool/sdk/  (默认保留 — 重装几 GB 慢)',
  'cleanupCache.avdConfig': 'AVD 配置和磁盘',
  'cleanupCache.title': '清理所有缓存',
  'cleanupCache.intro': '将清理以下位置(白名单内):',
  'cleanupCache.alwaysKeep': '始终保留:',
  'cleanupCache.keepSDK': '保留 Android SDK',
  'cleanupCache.keepSDKHint': '建议勾上(SDK 重装几 GB)',
  'cleanupCache.confirm': '清理',
  'cleanupCache.done': '清理完成',
  'cleanupCache.freed': '已释放 {size} ',
  'cleanupCache.freedCount': '({count} 项)',
  'cleanupCache.skippedHeader':
      '跳过 {count} 项(权限/不存在):',
  'cleanupCache.skippedMore': '... 还有 {count} 项',
  'cleanupCache.cleanupDetail': '清理明细:',
  'cleanupCache.notExists': '不存在',
  'cleanupCache.sdkKept': 'Android SDK 已保留',
  'cleanupCache.close': '完成',

  // ── widgets/mirror_config_card.dart ────────────────────────────────
  'mirror.title': '下载镜像加速',
  'mirror.subtitle': '配置国内镜像源加速 sdkmanager 下载',
  'mirror.label': '镜像地址',
  'mirror.hint': '例如: https://mirrors.cloud.tencent.com/AndroidSDK/',
  'mirror.save': '保存',
  'mirror.saved': '镜像配置已保存',
  'mirror.clear': '清除',
  'mirror.cleared': '镜像配置已清除',
  'mirror.current': '当前镜像',
  'mirror.none': '未配置（使用官方源）',
  'mirror.tencent': '腾讯镜像',
  'mirror.huawei': '华为镜像',
  'mirror.apply': '应用',
  'mirror.quickSelect': '快捷选择:',
  'mirror.proxyHint': '配置后 sdkmanager 会通过镜像代理下载,可加速国内访问',
};

const _locEmulatorEn = <String, String>{
  // ── screens/emulator_settings_screen.dart ────────────────────────────
  'emulatorSettings.title': 'Android Emulator',
  'emulatorSettings.cleanupTooltip':
      'Clean all adb-tool caches (SDK kept)',
  'emulatorSettings.instanceSection': 'Emulator Instances',
  'emulatorSettings.installEmulatorHint':
      'Install emulator + system-image in the SDK Engine card above first',
  'emulatorSettings.createInstance': 'Create Instance',
  'emulatorSettings.emptyInstance': 'No emulator instances yet',
  'emulatorSettings.emptyInstanceHint': 'Create one to start using the emulator',
  'emulatorSettings.imageSection': 'System Images',
  'emulatorSettings.addImage': 'Add Image',
  'emulatorSettings.emptyImage': 'No system images',
  'emulatorSettings.emptyImageHint': 'Tap the button above to add one',
  'emulatorSettings.install.downloadError':
      'Download failed: {error}',
  'emulatorSettings.install.downloadDone': '{pkg} download complete',
  'emulatorSettings.install.downloadPreparing': 'Preparing…',
  'emulatorSettings.import.success': 'Image imported',
  'emulatorSettings.import.failure':
      'Image import failed: {error}',
  'emulatorSettings.install.kickoff': 'Starting download: {package}',
  'emulatorSettings.install.kickoffError':
      'Failed to start download: {error}',
  'emulatorSettings.install.completed':
      'Image installed: {package}',
  'emulatorSettings.install.failed':
      'Image download failed: {error}',
  'emulatorSettings.common.unknownError': 'Unknown error',
  'emulatorSettings.delete.titleManaged': 'Delete image files',
  'emulatorSettings.delete.titleRegistryOnly': 'Remove image record',
  'emulatorSettings.delete.bodyManaged':
      'This image lives under adb-tool\'s managed directory — confirming will permanently delete the disk files.\n'
      '{name}\n'
      '{sizeLine}'
      '{pathLine}'
      'This cannot be undone.',
  'emulatorSettings.delete.bodyRegistryOnly':
      'This image is outside adb-tool\'s managed directory — only the images.json record will be removed; disk files are untouched.\n'
      '{name}\n'
      '{pathLine}',
  'emulatorSettings.delete.sizeLine': 'Disk usage: {size}\n',
  'emulatorSettings.delete.pathLine': 'Path: {path}\n',
  'emulatorSettings.delete.pathLineNoNl': 'Path: {path}',
  'emulatorSettings.delete.cancel': 'Cancel',
  'emulatorSettings.delete.confirmManaged': 'Delete files',
  'emulatorSettings.delete.confirmRegistryOnly': 'Remove record',
  'emulatorSettings.delete.inUse':
      'Cannot delete: these instances are using this image{users}. Delete the instances first.',
  'emulatorSettings.delete.failure': 'Delete failed: {error}',

  // ── widgets/emulator_engine_card.dart ───────────────────────────────
  'engineCard.selectedSDKInvalid':
      'Previous SDK selection is invalid, please pick or scan again',
  'engineCard.noSDKConfigured': 'No SDK configured',
  'engineCard.pathCopied': 'Path copied',
  'engineCard.copyPath': 'Copy path',
  'engineCard.emulatorInstalled': 'Emulator {version}',
  'engineCard.emulatorMissing': 'Emulator (not installed)',
  'engineCard.installFailed': 'Install failed',
  'engineCard.retry': 'Retry',
  'engineCard.installCompleted': 'Emulator installed, refreshing status…',
  'engineCard.installEmulator': 'Install emulator',
  'engineCard.installEmulatorViaSdkmanager':
      'Use sdkmanager to install emulator (with qemu)',
  'engineCard.installEmulatorNeedsCmdline':
      'cmdline-tools required before installing emulator',
  'engineCard.status.processing': 'Processing',
  'engineCard.status.ready': 'Ready',
  'engineCard.status.partialReady': 'Partial',
  'engineCard.status.notConfigured': 'Not set',
  'engineCard.action.scan': 'Scan',
  'engineCard.action.pickPath': 'Pick path',
  'engineCard.action.downloadSDK': 'Download SDK',
  'engineCard.action.importZip': 'Import zip',
  'engineCard.status.processingDots': 'Processing…',
  'engineCard.scanTitle': 'Scan notes',
  'engineCard.scanIntro':
      'Will scan these locations to find an Android SDK:',
  'engineCard.scanLoc1': 'Android Studio default path',
  'engineCard.scanLoc2': 'External drive (if any)',
  'engineCard.scanLoc3': 'Our managed SDK (if any)',
  'engineCard.scanLoc4': 'Environment variables',
  'engineCard.scanning': 'Scanning…',
  'engineCard.startScan': 'Start scan',
  'engineCard.rescan': 'Rescan',
  'engineCard.scanHint': 'Tap the button above to scan for an SDK',
  'engineCard.scanningDots': 'Scanning…',
  'engineCard.scanResultCount': 'Scan results ({count})',
  'engineCard.inUse': 'In use',
  'engineCard.useThisSDK': 'Use this SDK',
  'engineCard.useThisSDKNoEmulator':
      'Use this SDK (emulator still needs installing)',
  'engineCard.invalidSDKDir':
      'Neither emulator nor avdmanager found here — not a valid Android SDK',
  'engineCard.unavailable': 'Unavailable',
  'engineCard.manualPickTitle': 'Enter SDK path manually',
  'engineCard.browse': 'Browse',
  'engineCard.pathHint': 'Enter the Android SDK root path',
  'engineCard.useThisPath': 'Use this path',
  'engineCard.whereIsIt': 'Where is it?',
  'engineCard.downloadSDKTitle': 'Download Android SDK',
  'engineCard.officialPage': 'Official download page',
  'engineCard.urlHint': 'Enter SDK download URL',
  'engineCard.urlHelp':
      'Download Command Line Tools from the Android dev site, then paste the download link',
  'engineCard.startDownload': 'Start download',
  'engineCard.zipHint': 'Enter SDK zip path (.zip)',
  'engineCard.browseZip': 'Browse ZIP file',
  'engineCard.zipHelp': 'Extracts into ~/.adb-tool/sdk/',
  'engineCard.importingDots': 'Importing…',
  'engineCard.startImport': 'Start import',
  'engineCard.debugLogTitle': 'Debug log',
  'engineCard.clearLog': 'Clear',
  'engineCard.testLogEntry': 'This is a test log - {time}',
  'engineCard.detectedPathEntry': 'Detected path: ~/Library/Android/sdk',
  'engineCard.testLog': 'Test log',
  'engineCard.noLog': 'No log yet',
  'engineCard.scanLog.start': 'Scanning…',
  'engineCard.scanLog.found': 'Found {count} SDK(s)',
  'engineCard.scanLog.failed': 'Scan failed: {error}',
  'engineCard.useSDKLog.header': '========== Switch SDK ==========',
  'engineCard.useSDKLog.target': 'Target path: {path}',
  'engineCard.useSDKLog.request': 'POST /api/emulator/sdk/use',
  'engineCard.useSDKLog.response':
      'Response: status={code}',
  'engineCard.useSDKLog.responseBody': 'Body: {body}',
  'engineCard.useSDKLog.backendOk': '✅ Backend confirmed!',
  'engineCard.useSDKLog.refresh': 'Calling provider.refreshStatus()…',
  'engineCard.useSDKLog.refreshDone': '✅ refreshStatus done',
  'engineCard.useSDKLog.stateNow': 'Current engine state:',
  'engineCard.useSDKLog.switched': 'Switched to: {path}',
  'engineCard.useSDKLog.backendFailed':
      '❌ Backend returned failure: {error}',
  'engineCard.useSDKLog.done': '========== Switch SDK done ==========',
  'engineCard.useSDKLog.exception': '❌ Exception: {error}',
  'engineCard.useSDKLog.stack': 'Stack: {stack}',
  'engineCard.installLog.header': '========== Install emulator ==========',
  'engineCard.installLog.started': '✅ Started: jobId={id}',
  'engineCard.installLog.completed': '✅ Emulator installed',
  'engineCard.installLog.done': 'Emulator installed',
  'engineCard.installLog.failed': '❌ Install failed: {error}',
  'engineCard.installLog.pollException': 'Poll exception: {error}',
  'engineCard.installLog.startFailed': '❌ Start failed: {error}',
  'engineCard.installLog.kickoffFailed':
      'Failed to start install: {error}',
  'engineCard.downloadLog.needURL': 'Enter download URL',
  'engineCard.cancelFailed': 'Cancel failed: {error}',
  'engineCard.importLog.needZip': 'Enter zip path',
  'engineCard.importLog.fileMissing': 'File does not exist: {path}',
  'engineCard.importLog.failedBody': 'Import failed: {body}',
  'engineCard.importLog.success': 'SDK imported!',
  'engineCard.importLog.failed': 'Import failed: {error}',

  // ── widgets/emulator_image_card.dart ────────────────────────────────
  'imageCard.unknownSize': 'Unknown size',
  'imageCard.notReady': 'Image unavailable',
  'imageCard.delete': 'Delete',
  'imageCard.downloading': 'Downloading',
  'imageCard.error': 'Error',
  'imageCard.pending': 'Pending',

  // ── widgets/emulator_instance_card.dart ─────────────────────────────
  'instanceCard.boot.preparing': 'Preparing emulator…',
  'instanceCard.boot.startingEmulator': 'Starting emulator…',
  'instanceCard.boot.startingKernel': 'Starting kernel…',
  'instanceCard.boot.androidStarting': 'Android starting…',
  'instanceCard.boot.adbConnecting': 'Connecting ADB…',
  'instanceCard.boot.ready': 'Ready',
  'instanceCard.boot.starting': 'Starting…',
  'instanceCard.cancelStart': 'Cancel start',
  'instanceCard.viewStartLog': 'View start log',
  'instanceCard.openInExplorer': 'Show in file manager',
  'instanceCard.logLoadFailed': 'Failed to load log',
  'instanceCard.logEmpty': 'No log output',
  'instanceCard.close': 'Close',
  'instanceCard.deleted': 'Instance deleted',
  'instanceCard.noLocalPath': 'No local path available for this instance',
  'instanceCard.pathMissing': 'Path does not exist: {path}',
  'instanceCard.openFailed': 'Open failed: {error}',

  // ── widgets/emulator_java_card.dart ────────────────────────────────
  'javaCard.title': 'Java Runtime',
  'javaCard.notFound': 'Not found',
  'javaCard.detecting': 'Detecting…',
  'javaCard.unknown': 'Unknown',
  'javaCard.notDetected': 'No Java runtime detected',
  'javaCard.runtimeListPrompt':
      '{count} Java runtime(s) detected — pick one to use:',
  'javaCard.downloaded': 'Downloaded',
  'javaCard.unknownVersion': 'Unknown version',
  'javaCard.selectedInvalid':
      'Previously selected Java runtime is invalid, pick another',
  'javaCard.cancelDownload': 'Cancel download',
  'javaCard.redetect': 'Re-detect',
  'javaCard.downloadJava': 'Download Java',
  'javaCard.importZip': 'Import Zip',
  'javaCard.importZipTitle': 'Import Java Zip',
  'javaCard.filePicked': 'File: {name}',
  'javaCard.runtimeID': 'Runtime ID',
  'javaCard.runtimeIDHint': 'Letters/digits/._- only',
  'javaCard.import': 'Import',
  'javaCard.importedSnack': 'Imported Java: {id}',
  'javaCard.importFailed': 'Import failed: {error}',
  'javaCard.downloadTitle': 'Download Java runtime',
  'javaCard.downloadHelp':
      'Download Eclipse Temurin (Adoptium) — cross-platform official build',
  'javaCard.versionLabel': 'Java version',
  'javaCard.urlLabel': 'Download URL',
  'javaCard.urlHint': 'Default Temurin mirror, edit if needed',
  'javaCard.sourceLabel': 'Source: {name}',
  'javaCard.kickoff': 'Starting download of Java {version}…',
  'javaCard.kickoffFailed': 'Failed to start download: {error}',

  // ── widgets/add_image_dialog.dart ───────────────────────────────────
  'addImage.tabSDK': 'SDK',
  'addImage.title': 'Add system image',
  'addImage.source': 'Image source',
  'addImage.tabURL': 'URL',
  'addImage.tabLocal': 'Local path',
  'addImage.urlLabel': 'Image download URL',
  'addImage.urlHint':
      'After download the archive is auto-extracted into the cache and the image is parsed.',
  'addImage.historyTitle': 'Recent download URLs',
  'addImage.removeFromHistory': 'Remove from history',
  'addImage.config': 'Image configuration',
  'addImage.apiLevel': 'API level',
  'addImage.arch': 'Arch',
  'addImage.variant': 'Variant',
  'addImage.variantGooglePlay': 'Google Play (recommended)',
  'addImage.variantDefault': 'Default (no Google services)',
  'addImage.sdkHint':
      'sdkmanager will download into the local system-images directory and the image will appear in the list when done.',
  'addImage.pickFolder': 'Pick folder',
  'addImage.pickZip': 'Pick Zip',
  'addImage.folderLabel': 'Image folder',
  'addImage.zipLabel': 'Image Zip file',
  'addImage.folderHint': 'Folder containing system.img / config.ini',
  'addImage.zipFileHint': 'System image archive (.zip)',
  'addImage.localHint':
      'Image metadata (API level, arch, variant) is auto-detected from the selection.',
  'addImage.confirm': 'Add',
  'addImage.folderPickFailed': 'Pick folder failed: {error}',
  'addImage.filePickFailed': 'Pick file failed: {error}',
  'addImage.validator.folder': 'Pick an image folder',
  'addImage.validator.zip': 'Pick an image Zip file',

  // ── widgets/cleanup_cache_dialog.dart ───────────────────────────────
  'cleanupCache.cacheRootHint':
      'adb-tool-cache under the system TempDir (kept across restarts)',
  'cleanupCache.adbTemp': 'Screen-record / clipboard / push-pull temp files',
  'cleanupCache.emuInstanceLogs': 'Emulator instance logs',
  'cleanupCache.emuInstanceLogsPath':
      '~/.adb-tool/emulator/instances/<id>/logs/*.log (AVD files kept)',
  'cleanupCache.backendLogs': 'Backend logs',
  'cleanupCache.backendLogsPath':
      '~/Library/Application Support/ADBTool or %APPDATA%\\ADBTool',
  'cleanupCache.flutterDb': 'Flutter database + session attachments',
  'cleanupCache.flutterDbPath':
      '%APPDATA%\\com.example.ADB Tool\\ etc.',
  'cleanupCache.flutterEngine': 'Flutter engine cache (ADBToolData)',
  'cleanupCache.flutterEnginePath':
      '~/ADBToolData or flutter_app/ADBToolData (best-effort)',
  'cleanupCache.sdkKeepHint':
      '~/.adb-tool/sdk/ (kept by default — reinstalling is multi-GB)',
  'cleanupCache.avdConfig': 'AVD configs and disks',
  'cleanupCache.title': 'Clean all caches',
  'cleanupCache.intro': 'Will clean the following (within allowlist):',
  'cleanupCache.alwaysKeep': 'Always kept:',
  'cleanupCache.keepSDK': 'Keep Android SDK',
  'cleanupCache.keepSDKHint':
      'Recommended (re-downloading the SDK is multi-GB)',
  'cleanupCache.confirm': 'Clean',
  'cleanupCache.done': 'Cleanup complete',
  'cleanupCache.freed': 'Freed {size} ',
  'cleanupCache.freedCount': '({count} items)',
  'cleanupCache.skippedHeader':
      'Skipped {count} item(s) (permission / missing):',
  'cleanupCache.skippedMore': '... and {count} more',
  'cleanupCache.cleanupDetail': 'Cleanup detail:',
  'cleanupCache.notExists': 'missing',
  'cleanupCache.sdkKept': 'Android SDK kept',
  'cleanupCache.close': 'Done',

  // ── widgets/mirror_config_card.dart ────────────────────────────────
  'mirror.title': 'Download Mirror',
  'mirror.subtitle': 'Configure a mirror to speed up sdkmanager downloads',
  'mirror.label': 'Mirror URL',
  'mirror.hint': 'e.g. https://mirrors.cloud.tencent.com/AndroidSDK/',
  'mirror.save': 'Save',
  'mirror.saved': 'Mirror config saved',
  'mirror.clear': 'Clear',
  'mirror.cleared': 'Mirror config cleared',
  'mirror.current': 'Current mirror',
  'mirror.none': 'Not configured (using official source)',
  'mirror.tencent': 'Tencent Mirror',
  'mirror.huawei': 'Huawei Mirror',
  'mirror.apply': 'Apply',
  'mirror.quickSelect': 'Quick select:',
  'mirror.proxyHint': 'Once set, sdkmanager downloads go through the mirror proxy for faster access.',
};