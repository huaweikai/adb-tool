import 'dart:async';
import 'dart:io';

class ServerLauncher {
  Process? _process;

  String get _binaryName =>
      Platform.isWindows ? 'adb-tool.exe' : 'adb-tool';

  Future<String> findServerBinary() async {
    final execDir = File(Platform.resolvedExecutable).parent.path;

    final candidates = <String>[];

    if (Platform.isMacOS) {
      final bundleRoot = '${execDir}${Platform.pathSeparator}..${Platform.pathSeparator}..';
      candidates.add('$bundleRoot${Platform.pathSeparator}$_binaryName');
      candidates.add('$execDir${Platform.pathSeparator}$_binaryName');
    }

    candidates.add('${Directory.current.path}${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.path}${Platform.pathSeparator}macos${Platform.pathSeparator}Runner${Platform.pathSeparator}$_binaryName');
    candidates.add('${Directory.current.parent.path}${Platform.pathSeparator}build${Platform.pathSeparator}$_binaryName');

    for (final p in candidates) {
      if (await File(p).exists()) return p;
    }

    throw Exception(
      'Server binary "$_binaryName" not found.\n'
      'Search paths:\n  ${candidates.join('\n  ')}\n'
      'Build it: cd backend && go build -ldflags="-s -w" -o ../flutter_app/macos/Runner/adb-tool ./cmd/adb-tool',
    );
  }

  Future<bool> start() async {
    final path = await findServerBinary();

    final env = Map<String, String>.from(Platform.environment);
    env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${env['PATH'] ?? ''}';

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
}
