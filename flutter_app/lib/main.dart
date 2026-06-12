import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'services/log_stream.dart';
import 'services/server_launcher.dart';
import 'screens/home_screen.dart';

final api = ApiClient('http://localhost:9876');
final logStream = LogStreamService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdbToolApp());
}

String get _prefsPath {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  return '$home/.adb_tool_prefs.json';
}

ThemeMode _loadTheme() {
  try {
    final f = File(_prefsPath);
    if (f.existsSync()) {
      final data = json.decode(f.readAsStringSync());
      return data['dark'] == false ? ThemeMode.light : ThemeMode.dark;
    }
  } catch (_) {}
  return ThemeMode.dark;
}

void _saveTheme(bool dark) {
  try {
    File(_prefsPath).writeAsStringSync(json.encode({'dark': dark}));
  } catch (_) {}
}

class AdbToolApp extends StatefulWidget {
  const AdbToolApp({super.key});

  @override
  State<AdbToolApp> createState() => _AdbToolAppState();
}

class _AdbToolAppState extends State<AdbToolApp> {
  ThemeMode _themeMode = _loadTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Tool',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        dividerColor: const Color(0xFF30363D),
        fontFamily: 'System',
      ),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        dividerColor: const Color(0xFFD0D7DE),
        fontFamily: 'System',
      ),
      home: ServerBootScreen(
        onThemeToggle: (isDark) {
          setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
          _saveTheme(isDark);
        },
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class ServerBootScreen extends StatefulWidget {
  final ValueChanged<bool> onThemeToggle;
  final bool isDark;

  const ServerBootScreen({super.key, required this.onThemeToggle, required this.isDark});

  @override
  State<ServerBootScreen> createState() => _ServerBootScreenState();
}

class _ServerBootScreenState extends State<ServerBootScreen> with WidgetsBindingObserver {
  String _status = 'Starting ...';
  bool _ready = false;
  ServerLauncher? _launcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _launcher?.stop();
      _launcher = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launcher?.stop();
    _launcher = null;
    super.dispose();
  }

  Future<void> _boot() async {
    _launcher ??= ServerLauncher();
    final launcher = _launcher!;
    try {
      setState(() => _status = 'Launching backend ...');
      await launcher.start();
      setState(() => _status = 'Waiting for server ...');
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await api.isReady()) {
          setState(() => _ready = true);
          return;
        }
      }
      launcher.stop();
      _launcher = null;
      setState(() => _status = 'Server timeout');
    } catch (e) {
      launcher.stop();
      _launcher = null;
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return HomeScreen(
        api: api,
        logStream: logStream,
        onThemeToggle: widget.onThemeToggle,
        isDark: widget.isDark,
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 24),
            Text('ADB Tool', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(_status, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
