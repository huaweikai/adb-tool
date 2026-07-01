// Scrcpy screen-mirror control: start/stop the bundled binary, fire
// system-level shortcuts against the device, poll running state.
//
// The actual video stream is owned by scrcpy's own SDL window outside
// our Flutter app — these endpoints just manage the subprocess lifecycle.
import 'package:adb_tool/models/scrcpy_options.dart';
import 'package:adb_tool/services/api_client.dart';

mixin ScrcpyApi on ApiBase {
  /// Spawn the bundled scrcpy binary against the given device.
  /// Returns the response map (`{status, serial}`) on success.
  ///
  /// [options] is the per-device scrcpy config (mirrors the Go
  /// ScrcpyOptions struct). Pass `ScrcpyOptions()` (zero value) to
  /// use backend defaults. Pass `ScrcpyOptions.defaults()` to use
  /// the same baseline the Go side ships with.
  Future<Map<String, dynamic>> startScrcpy(
    String serial, {
    ScrcpyOptions? options,
  }) async {
    // Always send the body envelope so the backend can distinguish
    // "no body at all" (use defaults) from "explicitly empty" (still
    // use defaults). We send the wrapper unconditionally.
    final body = (options ?? ScrcpyOptions()).toApiJson();
    final resp = await dio.post(
      '/api/scrcpy/start',
      queryParameters: deviceQueryParameters(serial),
      data: body,
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
      queryParameters: deviceQueryParameters(serial, {'action': action}),
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
      queryParameters: serial != null ? deviceQueryParameters(serial) : null,
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
