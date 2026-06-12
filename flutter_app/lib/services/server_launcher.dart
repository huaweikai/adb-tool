import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ServerLauncher {
  Process? _process;

  String get _binaryName =>
      Platform.isWindows ? 'adb-tool.exe' : 'adb-tool';

  Future<String> findServerBinary() async {
    final execDir = File(Platform.resolvedExecutable).parent.path;

    final candidates = <String>[];

    if (Platform.isMacOS) {
      final bundleRoot = '$execDir${Platform.pathSeparator}..${Platform.pathSeparator}..';
      candidates.add('$bundleRoot${Platform.pathSeparator}$_binaryName');
      candidates.add('$execDir${Platform.pathSeparator}$_binaryName');
    }

    if (Platform.isWindows) {
      candidates.add('$execDir${Platform.pathSeparator}$_binaryName');
      candidates.add('$execDir${Platform.pathSeparator}Resources${Platform.pathSeparator}$_binaryName');
      candidates.add('$execDir${Platform.pathSeparator}..${Platform.pathSeparator}Resources${Platform.pathSeparator}$_binaryName');
      candidates.add('$execDir${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}Resources${Platform.pathSeparator}$_binaryName');
    }

    candidates.add('${Directory.current.path}${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.path}${Platform.pathSeparator}macos${Platform.pathSeparator}Runner${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.path}${Platform.pathSeparator}windows${Platform.pathSeparator}runner${Platform.pathSeparator}Resources${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.parent.path}${Platform.pathSeparator}build${Platform.pathSeparator}$_binaryName');

    for (final p in candidates) {
      if (await File(p).exists()) return p;
    }

    final buildCmd = Platform.isWindows
        ? 'cd backend && go build -ldflags="-s -w" -o ../flutter_app/windows/runner/Resources/adb-tool.exe .'
        : 'cd backend && go build -ldflags="-s -w" -o ../flutter_app/macos/Runner/adb-tool .';
    throw Exception(
      'Server binary "$_binaryName" not found.\n'
      'Search paths:\n  ${candidates.join('\n  ')}\n'
      'Build it: $buildCmd',
    );
  }

  Future<bool> start() async {
    await _stopOldServerIfAny();
    final path = await findServerBinary();

    final env = Map<String, String>.from(Platform.environment);
    if (Platform.isWindows) {
      env['PATH'] = '${Platform.environment['SystemRoot'] ?? 'C:\\\\Windows'}\\System32;${env['PATH'] ?? ''}';
    } else {
      env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${env['PATH'] ?? ''}';
    }

    _process = await Process.start(
      path,
      [],
      environment: env,
      mode: ProcessStartMode.normal,
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

  void stop() {
    _process?.kill();
    _process = null;
  }

  Future<void> _stopOldServerIfAny() async {
    const baseUrl = 'http://localhost:9876';
    final isOurServer = await _isOurBackend(baseUrl);
    if (!isOurServer) return;

    await _tryHttpShutdown(baseUrl);
    if (await _isPortOpen(9876)) {
      await _killPortListeners(9876);
    }

    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (!await _isPortOpen(9876)) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<bool> _isOurBackend(String baseUrl) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/identify'))
          .timeout(const Duration(milliseconds: 800));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data is Map && data['name'] == 'adb-tool';
      }
    } catch (_) {}

    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/adb-path'))
          .timeout(const Duration(milliseconds: 800));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data is Map && data.containsKey('path');
      }
    } catch (_) {}

    return false;
  }

  Future<void> _tryHttpShutdown(String baseUrl) async {
    try {
      await http
          .post(Uri.parse('$baseUrl/api/shutdown'))
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(milliseconds: 200));
      socket.destroy();
      return true;
    } catch (_) {
      try {
        final socket = await Socket.connect('::1', port,
            timeout: const Duration(milliseconds: 200));
        socket.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _killPortListeners(int port) async {
    final pids = await _getPortPids(port);
    for (final pid in pids) {
      Process.killPid(pid, ProcessSignal.sigterm);
    }
    await Future.delayed(const Duration(milliseconds: 300));
    final pids2 = await _getPortPids(port);
    for (final pid in pids2) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }

  Future<List<int>> _getPortPids(int port) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano']);
        if (result.exitCode != 0) return [];
        final out = (result.stdout ?? '').toString();
        final pids = <int>{};
        for (final line in out.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.contains(':9876') && trimmed.contains('LISTENING')) {
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              final pid = int.tryParse(parts.last);
              if (pid != null && pid > 0) pids.add(pid);
            }
          }
        }
        return pids.toList();
      } else {
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
      }
    } catch (_) {
      return [];
    }
  }
}
