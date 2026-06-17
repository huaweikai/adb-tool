/// 通用时间/时长/文件大小格式化函数。

/// 00:00 格式的时长字符串。
String fmtDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 00:00:00 格式的 elapsed 字符串。
String fmtElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

/// 字节数格式化（KB / MB）。
String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// HH:mm:ss 格式。
String fmtTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  final s = time.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// yyyy-MM-dd HH:mm:ss 格式。
String fmtDateTime(DateTime time) {
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${fmtTime(time)}';
}
