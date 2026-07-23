import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class PortInUseException implements Exception {
  final int port;
  final String message;

  PortInUseException(this.port, this.message);

  @override
  String toString() => message;
}

class ServerLauncher {
  /// Backend listen port. Defaults to 9876 to match the Go backend's
  /// `server.DefaultListenAddr`. The actual port is propagated to the
  /// backend via the `ADB_TOOL_LISTEN` env var in [start].
  final int port;
  late final String baseUrl;
  late final Dio _dio;
  Process? _process;
  Future<void>? _stopFuture;

  ServerLauncher([this.port = 9876]) {
    baseUrl = 'http://127.0.0.1:$port';
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
        validateStatus: (_) => true,
      ),
    );
  }

  String get _binaryName => Platform.isWindows ? 'runtime.exe' : 'adb-tool';

  Future<String> findServerBinary() async {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;

    final candidates = <String>[
      '$execDir$sep$_binaryName',
    ];

    if (Platform.isMacOS) {
      final bundleRoot = '$execDir$sep..$sep..';
      candidates.add('$bundleRoot$sep$_binaryName');
      candidates.add('$execDir$sep..${sep}Resources$sep$_binaryName');
    }

    if (Platform.isWindows) {
      candidates.add('$execDir${sep}Resources$sep$_binaryName');
      candidates.add('$execDir$sep..${sep}Resources$sep$_binaryName');
    }

    candidates.add('${Directory.current.path}$sep$_binaryName');
    candidates
        .add('${Directory.current.path}$sep..${sep}backend$sep$_binaryName');

    for (final p in candidates) {
      if (await File(p).exists()) return p;
    }

    final buildCmd = Platform.isWindows
        ? 'cd backend && go build -ldflags="-s -w" -o ../flutter_app/windows/runner/Resources/runtime.exe .'
        : 'cd backend && go build -ldflags="-s -w" -o ../flutter_app/macos/Runner/adb-tool .';
    throw Exception(
      'Server binary "$_binaryName" not found.\n'
      'Search paths:\n  ${candidates.join('\n  ')}\n'
      'Build it: $buildCmd',
    );
  }

  Future<bool> start() async {
    _stopFuture = null;
    await _releaseOurBackendPort(port);
    final path = await findServerBinary();

    // 获取后端所在目录
    final backendDir = File(path).parent.path;

    // 基础环境变量
    final env = Map<String, String>.from(Platform.environment);
    env['ADB_TOOL_PARENT_PID'] = pid.toString();
    // Tell the Go backend which loopback address:port to listen on.
    // Matches backend/main.go: listenAddr = os.Getenv("ADB_TOOL_LISTEN").
    env['ADB_TOOL_LISTEN'] = '127.0.0.1:$port';

    if (Platform.isMacOS || Platform.isLinux) {
      // Important: a GUI app (this Flutter desktop app) does NOT inherit
      // shell-init env vars (ANDROID_HOME / JAVA_HOME / PATH additions from
      // ~/.zshrc etc.) when it spawns the backend. Without this the user's
      // PATH-only tools (adb / avdmanager / java) may not be found.
      //
      // What we DO propagate: PATH and nothing else.
      // What we DON'T propagate: ANDROID_HOME / ANDROID_SDK_ROOT / JAVA_HOME.
      // AGENTS.md is explicit: ANDROID_HOME must not be back-inferred —
      // the SDK Manager UI is the only place that controls it. If we
      // override it from shell env we silently win over the user's
      // in-app selection, which has caused confusion before.
      final shellEnv = await _loadShellEnvironment();
      if (shellEnv.containsKey('PATH')) {
        env['PATH'] = _mergePath(env['PATH'], shellEnv['PATH']!);
      }
    } else if (Platform.isWindows) {
      env['PATH'] =
          '${Platform.environment['SystemRoot'] ?? 'C:\\Windows'}\\System32;${env['PATH'] ?? ''}';
    }

    // 直接启动后端（环境变量已经包含了 shell 配置中的内容）
    _process = await Process.start(
      path,
      [],
      environment: env,
      mode: ProcessStartMode.normal,
      workingDirectory: backendDir,
    );

    _process!.stdout.listen((data) {
      stdout.add(data);
    });
    _process!.stderr.listen((data) {
      stderr.add(data);
    });

    unawaited(_process!.exitCode.then((code) {
      if (code != 0) {
        stderr.writeln('Server exited with code $code');
      }
    }));

    return true;
  }

  /// Loads PATH (and only PATH) from the user's interactive shell.
  ///
  /// Why this exists:
  /// - A GUI app (this Flutter desktop app) does NOT inherit shell-init
  ///   env vars when it spawns the backend. Without sourcing ~/.zshrc,
  ///   the backend's PATH won't include things like Homebrew bin or
  ///   the user's per-shell adb / avdmanager install locations.
  ///
  /// Why we DON'T propagate ANDROID_HOME / JAVA_HOME / ANDROID_SDK_ROOT:
  /// - AGENTS.md says: "ANDROID_HOME 不反推（用户用 SDK manager 页面控制）".
  ///   If we override from shell env we silently win over the user's
  ///   in-app selection in the SDK Manager UI, which is confusing.
  ///   Those vars are owned by the SDK Manager page in-app; if they're
  ///   unset, the backend's tools resolve via PATH.
  ///
  /// Must use r''' raw string to avoid Dart `$variable` interpolation —
  /// the `$VAR` references must be expanded by zsh / bash, not Dart.
  Future<Map<String, String>> _loadShellEnvironment() async {
    if (Platform.isMacOS) {
      // macOS: zsh interactive mode loads ~/.zshrc / ~/.zprofile / ~/.zshenv.
      try {
        final result = await Process.run(
          '/bin/zsh',
          ['-i', '-c', r'''
            source ~/.zshrc 2>/dev/null
            source ~/.zprofile 2>/dev/null
            source ~/.zshenv 2>/dev/null
            echo "PATH=$PATH"
          '''],
          environment: Platform.environment,
        );

        return _parseShellEnv(result.stdout.toString());
      } catch (e) {
        stderr.writeln('Failed to load shell environment: $e');
        return {};
      }
    } else if (Platform.isLinux) {
      // Linux: bash login mode loads ~/.bashrc / ~/.bash_profile / ~/.profile.
      try {
        final shell = File('/bin/bash').existsSync() ? '/bin/bash' : '/bin/sh';
        final result = await Process.run(
          shell,
          ['-l', '-c', r'''
            source ~/.bashrc 2>/dev/null
            source ~/.bash_profile 2>/dev/null
            source ~/.profile 2>/dev/null
            echo "PATH=$PATH"
          '''],
          environment: Platform.environment,
        );

        return _parseShellEnv(result.stdout.toString());
      } catch (e) {
        stderr.writeln('Failed to load shell environment: $e');
        return {};
      }
    }
    return {};
  }

  Map<String, String> _parseShellEnv(String output) {
    final shellEnv = <String, String>{};
    for (final line in output.split('\n')) {
      if (line.startsWith('PATH=')) {
        shellEnv['PATH'] = line.substring('PATH='.length);
      }
    }
    return shellEnv;
  }

  /// Merge a shell-derived PATH on top of the existing PATH while
  /// keeping the system fallback dirs (so basic tools like
  /// /usr/bin/env still resolve). Fix (code-review B8): the previous
  /// `env.addAll(shellEnv)` overwrote PATH wholesale, dropping the
  /// standard `/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin` prefix
  /// and breaking Linux users with no zsh + oh-my-zsh users whose
  /// shell PATH was shorter than the default.
  ///
  /// Strategy:
  /// 1. Sanity-check the shell PATH — if it's suspiciously short
  ///    (e.g. a malformed rc file), fall back to the existing PATH.
  /// 2. Prepend the standard system dirs (only those that exist) so
  ///    findBinary() can always fall back to /usr/bin etc.
  /// 3. De-duplicate entries, keeping the first occurrence so the
  ///    user's shell PATH wins over the system defaults.
  String _mergePath(String? existingPath, String shellPath) {
    const fallbackDirs = [
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
      '/usr/local/bin',
    ];

    // PATH-environment-variable separator (':'' on Unix, ';' on Windows).
    // NB: NOT to be confused with Platform.pathSeparator, which is the
    // file-path component separator ('/' on Unix, '\\' on Windows). Using
    // the wrong one corrupts PATH values into slash-joined nonsense, which
    // is exactly the bug that broke sdkmanager spawn with exit 127.
    final envSep = Platform.isWindows ? ';' : ':';

    // Sanity check: a valid PATH on a real desktop is at least a few
    // dozen chars (e.g. "/usr/bin:/bin:/usr/local/bin:/opt/...").
    // A < 100 char PATH usually means the rc file failed to source.
    if (shellPath.length < 100) {
      return existingPath ?? '';
    }

    final merged = <String>[];
    final seen = <String>{};

    void add(String dir) {
      if (dir.isEmpty) return;
      if (seen.add(dir)) merged.add(dir);
    }

    // 1. System fallback first (guaranteed tools like /usr/bin/env).
    for (final d in fallbackDirs) {
      add(d);
    }
    // 2. User's existing Flutter-app PATH (Flutter ships some tools
    //    via dart / snap / brew on macOS).
    if (existingPath != null && existingPath.isNotEmpty) {
      for (final d in existingPath.split(envSep)) {
        add(d);
      }
    }
    // 3. Shell PATH last (highest priority — Homebrew, rbenv, etc.).
    for (final d in shellPath.split(envSep)) {
      add(d);
    }

    return merged.join(envSep);
  }

  Future<void> stop() {
    return _stopFuture ??= _stop();
  }

  Future<void> _stop() async {
    final process = _process;
    _process = null;
    await _tryHttpShutdown(baseUrl);

    if (process != null) {
      try {
        final code = await process.exitCode.timeout(const Duration(seconds: 3));
        if (code != 0) {
          stderr.writeln('Server exited with code $code');
        }
      } catch (_) {
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } catch (_) {
          process.kill(ProcessSignal.sigkill);
        }
      }
    }

    await _releaseOurBackendPort(port, trackedPid: process?.pid);
  }

  Future<void> _releaseOurBackendPort(int port, {int? trackedPid}) async {
    if (!await _isPortOpen(port)) return;

    final isOurs = await _isOurBackend();
    if (!isOurs) {
      throw PortInUseException(
        port,
        'Port $port is already in use by another application. '
        'Stop that process or change ADB_TOOL_LISTEN before starting adb-tool.',
      );
    }

    await _tryHttpShutdown(baseUrl);
    await _waitForPortClosed(port, const Duration(seconds: 4));
    if (!await _isPortOpen(port)) return;

    final stillOurs = await _isOurBackend();
    if (!stillOurs) {
      throw PortInUseException(
        port,
        'Port $port is in use by another application.',
      );
    }

    await _killVerifiedBackendListeners(port, trackedPid: trackedPid);
    await _waitForPortClosed(port, const Duration(seconds: 5));

    if (await _isPortOpen(port)) {
      throw PortInUseException(
        port,
        'Port $port is still in use after attempting to stop the previous adb-tool backend.',
      );
    }
  }

  Future<bool> _isOurBackend() async {
    try {
      final resp = await _dio.get('/api/identify');
      if (resp.statusCode == 200 && _isOurBackendPayload(resp.data)) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<int?> _ourBackendPid() async {
    try {
      final resp = await _dio.get('/api/identify');
      if (resp.statusCode != 200 || !_isOurBackendPayload(resp.data)) {
        return null;
      }
      final payload = _unwrapPayload(_asMap(resp.data));
      return int.tryParse(payload['pid']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  bool _isOurBackendPayload(dynamic data) {
    final payload = _unwrapPayload(_asMap(data));
    return payload['name'] == 'adb-tool';
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> body) {
    if (body['ok'] == true && body['data'] is Map) {
      return _asMap(body['data']);
    }
    return body;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = json.decode(data);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Future<void> _tryHttpShutdown(String baseUrl) async {
    try {
      await _dio.post('$baseUrl/api/shutdown');
    } catch (_) {}
  }

  Future<void> _waitForPortClosed(int port, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await _isPortOpen(port)) return;
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> _isPortOpen(int port) async {
    for (final host in const ['127.0.0.1', '::1']) {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        socket.destroy();
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> _killVerifiedBackendListeners(int port, {int? trackedPid}) async {
    final allowedPids = <int>{};
    if (trackedPid != null && trackedPid > 0) {
      allowedPids.add(trackedPid);
    }
    final backendPid = await _ourBackendPid();
    if (backendPid != null && backendPid > 0) {
      allowedPids.add(backendPid);
    }

    if (allowedPids.isEmpty) {
      throw PortInUseException(
        port,
        'Port $port is in use but the adb-tool backend PID could not be verified.',
      );
    }

    final listenerPids = await _getPortPids(port);
    final targets =
        listenerPids.where((listenerPid) => allowedPids.contains(listenerPid)).toList();
    if (targets.isEmpty) {
      return;
    }

    for (final listenerPid in targets) {
      if (listenerPid == pid) continue;
      Process.killPid(listenerPid, ProcessSignal.sigterm);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    final remaining = await _getPortPids(port);
    for (final listenerPid in remaining) {
      if (!allowedPids.contains(listenerPid) || listenerPid == pid) continue;
      Process.killPid(listenerPid, ProcessSignal.sigkill);
    }
  }

  Future<List<int>> _getPortPids(int port) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano']);
        if (result.exitCode != 0) return [];
        final out = (result.stdout ?? '').toString();
        final pids = <int>{};
        final portToken = ':$port';
        for (final line in out.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.contains('LISTENING')) continue;
          if (!_lineHasListeningPort(trimmed, portToken)) continue;
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.isEmpty) continue;
          final listenerPid = int.tryParse(parts.last);
          if (listenerPid != null && listenerPid > 0) {
            pids.add(listenerPid);
          }
        }
        return pids.toList();
      }

      final result = await Process.run(
        'lsof',
        ['-nP', '-iTCP:$port', '-sTCP:LISTEN', '-t'],
      );
      if (result.exitCode != 0) return [];
      final out = (result.stdout ?? '').toString().trim();
      if (out.isEmpty) return [];
      return out
          .split(RegExp(r'\s+'))
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _lineHasListeningPort(String line, String portToken) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) return false;
    for (final part in parts) {
      if (part == 'LISTENING') break;
      final colon = part.lastIndexOf(':');
      if (colon < 0) continue;
      final portText = part.substring(colon + 1);
      if (portText == portToken.substring(1)) return true;
    }
    return false;
  }

  Future<bool> isBackendReachable() => _isOurBackend();
}
