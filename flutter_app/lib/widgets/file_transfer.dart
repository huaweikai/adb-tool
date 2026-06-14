enum TransferMode { upload, download }

class TransferState {
  final TransferMode mode;
  final String fileName;
  final int sent;
  final int total;
  final String phaseKey;

  const TransferState({
    required this.mode,
    required this.fileName,
    required this.sent,
    required this.total,
    required this.phaseKey,
  });

  bool get waitingForAdb =>
      phaseKey == 'deviceReading' ||
      phaseKey == 'deviceWriting' ||
      phaseKey == 'deviceInstalling';

  double? get progress => total > 0 && !waitingForAdb ? sent / total : null;
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes ${units[unit]}';
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}
