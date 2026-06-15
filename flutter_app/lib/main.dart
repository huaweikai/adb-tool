import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'services/log_stream.dart';
import 'services/server_launcher.dart';
import 'screens/home_screen.dart';
import 'i18n.dart';
import 'providers/theme_provider.dart';
import 'providers/device_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/test_session_provider.dart';
import 'providers/test_config_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient('http://127.0.0.1:9876'),
        ),
        Provider<LogStreamService>(
          create: (_) => LogStreamService(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<DeviceProvider>(
          create: (_) => DeviceProvider(),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
        ChangeNotifierProvider<TestSessionProvider>(
          create: (_) => TestSessionProvider(),
        ),
        ChangeNotifierProvider<TestConfigProvider>(
          create: (_) => TestConfigProvider()..load(),
        ),
      ],
      child: const AdbToolApp(),
    ),
  );
}

class AdbToolApp extends StatelessWidget {
  const AdbToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context
            .read<TestSessionProvider>()
            .setTranslator(tr, language: currentLang);
      }
    });
    return MaterialApp(
      title: 'ADB Tool',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
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
      home: ServerBootScreen(),
    );
  }
}

class ServerBootScreen extends StatefulWidget {
  const ServerBootScreen({super.key});

  @override
  State<ServerBootScreen> createState() => _ServerBootScreenState();
}

class _ServerBootScreenState extends State<ServerBootScreen>
    with WidgetsBindingObserver {
  String _status = 'Starting ...';
  bool _ready = false;
  bool _stoppedByUser = false;
  bool _canRetry = false;
  bool _disposed = false;
  Timer? _bootDelayTimer;
  ServerLauncher? _launcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = tr('starting');
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_launcher?.stop() ?? Future.value());
      _launcher = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _bootDelayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_launcher?.stop() ?? Future.value());
    _launcher = null;
    super.dispose();
  }

  Future<void> _boot() async {
    final api = context.read<ApiClient>();
    _launcher ??= ServerLauncher();
    final launcher = _launcher!;
    try {
      if (!mounted || _disposed) return;
      setState(() {
        _status = tr('launchingBackend');
        _stoppedByUser = false;
        _canRetry = false;
      });
      await launcher.start();
      if (!mounted || _disposed) return;
      setState(() => _status = tr('waitingForServer'));
      await Future.delayed(const Duration(milliseconds: 800));
      for (int i = 0; i < 60; i++) {
        await _waitForBootRetry();
        if (!mounted || _disposed) return;
        if (await api.isReady()) {
          if (!mounted || _disposed) return;
          setState(() {
            _ready = true;
            _canRetry = false;
          });
          return;
        }
      }
      await launcher.stop();
      if (!mounted || _disposed) return;
      _launcher = null;
      setState(() {
        _status = tr('serverTimeout');
        _canRetry = true;
      });
    } catch (e) {
      await launcher.stop();
      if (!mounted || _disposed) return;
      _launcher = null;
      setState(() {
        _status = '${tr('serverError')}: $e';
        _canRetry = true;
      });
    }
  }

  Future<void> _waitForBootRetry() {
    _bootDelayTimer?.cancel();
    final completer = Completer<void>();
    _bootDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _shutdownServer() async {
    final launcher = _launcher;
    _launcher = null;
    await launcher?.stop();
    setState(() {
      _ready = false;
      _stoppedByUser = true;
      _canRetry = true;
      _status = tr('serverShutdown');
    });
  }

  Future<void> _restartServer() async {
    final launcher = _launcher;
    _launcher = null;
    await launcher?.stop();
    setState(() {
      _ready = false;
      _stoppedByUser = false;
      _canRetry = false;
      _status = tr('restarting');
    });
    await _boot();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return HomeScreen(
        onShutdown: _shutdownServer,
        onRestart: _restartServer,
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_stoppedByUser && !_canRetry) ...[
              const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: 24),
            ],
            Text(tr('appTitle'),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(_status,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (_stoppedByUser || _canRetry) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _restartServer,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(tr('restartServer')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
