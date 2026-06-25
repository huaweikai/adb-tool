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
  static const int serverPort = 9876;
  static const String baseUrl = 'http://127.0.0.1:$serverPort';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
      validateStatus: (_) => true,
    ),
  );
  Process? _process;
  Future<void>? _stopFuture;

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
    await _releaseOurBackendPort(serverPort);
    final path = await findServerBinary();

    // 获取后端所在目录
    final backendDir = File(path).parent.path;

    // 基础环境变量
    final env = Map<String, String>.from(Platform.environment);
    env['ADB_TOOL_PARENT_PID'] = pid.toString();

    if (Platform.isMacOS || Platform.isLinux) {
      // 重要：必须先从 shell 配置加载环境变量！
      // GUI 应用（如 Flutter App）启动的子进程不会自动获取 shell 配置的环境变量
      // 这会导致 ANDROID_HOME、JAVA_HOME 等变量丢失，影响 SDK 扫描功能
      // 详见 _loadShellEnvironment() 的文档注释
      final shellEnv = await _loadShellEnvironment();
      env.addAll(shellEnv);
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

  /// 从 shell 配置文件中加载环境变量（ANDROID_HOME 等）
  ///
  /// 为什么需要这个：
  /// - Flutter App 是 GUI 程序，启动子进程时不会自动继承 shell 配置的环境变量
  /// - ANDROID_HOME、JAVA_HOME 等通常在 ~/.zshrc、~/.zprofile 中设置
  /// - 直接启动的后端进程无法获取这些环境变量，导致 SDK 扫描失败
  ///
  /// 注意：
  /// - 必须使用 r''' raw string 来避免 Dart 的 $ 变量插值
  /// - shell 命令中的 $ANDROID_HOME 应该在 zsh/bash 中展开，而不是 Dart
  Future<Map<String, String>> _loadShellEnvironment() async {
    if (Platform.isMacOS) {
      // macOS: 使用 zsh 交互模式加载配置文件
      try {
        final result = await Process.run(
          '/bin/zsh',
          ['-i', '-c', r'''
            source ~/.zshrc 2>/dev/null
            source ~/.zprofile 2>/dev/null
            source ~/.zshenv 2>/dev/null
            echo "ANDROID_HOME=$ANDROID_HOME"
            echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
            echo "JAVA_HOME=$JAVA_HOME"
            echo "PATH=$PATH"
          '''],
          environment: Platform.environment,
        );

        final output = result.stdout.toString();
        final shellEnv = <String, String>{};

        for (final line in output.split('\n')) {
          if (line.startsWith('ANDROID_HOME=')) {
            shellEnv['ANDROID_HOME'] = line.substring('ANDROID_HOME='.length);
          } else if (line.startsWith('ANDROID_SDK_ROOT=')) {
            shellEnv['ANDROID_SDK_ROOT'] = line.substring('ANDROID_SDK_ROOT='.length);
          } else if (line.startsWith('JAVA_HOME=')) {
            shellEnv['JAVA_HOME'] = line.substring('JAVA_HOME='.length);
          } else if (line.startsWith('PATH=')) {
            shellEnv['PATH'] = line.substring('PATH='.length);
          }
        }

        return shellEnv;
      } catch (e) {
        stderr.writeln('Failed to load shell environment: $e');
        return {};
      }
    } else if (Platform.isLinux) {
      // Linux: 使用 bash
      try {
        final shell = File('/bin/bash').existsSync() ? '/bin/bash' : '/bin/sh';
        final result = await Process.run(
          shell,
          ['-l', '-c', r'''
            source ~/.bashrc 2>/dev/null
            source ~/.bash_profile 2>/dev/null
            source ~/.profile 2>/dev/null
            echo "ANDROID_HOME=$ANDROID_HOME"
            echo "PATH=$PATH"
          '''],
          environment: Platform.environment,
        );

        final output = result.stdout.toString();
        final shellEnv = <String, String>{};

        for (final line in output.split('\n')) {
          if (line.startsWith('ANDROID_HOME=')) {
            shellEnv['ANDROID_HOME'] = line.substring('ANDROID_HOME='.length);
          } else if (line.startsWith('PATH=')) {
            shellEnv['PATH'] = line.substring('PATH='.length);
          }
        }

        return shellEnv;
      } catch (e) {
        stderr.writeln('Failed to load shell environment: $e');
        return {};
      }
    }
    return {};
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

    await _releaseOurBackendPort(serverPort, trackedPid: process?.pid);
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
