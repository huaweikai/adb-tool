import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'services/database.dart';
import 'services/log_stream.dart';
import 'services/server_launcher.dart';
import 'screens/home_screen.dart';
import 'i18n.dart';
import 'providers/theme_provider.dart';
import 'providers/device_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/test_session_provider.dart';
import 'providers/test_config_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Singleton DB shared by DeviceProvider and TestSessionProvider
  final db = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
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
          create: (_) => DeviceProvider(db: db),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
        ChangeNotifierProvider<TestSessionProvider>(
          create: (_) => TestSessionProvider(db: db),
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
  final List<String> _steps = [];
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

  void _log(String step) {
    if (!mounted) return;
    setState(() => _steps.add('[${DateTime.now().millisecondsSinceEpoch % 100000}] $step'));
    debugPrint('[BOOT] $step');
  }

  Future<void> _boot() async {
    final api = context.read<ApiClient>();
    _launcher ??= ServerLauncher();
    final launcher = _launcher!;
    try {
      if (!mounted || _disposed) return;
      _log('开始启动...');
      setState(() {
        _status = tr('launchingBackend');
        _stoppedByUser = false;
        _canRetry = false;
      });
      _log('调用 launcher.start()...');
      await launcher.start();
      _log('launcher.start() 完成');
      if (!mounted || _disposed) return;
      setState(() => _status = tr('waitingForServer'));
      _log('等待 800ms...');
      await Future.delayed(const Duration(milliseconds: 800));
      _log('开始轮询 isReady()...');
      for (int i = 0; i < 60; i++) {
        await _waitForBootRetry();
        if (!mounted || _disposed) return;
        _log('isReady() 第${i + 1}次尝试...');
        final ready = await api.isReady();
        _log('isReady() = $ready');
        if (ready) {
          if (!mounted || _disposed) return;
          _log('后端就绪，切换到 HomeScreen');
          setState(() {
            _ready = true;
            _canRetry = false;
          });
          return;
        }
      }
      _log('轮询超时，停止后端');
      await launcher.stop();
      if (!mounted || _disposed) return;
      _launcher = null;
      setState(() {
        _status = tr('serverTimeout');
        _canRetry = true;
      });
    } catch (e, st) {
      _log('异常: $e');
      debugPrint('[BOOT ERROR] $e\n$st');
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

  void _showBootLog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('启动日志'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: _steps.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _steps[i],
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
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
            if (_steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._steps.reversed.take(3).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(s,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _showBootLog,
                child: Text('查看完整日志 (${_steps.length}步)'),
              ),
            ],
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
