import 'dart:async';
import 'package:flutter/material.dart';
import '../models/crash_event.dart';
import '../services/log_stream.dart';
import '../i18n.dart';
import 'crash_notification_pref.dart';

class CrashNotifierProvider {
  CrashNotifierProvider({
    required LogStreamService logStream,
    required CrashNotificationPref pref,
  })  : _logStream = logStream,
        _pref = pref;

  final LogStreamService _logStream;
  final CrashNotificationPref _pref;
  final Map<String, StreamSubscription<CrashEvent>> _subs = {};

  /// ScaffoldMessengerKey used to show snackbars. Set by [main.dart].
  GlobalKey<ScaffoldMessengerState>? messengerKey;

  /// Subscribes to crash events for [serial] via the existing /ws/logs
  /// connection. Safe to call multiple times — previous subscription
  /// is cancelled first.
  void attach(String serial) {
    detach(serial);
    _subs[serial] = _logStream.crashStreamFor(serial).listen((ev) {
      _onCrash(ev);
    });
  }

  /// Cancels the crash subscription for [serial].
  void detach(String serial) {
    _subs.remove(serial)?.cancel();
  }

  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
  }

  void _onCrash(CrashEvent ev) {
    if (!_pref.enabled) return;

    final key = messengerKey;
    if (key?.currentState == null || key?.currentContext == null) return;

    final kind = switch (ev.kind) {
      CrashKind.crash => tr('crashKindCrash'),
      CrashKind.anr => tr('crashKindAnr'),
      CrashKind.native => tr('crashKindNative'),
    };
    final pkg = ev.packageName.isNotEmpty ? ev.packageName : 'unknown';
    final title = tr('crashToastTitle', {'kind': kind, 'package': pkg});

    key!.currentState!.clearSnackBars();
    key.currentState!.showSnackBar(
      SnackBar(
        content: Text(title),
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red.shade800,
        action: SnackBarAction(
          label: tr('crashViewAction'),
          textColor: Colors.white,
          onPressed: () {
            // TODO: navigate to logcat screen for the device
          },
        ),
      ),
    );
  }
}
