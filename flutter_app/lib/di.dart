// Dependency Injection setup using GetIt.
//
// Architecture:
//   GetIt provides DI (singleton registration, constructor resolution)
//   Provider bridges GetIt singletons → Flutter widget tree
//
// Usage:
//   // Resolve from anywhere:
//   final db = getIt<AppDatabase>();
//
//   // In main.dart MultiProvider:
//   ChangeNotifierProvider<DeviceProvider>.value(getIt<DeviceProvider>()),
//
// Singleton vs Factory:
//   - Singleton: app-wide shared state (DB, API, Providers)
//   - Factory: fresh instance per request (use registerFactory)
//
// Registration order matters — dependencies must be registered before
// anything that depends on them.
import 'package:get_it/get_it.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';

import 'db/database.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/device_provider.dart';
import 'providers/test_session_provider.dart';
import 'providers/test_config_provider.dart';
import 'providers/scrcpy_settings_provider.dart';
import 'providers/clipboard_history_provider.dart';
import 'providers/emulator_engine_provider.dart';
import 'providers/emulator_java_provider.dart';
import 'providers/emulator_image_provider.dart';
import 'services/api_client.dart';
import 'services/log_stream.dart';

export 'package:get_it/get_it.dart' show getIt;

final GetIt getIt = GetIt.instance;

/// Initialize all app-wide singletons.
///
/// Call once from main() before runApp().
Future<void> setupDependencies() async {
  // ── 1. Core infrastructure (no app-layer dependencies) ──────────────
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  getIt.registerSingleton<ApiClient>(
    ApiClient('http://127.0.0.1:9876'),
  );

  getIt.registerSingleton<LogStreamService>(
    LogStreamService(),
  );

  // ── 2. UI state providers ────────────────────────────────────────────
  // Theme / locale are independent
  getIt.registerSingleton<ThemeProvider>(ThemeProvider());
  getIt.registerSingleton<LocaleProvider>(LocaleProvider());

  // DeviceProvider needs DB
  getIt.registerSingleton<DeviceProvider>(
    DeviceProvider(db: getIt<AppDatabase>()),
  );

  // TestConfigProvider needs a DAO from DB
  getIt.registerSingleton<TestConfigProvider>(
    TestConfigProvider(getIt<AppDatabase>().testAppConfigsDao),
  );

  // ScrcpySettingsProvider needs DB
  getIt.registerSingleton<ScrcpySettingsProvider>(
    ScrcpySettingsProvider(db: getIt<AppDatabase>()),
  );

  // ClipboardHistoryProvider needs DB
  getIt.registerSingleton<ClipboardHistoryProvider>(
    ClipboardHistoryProvider(db: getIt<AppDatabase>())..load(),
  );

  // TestSessionProvider needs DB + DeviceProvider
  // DeviceProvider must be registered first (no lazy fallback in constructor)
  getIt.registerSingleton<TestSessionProvider>(
    TestSessionProvider(
      db: getIt<AppDatabase>(),
      deviceProvider: getIt<DeviceProvider>(),
    ),
  );

  // EmulatorEngineProvider needs ApiClient
  getIt.registerSingleton<EmulatorEngineProvider>(
    EmulatorEngineProvider(api: getIt<ApiClient>()),
  );

  // EmulatorJavaProvider needs ApiClient
  getIt.registerSingleton<EmulatorJavaProvider>(
    EmulatorJavaProvider(api: getIt<ApiClient>()),
  );

  // EmulatorImageProvider needs ApiClient
  getIt.registerSingleton<EmulatorImageProvider>(
    EmulatorImageProvider(api: getIt<ApiClient>()),
  );
}

/// Build the Provider list from registered singletons.
/// Use with MultiProvider(...providers: dependencyProviders, ...)
List<SingleChildWidget> get dependencyProviders => [
      // Raw singletons (no ChangeNotifier)
      Provider<AppDatabase>.value(value: getIt<AppDatabase>()),
      Provider<ApiClient>.value(value: getIt<ApiClient>()),
      Provider<LogStreamService>.value(value: getIt<LogStreamService>()),

      // ChangeNotifier providers
      ChangeNotifierProvider<ThemeProvider>.value(value: getIt<ThemeProvider>()),
      ChangeNotifierProvider<LocaleProvider>.value(value: getIt<LocaleProvider>()),
      ChangeNotifierProvider<DeviceProvider>.value(value: getIt<DeviceProvider>()),
      ChangeNotifierProvider<TestConfigProvider>.value(value: getIt<TestConfigProvider>()),
      ChangeNotifierProvider<ScrcpySettingsProvider>.value(value: getIt<ScrcpySettingsProvider>()),
      ChangeNotifierProvider<ClipboardHistoryProvider>.value(value: getIt<ClipboardHistoryProvider>()),
      ChangeNotifierProvider<TestSessionProvider>.value(value: getIt<TestSessionProvider>()),
      ChangeNotifierProvider<EmulatorEngineProvider>.value(value: getIt<EmulatorEngineProvider>()),
      ChangeNotifierProvider<EmulatorJavaProvider>.value(value: getIt<EmulatorJavaProvider>()),
      ChangeNotifierProvider<EmulatorImageProvider>.value(value: getIt<EmulatorImageProvider>()),
    ];

/// Dispose all singletons. Call only in integration tests.
Future<void> disposeDependencies() async {
  await getIt<AppDatabase>().close();
  await getIt.reset();
}
