package com.adbtool.i18n

import androidx.compose.runtime.compositionLocalOf

enum class AppLanguage {
    CHINESE, ENGLISH
}

data class Translations(
    val lang: AppLanguage = AppLanguage.CHINESE
) {
    val welcome: String = when (lang) {
        AppLanguage.CHINESE -> "连接设备后开始使用"
        AppLanguage.ENGLISH -> "Connect a device to start"
    }
    val refresh: String = when (lang) {
        AppLanguage.CHINESE -> "刷新"
        AppLanguage.ENGLISH -> "Refresh"
    }
    val wirelessAdb: String = when (lang) {
        AppLanguage.CHINESE -> "无线ADB"
        AppLanguage.ENGLISH -> "Wireless ADB"
    }
    val restart: String = when (lang) {
        AppLanguage.CHINESE -> "重启"
        AppLanguage.ENGLISH -> "Restart"
    }
    val shutdown: String = when (lang) {
        AppLanguage.CHINESE -> "关闭"
        AppLanguage.ENGLISH -> "Shutdown"
    }
    val theme: String = when (lang) {
        AppLanguage.CHINESE -> "主题"
        AppLanguage.ENGLISH -> "Theme"
    }
    val testConfigCenter: String = when (lang) {
        AppLanguage.CHINESE -> "测试配置中心"
        AppLanguage.ENGLISH -> "Test Config"
    }
    val backendLogs: String = when (lang) {
        AppLanguage.CHINESE -> "后端日志"
        AppLanguage.ENGLISH -> "Backend Logs"
    }
    val noDevices: String = when (lang) {
        AppLanguage.CHINESE -> "没有设备"
        AppLanguage.ENGLISH -> "No Devices"
    }
    val noDevicesHint: String = when (lang) {
        AppLanguage.CHINESE -> "通过 USB 连接或无线 ADB"
        AppLanguage.ENGLISH -> "Connect via USB or Wireless ADB"
    }
    val backendOffline: String = when (lang) {
        AppLanguage.CHINESE -> "后端服务离线"
        AppLanguage.ENGLISH -> "Backend Offline"
    }
    val cancel: String = when (lang) {
        AppLanguage.CHINESE -> "取消"
        AppLanguage.ENGLISH -> "Cancel"
    }
    val confirm: String = when (lang) {
        AppLanguage.CHINESE -> "确认"
        AppLanguage.ENGLISH -> "Confirm"
    }
    val close: String = when (lang) {
        AppLanguage.CHINESE -> "关闭"
        AppLanguage.ENGLISH -> "Close"
    }
    val logcat: String = when (lang) {
        AppLanguage.CHINESE -> "日志"
        AppLanguage.ENGLISH -> "Logcat"
    }
    val files: String = when (lang) {
        AppLanguage.CHINESE -> "文件"
        AppLanguage.ENGLISH -> "Files"
    }
    val apps: String = when (lang) {
        AppLanguage.CHINESE -> "应用"
        AppLanguage.ENGLISH -> "Apps"
    }
    val deviceStatus: String = when (lang) {
        AppLanguage.CHINESE -> "设备状态"
        AppLanguage.ENGLISH -> "Device Status"
    }
    val clipboard: String = when (lang) {
        AppLanguage.CHINESE -> "剪贴板"
        AppLanguage.ENGLISH -> "Clipboard"
    }
    val command: String = when (lang) {
        AppLanguage.CHINESE -> "命令"
        AppLanguage.ENGLISH -> "Command"
    }
    val testSession: String = when (lang) {
        AppLanguage.CHINESE -> "测试会话"
        AppLanguage.ENGLISH -> "Test Session"
    }
    val start: String = when (lang) {
        AppLanguage.CHINESE -> "开始"
        AppLanguage.ENGLISH -> "Start"
    }
    val stop: String = when (lang) {
        AppLanguage.CHINESE -> "停止"
        AppLanguage.ENGLISH -> "Stop"
    }
    val pause: String = when (lang) {
        AppLanguage.CHINESE -> "暂停"
        AppLanguage.ENGLISH -> "Pause"
    }
    val resume: String = when (lang) {
        AppLanguage.CHINESE -> "继续"
        AppLanguage.ENGLISH -> "Resume"
    }
    val clear: String = when (lang) {
        AppLanguage.CHINESE -> "清除"
        AppLanguage.ENGLISH -> "Clear"
    }
    val save: String = when (lang) {
        AppLanguage.CHINESE -> "保存"
        AppLanguage.ENGLISH -> "Save"
    }
    val delete: String = when (lang) {
        AppLanguage.CHINESE -> "删除"
        AppLanguage.ENGLISH -> "Delete"
    }
    val selectDevice: String = when (lang) {
        AppLanguage.CHINESE -> "选择设备"
        AppLanguage.ENGLISH -> "Select Device"
    }
    val selectDeviceHint: String = when (lang) {
        AppLanguage.CHINESE -> "选择设备查看日志"
        AppLanguage.ENGLISH -> "Select a device to view logs"
    }
    val logsHint: String = when (lang) {
        AppLanguage.CHINESE -> "日志将实时显示"
        AppLanguage.ENGLISH -> "Logs will appear in real-time"
    }
    val tag: String = when (lang) {
        AppLanguage.CHINESE -> "标签"
        AppLanguage.ENGLISH -> "Tag"
    }
    val level: String = when (lang) {
        AppLanguage.CHINESE -> "级别"
        AppLanguage.ENGLISH -> "Level"
    }
    val keyword: String = when (lang) {
        AppLanguage.CHINESE -> "关键词"
        AppLanguage.ENGLISH -> "Keyword"
    }
    val `package`: String = when (lang) {
        AppLanguage.CHINESE -> "包名"
        AppLanguage.ENGLISH -> "Package"
    }
    val all: String = when (lang) {
        AppLanguage.CHINESE -> "全部"
        AppLanguage.ENGLISH -> "All"
    }
    val status: String = when (lang) {
        AppLanguage.CHINESE -> "状态"
        AppLanguage.ENGLISH -> "Status"
    }
    val lines: String = when (lang) {
        AppLanguage.CHINESE -> "行数"
        AppLanguage.ENGLISH -> "Lines"
    }
    val pid: String = when (lang) {
        AppLanguage.CHINESE -> "进程ID"
        AppLanguage.ENGLISH -> "PID"
    }
    val streaming: String = when (lang) {
        AppLanguage.CHINESE -> "流式传输中"
        AppLanguage.ENGLISH -> "Streaming"
    }
    val idle: String = when (lang) {
        AppLanguage.CHINESE -> "空闲"
        AppLanguage.ENGLISH -> "Idle"
    }
    val paused: String = when (lang) {
        AppLanguage.CHINESE -> "已暂停"
        AppLanguage.ENGLISH -> "Paused"
    }
    val highlightRules: String = when (lang) {
        AppLanguage.CHINESE -> "高亮规则"
        AppLanguage.ENGLISH -> "Highlight"
    }
    val autoScroll: String = when (lang) {
        AppLanguage.CHINESE -> "自动滚动"
        AppLanguage.ENGLISH -> "Auto Scroll"
    }
    val upload: String = when (lang) {
        AppLanguage.CHINESE -> "上传"
        AppLanguage.ENGLISH -> "Upload"
    }
    val download: String = when (lang) {
        AppLanguage.CHINESE -> "下载"
        AppLanguage.ENGLISH -> "Download"
    }
    val screenshot: String = when (lang) {
        AppLanguage.CHINESE -> "截图"
        AppLanguage.ENGLISH -> "Screenshot"
    }
    val copyPath: String = when (lang) {
        AppLanguage.CHINESE -> "复制路径"
        AppLanguage.ENGLISH -> "Copy Path"
    }
    val pathCopied: String = when (lang) {
        AppLanguage.CHINESE -> "路径已复制"
        AppLanguage.ENGLISH -> "Path copied"
    }
    val name: String = when (lang) {
        AppLanguage.CHINESE -> "名称"
        AppLanguage.ENGLISH -> "Name"
    }
    val path: String = when (lang) {
        AppLanguage.CHINESE -> "路径"
        AppLanguage.ENGLISH -> "Path"
    }
    val size: String = when (lang) {
        AppLanguage.CHINESE -> "大小"
        AppLanguage.ENGLISH -> "Size"
    }
    val modified: String = when (lang) {
        AppLanguage.CHINESE -> "修改时间"
        AppLanguage.ENGLISH -> "Modified"
    }
    val deviceInfo: String = when (lang) {
        AppLanguage.CHINESE -> "设备信息"
        AppLanguage.ENGLISH -> "Device Info"
    }
}

val LocalTranslations = compositionLocalOf { Translations() }
