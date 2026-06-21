// Scrcpy screen-mirror control: start/stop the bundled binary, fire
// system-level shortcuts against the device, poll running state.
//
// The actual video stream is owned by scrcpy's own SDL window outside
// our Flutter app — these endpoints just manage the subprocess lifecycle.
import 'package:adb_tool/services/api_client.dart';

mixin ScrcpyApi on ApiBase {
  /// Spawn the bundled scrcpy binary against the given device.
  /// Returns the response map (`{status, serial}`) on success.
  Future<Map<String, dynamic>> startScrcpy(String serial) async {
    final resp = await dio.post(
      '/api/scrcpy/start',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  /// Kill the running scrcpy subprocess. No-op if nothing's running.
  Future<Map<String, dynamic>> stopScrcpy() async {
    final resp = await dio.post('/api/scrcpy/stop');
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  /// Fire a system-level shortcut at the device. `action` is one of the
  /// scrcpyAction* constants from the backend (home / back / recents /
  /// power / volume_up / volume_down / menu).
  Future<Map<String, dynamic>> scrcpyShortcut(
      String serial, String action) async {
    final resp = await dio.post(
      '/api/scrcpy/action',
      queryParameters: {'serial': serial, 'action': action},
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  /// Query whether scrcpy is currently running.
  ///
  /// When [serial] is provided, only returns running=true if the running
  /// scrcpy is attached to that exact device. Use this on tab open to
  /// decide whether to render the "Start" or "Stop" button state.
  Future<ScrcpyStatus> scrcpyStatus({String? serial}) async {
    final resp = await dio.get(
      '/api/scrcpy/status',
      queryParameters: serial != null ? {'serial': serial} : null,
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return ScrcpyStatus(
      running: data['running'] == true,
      serial: data['serial'] as String? ?? '',
      pid: (data['pid'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (data['elapsed'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScrcpyStatus {
  final bool running;
  final String serial;
  final int pid;
  final int elapsedSeconds;

  const ScrcpyStatus({
    required this.running,
    required this.serial,
    required this.pid,
    required this.elapsedSeconds,
  });

  static const stopped = ScrcpyStatus(
    running: false,
    serial: '',
    pid: 0,
    elapsedSeconds: 0,
  );

  factory ScrcpyStatus.fromMap(Map<String, dynamic> m) => ScrcpyStatus(
        running: m['running'] == true,
        serial: m['serial'] as String? ?? '',
        pid: (m['pid'] as num?)?.toInt() ?? 0,
        elapsedSeconds: (m['elapsed'] as num?)?.toInt() ?? 0,
      );
}