// Settings — reusable floating "window" dialog (simulates a detached
// multi-window panel). Opened from both the launch page and the main
// app, so it is intentionally a dialog, not a route.
//
// Visual language matches the launch page (design node 64:2): dark
// surface, green accent (#2EA043 / #3FB950), bordered panels, custom
// rows / toggles / pill-segments — deliberately NOT the stock Material
// Card / AppBar / SwitchListTile / SegmentedButton widgets.
//
// Sections:
//   * 后端 (Backend / Bridge) — live status pill (green running /
//     red stopped / gray checking), editable listen port, auto-start
//     switch, restart button, runtime info (pid / started).
//   * 录屏 (Recording) — adb / scrcpy method picker.
//   * 缓存 (Cache) — cleanup dialog trigger.
//   * 外观 (Appearance) — theme (dark/light) + language (zh/en).
//   * 关于 (About) — app version (kAppVersion / kAppBuild).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../design/design_tokens.dart';
import '../providers/app_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_client.dart';
import '../widgets/cleanup_cache_dialog.dart';
import '../widgets/recording_settings_section.dart';

const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
const String kAppBuild =
    String.fromEnvironment('APP_BUILD', defaultValue: '0');

/// Accent colors — keep in sync with lib/screens/launch_page.dart (64:2).
const Color _accent = Color(0xFF2EA043);
const Color _accentBorder = Color(0xFF3FB950);

/// Open the settings as a floating "window" dialog. Reusable from both
/// the launch page and the main app. [onRestartBackend] / [onPortChanged]
/// are optional live-backend hooks; when null the corresponding controls
/// are read-only / hidden.
Future<T?> showSettingsDialog<T>(
  BuildContext context, {
  Future<void> Function()? onRestartBackend,
  Future<void> Function(int newPort)? onPortChanged,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _SettingsDialog(
      onRestartBackend: onRestartBackend,
      onPortChanged: onPortChanged,
    ),
  );
}

class _SettingsDialog extends StatefulWidget {
  final Future<void> Function()? onRestartBackend;
  final Future<void> Function(int newPort)? onPortChanged;

  const _SettingsDialog({this.onRestartBackend, this.onPortChanged});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  Map<String, dynamic>? _backendInfo;
  bool _checking = true;
  bool _restarting = false;
  String? _portError;
  final _portController = TextEditingController();
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _portController.text = context.read<AppSettings>().backendPort.toString();
    _refreshStatus();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    setState(() => _checking = true);
    final api = context.read<ApiClient>();
    final info = await api.tryIdentify();
    if (!mounted) return;
    setState(() {
      _backendInfo = info;
      _checking = false;
    });
  }

  Future<void> _restart() async {
    if (widget.onRestartBackend == null) return;
    setState(() => _restarting = true);
    try {
      await widget.onRestartBackend!();
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  Future<void> _applyPort() async {
    final raw = int.tryParse(_portController.text.trim());
    if (raw == null || raw < 1 || raw > 65535) {
      setState(() => _portError = tr('settings.backend.portInvalid'));
      return;
    }
    setState(() => _portError = null);
    final settings = context.read<AppSettings>();
    await settings.setPort(raw);
    if (widget.onPortChanged != null) {
      await widget.onPortChanged!(raw);
      await _refreshStatus();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('settings.backend.port')}: $raw'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AppSettings>();
    final canEditPort = widget.onPortChanged != null;
    final maxW =
        (MediaQuery.of(context).size.width - 48).clamp(420.0, 680.0);

    final window = Container(
      width: maxW,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 40,
            spreadRadius: 2,
            offset: Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            _TitleBar(
              onClose: () => Navigator.of(context).pop(),
              onDrag: (delta) =>
                  setState(() => _dragOffset += delta),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.hub,
                      label: tr('settings.sectionBackend'),
                    ),
                    const SizedBox(height: 12),
                    _BackendPanel(
                      checking: _checking,
                      reachable: _backendInfo != null,
                      backendInfo: _backendInfo,
                      portController: _portController,
                      portError: _portError,
                      canEditPort: canEditPort,
                      autoStart: settings.autoStartBackend,
                      onAutoStartChanged: (v) =>
                          settings.setAutoStartBackend(v),
                      restarting: _restarting,
                      canRestart: widget.onRestartBackend != null,
                      onRestart: _restart,
                      onApplyPort: _applyPort,
                    ),
                    const SizedBox(height: 24),

                    _SectionTitle(
                      icon: Icons.fiber_manual_record,
                      label: tr('settings.sectionRecording'),
                    ),
                    const SizedBox(height: 12),
                    const RecordingSettingsSection(),
                    const SizedBox(height: 24),

                    _SectionTitle(
                      icon: Icons.cleaning_services,
                      label: tr('settings.sectionCache'),
                    ),
                    const SizedBox(height: 12),
                    const _CachePanel(),
                    const SizedBox(height: 24),

                    _SectionTitle(
                      icon: Icons.palette_outlined,
                      label: tr('settings.sectionAppearance'),
                    ),
                    const SizedBox(height: 12),
                    const _AppearancePanel(),
                    const SizedBox(height: 24),

                    _SectionTitle(
                      icon: Icons.info_outline,
                      label: tr('settings.sectionAbout'),
                    ),
                    const SizedBox(height: 12),
                    const _AboutPanel(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Center(
      child: Transform.translate(
        offset: _dragOffset,
        child: window,
      ),
    );
  }
}

/// Window title bar — doubles as the drag handle so the panel can be
/// moved like a detached window.
class _TitleBar extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(Offset delta) onDrag;

  const _TitleBar({required this.onClose, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onPanUpdate: (d) => onDrag(d.delta),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.4),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.settings_outlined, size: 18, color: _accent),
            const SizedBox(width: 10),
            Text(
              tr('settings.title'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: tr('close'),
              color: theme.colorScheme.onSurfaceVariant,
              splashRadius: 18,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading — green icon + bold label (matches launch page).
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: _accent, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Dark, bordered content panel — replaces Material Card.
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

/// Status pill — green running / red stopped / gray checking.
class _StatusPill extends StatelessWidget {
  final bool checking;
  final bool reachable;
  const _StatusPill({required this.checking, required this.reachable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    final String text;
    if (checking) {
      color = theme.colorScheme.onSurfaceVariant;
      text = tr('settings.backend.checking');
    } else if (reachable) {
      color = _accentBorder;
      text = tr('settings.backend.statusRunning');
    } else {
      color = Colors.redAccent;
      text = tr('settings.backend.statusStopped');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green filled button used across the dialog.
class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color accent;

  const _DialogButton({
    required this.label,
    this.onPressed,
    this.loading = false,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SegOption<T> {
  final T value;
  final String label;
  const _SegOption(this.value, this.label);
}

/// Custom two-option pill toggle (replaces Material SegmentedButton).
class _Segmented<T> extends StatelessWidget {
  final List<_SegOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color accent;

  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final sel = opt.value == selected;
          return GestureDetector(
            onTap: () => onChanged(opt.value),
            child: Container(
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: sel ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    color: sel
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BackendPanel extends StatelessWidget {
  final bool checking;
  final bool reachable;
  final Map<String, dynamic>? backendInfo;
  final TextEditingController portController;
  final String? portError;
  final bool canEditPort;
  final bool autoStart;
  final ValueChanged<bool> onAutoStartChanged;
  final bool restarting;
  final bool canRestart;
  final VoidCallback onRestart;
  final VoidCallback onApplyPort;

  const _BackendPanel({
    required this.checking,
    required this.reachable,
    required this.backendInfo,
    required this.portController,
    required this.portError,
    required this.canEditPort,
    required this.autoStart,
    required this.onAutoStartChanged,
    required this.restarting,
    required this.canRestart,
    required this.onRestart,
    required this.onApplyPort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr('settings.backend.bridge'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              _StatusPill(checking: checking, reachable: reachable),
            ],
          ),
          const SizedBox(height: 14),

          // Port
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tr('settings.backend.port'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  width: 140,
                  child: TextField(
                    controller: portController,
                    enabled: canEditPort,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      hintText: tr('settings.backend.portHint'),
                      errorText: portError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => onApplyPort(),
                  ),
                ),
              ),
              if (canEditPort) ...[
                const SizedBox(width: 8),
                _DialogButton(
                  label: tr('settings.backend.apply'),
                  onPressed: onApplyPort,
                  accent: _accent,
                ),
              ],
            ],
          ),
          if (portError == null && canEditPort)
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 4),
              child: Text(
                tr('settings.backend.portHint'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 12),

          // Auto-start
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('settings.backend.autoStart'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('settings.backend.autoStartDesc'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: autoStart,
                activeColor: _accent,
                onChanged: onAutoStartChanged,
              ),
            ],
          ),

          // Restart
          if (canRestart) ...[
            const SizedBox(height: 12),
            _DialogButton(
              label: restarting
                  ? tr('settings.backend.restarting')
                  : tr('settings.backend.restart'),
              onPressed: restarting ? null : onRestart,
              loading: restarting,
              accent: _accent,
            ),
          ],

          // Runtime info
          if (backendInfo != null) ...[
            const SizedBox(height: 14),
            Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              tr('settings.backend.runtimeInfo'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: tr('settings.backend.pid'),
              value: backendInfo!['pid']?.toString() ?? '—',
            ),
            _InfoRow(
              label: tr('settings.backend.started'),
              value: _formatStarted(backendInfo!['started']?.toString()),
            ),
          ],
        ],
      ),
    );
  }
}

class _CachePanel extends StatelessWidget {
  const _CachePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      child: Row(
        children: [
          const Icon(Icons.delete_sweep_outlined,
              color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('settings.cache.cleanup'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('settings.cache.cleanupDesc'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DialogButton(
            label: tr('settings.cache.cleanupButton'),
            onPressed: () => showCleanupCacheDialog(context),
            accent: _accent,
          ),
        ],
      ),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('settings.appearance.theme'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              _Segmented<bool>(
                selected: themeProvider.isDark,
                onChanged: (v) => themeProvider.setDark(v),
                accent: _accent,
                options: [
                  _SegOption(true, tr('settings.appearance.themeDark')),
                  _SegOption(false, tr('settings.appearance.themeLight')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('settings.appearance.language'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              _Segmented<String>(
                selected: locale.currentLang,
                onChanged: (v) => locale.setLocale(v),
                accent: _accent,
                options: [
                  _SegOption('zh', tr('settings.appearance.langZh')),
                  _SegOption('en', tr('settings.appearance.langEn')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.adb, color: _accent),
              const SizedBox(width: 8),
              Text(
                tr('settings.about.appName'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: tr('settings.about.version'), value: kAppVersion),
          _InfoRow(label: tr('settings.about.build'), value: kAppBuild),
          const SizedBox(height: 4),
          Text(
            tr('settings.about.copyright'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _formatStarted(String? started) {
  if (started == null || started.isEmpty) return '—';
  final dt = DateTime.tryParse(started);
  if (dt == null) return started;
  final local = dt.toLocal();
  final y = local.year.toString();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
