import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'di.dart';
import 'providers/app_settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/launch_page.dart';
import 'i18n.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/test_session_provider.dart';
import 'services/api_client.dart';
import 'services/server_launcher.dart';
import 'utils/legacy_session_cleanup.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/window_chrome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms.
  // Window is hidden at launch via native code to prevent flash.
  // Title bar is hidden via window_manager's TitleBarStyle.hidden.
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: Size(1200, 780),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      title: 'ADB Tool',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize all app-wide singletons via GetIt. AppSettings must be
  // loaded first so the backend port is known before ApiClient /
  // ServerLauncher are built.
  final appSettings = await AppSettings.load();
  await setupDependencies(appSettings);

  // Fire-and-forget: remove the pre-DB test-session on-disk storage on
  // first launch. Safe to re-run; a marker file short-circuits subsequent
  // startups. Must never block app launch.
  unawaited(LegacySessionCleanup.run());

  // Fire-and-forget: best-effort delete of the pre-DB test-config
  // JSON file. The DB is now the source of truth; the old file is
  // dead data and we don't want it lingering on disk confusing
  // future debugging. Silently swallow any failure (locked file,
  // missing dir, etc.) — the worst case is a stale file we can
  // clean up manually later.
  unawaited(_deleteLegacyTestConfigJson());

  runApp(
    MultiProvider(
      providers: dependencyProviders,
      child: const AdbToolApp(),
    ),
  );
}

Future<void> _deleteLegacyTestConfigJson() async {
  try {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final file = File('$home/ADBToolData/test_configs.json');
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Best-effort. Missing dir, permission denied, etc. — none of
    // these should block app launch.
  }
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
      darkTheme: themeProvider.darkTheme,
      theme: themeProvider.lightTheme,
      // Global custom window chrome: sits above the Navigator so both
      // pages (launch page, home) and every dialog share one title bar.
      //
      // The chrome's window-control Tooltips need an Overlay ancestor, but
      // the app's Overlay lives *inside* the Navigator. Wrap the whole tree
      // in a local Overlay so RawTooltip finds one and stops throwing
      // "No Overlay widget found".
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Column(
                children: [
                  const WindowChrome(),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
            ),
          ],
        );
      },
      home: const _AppShell(),
    );
  }
}

/// App shell — owns the Go-backend lifecycle (boot / shutdown / restart /
/// port reconfigure) and the app-level page switch between the
/// [LaunchPage] (device selection) and [HomeScreen].
///
/// Sits *inside* [AdbToolApp] as the navigator's home; the custom title
/// bar ([WindowChrome]) is rendered above the navigator via
/// [MaterialApp.builder] so it is shared by both pages and dialogs appear
/// beneath it.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  // True once a device is picked and we've swapped in HomeScreen.
  bool _entered = false;
  // True when the backend is not running and the banner should offer a
  // "启动后端" button. Set to false while booting / running.
  bool _notStarted = false;
  // True once we've confirmed the backend is reachable. When [_notStarted]
  // is true we assume it's down until proven otherwise.
  bool _backendUp = true;
  bool _disposed = false;
  ServerLauncher? _launcher;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-start ON → boot in the background (banner shows "connecting");
    // OFF → wait for the user to hit "启动后端".
    if (context.read<AppSettings>().autoStartBackend) {
      _boot();
    } else {
      _notStarted = true;
    }
    final api = context.read<ApiClient>();
    if (_notStarted) _backendUp = false;
    _startPolling(api);
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
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_launcher?.stop() ?? Future.value());
    _launcher = null;
    super.dispose();
  }

  void _startPolling(ApiClient api) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Skip while HomeScreen is showing — no need to rebuild it every
      // second, and the banner isn't visible anyway.
      if (!mounted || _entered) return;
      final up = await api.isReady();
      if (!mounted || _entered) return;
      if (up != _backendUp) setState(() => _backendUp = up);
    });
  }

  /// Boot (or re-boot) the Go backend. Runs the full start → wait → poll
  /// cycle. On success [_notStarted] stays false (banner hides). On
  /// timeout / error [_notStarted] is set back to true so the
  /// "启动后端" button reappears.
  Future<void> _boot() async {
    final api = context.read<ApiClient>();
    _launcher ??= ServerLauncher(context.read<AppSettings>().backendPort);
    final launcher = _launcher!;
    try {
      if (!mounted || _disposed) return;
      setState(() => _notStarted = false);
      await launcher.start();
      if (!mounted || _disposed) return;
      await Future.delayed(const Duration(milliseconds: 800));
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || _disposed) return;
        final ready = await api.isReady();
        if (ready) {
          if (!mounted || _disposed) return;
          setState(() => _notStarted = false);
          return;
        }
      }
      await launcher.stop();
      if (!mounted || _disposed) return;
      _launcher = null;
      setState(() => _notStarted = true);
    } catch (e, st) {
      debugPrint('[BOOT ERROR] $e\n$st');
      await launcher.stop();
      if (!mounted || _disposed) return;
      _launcher = null;
      setState(() => _notStarted = true);
    }
  }

  /// Boot on demand from the "启动后端" banner. [_boot] manages the
  /// _notStarted flag, so this is just a guard + call.
  Future<void> _startBackend() async {
    if (!mounted || _disposed) return;
    await _boot();
  }

  Future<void> _shutdownServer() async {
    final launcher = _launcher;
    _launcher = null;
    await launcher?.stop();
    setState(() {
      _entered = false;
      _notStarted = true;
    });
  }

  Future<void> _restartServer() async {
    final launcher = _launcher;
    _launcher = null;
    await launcher?.stop();
    setState(() {
      _entered = false;
      _notStarted = false; // "connecting" banner while rebooting
    });
    await _boot();
  }

  void _openSettings() {
    if (!mounted || _disposed) return;
    showSettingsDialog(
      context,
      onRestartBackend: _reconfigureBackend,
      onPortChanged: (_) => _reconfigureBackend(),
    );
  }

  /// Tear down the running backend, point [ApiClient] at the current
  /// port, and re-boot. Used by the settings "重启后端" button and after
  /// a port change.
  Future<void> _reconfigureBackend() async {
    final api = context.read<ApiClient>();
    final settings = context.read<AppSettings>();
    final old = _launcher;
    _launcher = null;
    await old?.stop();
    api.updateBaseUrl(settings.baseUrl);
    await _boot();
  }

  @override
  Widget build(BuildContext context) {
    if (_entered) {
      return HomeScreen(
        onShutdown: _shutdownServer,
        onRestart: _restartServer,
      );
    }
    return LaunchPage(
      backendUp: _backendUp,
      notStarted: _notStarted,
      onOpen: () => setState(() => _entered = true),
      onOpenSettings: _openSettings,
      onStartBackend: _notStarted ? _startBackend : null,
    );
  }
}
