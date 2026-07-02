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

  // ── Windowless recording (--no-window --record=<path>) ──────────────
  //
  // These three calls drive a SEPARATE scrcpy subprocess from the
  // mirror one. The two are mutually exclusive on the same device
  // (scrcpy holds the adb connection); the backend returns 409 with
  // `data.kind = "mirror" | "record"` when the user tries to start a
  // recording while the other subprocess is in flight. The capture
  // mixin layer surfaces that as a confirm dialog and re-calls start
  // with force=true if the user agrees.
  //
  // The destination path is owned by the backend (under
  // ~/.adb-tool/scrcpy_recordings/, see ScrcpyRecordingSandboxDir in
  // adb_scrcpy_record.go) — the Flutter side doesn't pick or persist
  // a directory any more. The start response carries the path; the
  // capture mixin reads it back via the status response at stop time.

  /// Start a windowless scrcpy recording. Pass [force]=true to
  /// gracefully kill an in-flight mirror session before starting the
  /// recording (the recording-mirror conflict is the only place force
  /// is meaningful; when a previous recording is running it's always
  /// replaced).
  ///
  /// Returns the host output path the backend picked
  /// (under `~/.adb-tool/scrcpy_recordings/`). The capture mixin
  /// persists this on its in-memory state so the stop path can read
  /// the file back.
  ///
  /// Throws [ScrcpyRecordBusyException] when the backend refuses with
  /// 409 (i.e. force=false and something is already running). The
  /// exception carries [ScrcpyRecordBusyException.kind] so the UI can
  /// render an appropriate message.
  Future<String> startScrcpyRecording(
    String serial, {
    bool force = false,
  }) async {
    final resp = await dio.post(
      '/api/scrcpy/record/start',
      queryParameters: {
        ...deviceQueryParameters(serial),
        if (force) 'force': 'true',
      },
    );
    if (resp.statusCode == 409) {
      final data = responseMap(resp);
      throw ScrcpyRecordBusyException(
        kind: data['kind'] as String? ?? 'record',
        serial: data['serial'] as String? ?? '',
        message: errorMessage(resp),
      );
    }
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return (data['outputPath'] as String?) ?? '';
  }

  /// Stop the windowless recording subprocess. No-op if nothing is
  /// running (returns 200 either way so the UI can fire it on every
  /// state transition).
  Future<Map<String, dynamic>> stopScrcpyRecording() async {
    final resp = await dio.post('/api/scrcpy/record/stop');
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  /// Query the windowless recording subprocess state. When [serial]
  /// is provided, only returns running=true if the recording is
  /// attached to that exact device.
  Future<ScrcpyRecordStatus> scrcpyRecordingStatus({String? serial}) async {
    final resp = await dio.get(
      '/api/scrcpy/record/status',
      queryParameters: serial != null ? deviceQueryParameters(serial) : null,
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return ScrcpyRecordStatus(
      running: data['running'] == true,
      serial: data['serial'] as String? ?? '',
      outputPath: data['outputPath'] as String? ?? '',
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

class ScrcpyRecordStatus {
  final bool running;
  final String serial;
  final String outputPath;
  final int pid;
  final int elapsedSeconds;

  const ScrcpyRecordStatus({
    required this.running,
    required this.serial,
    required this.outputPath,
    required this.pid,
    required this.elapsedSeconds,
  });

  static const stopped = ScrcpyRecordStatus(
    running: false,
    serial: '',
    outputPath: '',
    pid: 0,
    elapsedSeconds: 0,
  );
}

/// Thrown by [ScrcpyApi.startScrcpyRecording] when the backend
/// responds with 409 (something is already using scrcpy). The
/// [kind] field is the discriminator — "mirror" means the user has
/// a screen-mirror session running; "record" means a previous
/// recording is still in flight. The capture mixin uses the kind to
/// pick a different confirm-dialog copy.
class ScrcpyRecordBusyException implements Exception {
  final String kind;
  final String serial;
  final String message;

  const ScrcpyRecordBusyException({
    required this.kind,
    required this.serial,
    required this.message,
  });

  bool get isMirrorBusy => kind == 'mirror';
  bool get isRecordBusy => kind == 'record';

  @override
  String toString() => 'ScrcpyRecordBusyException($kind, $serial): $message';
}
