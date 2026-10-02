// Settings — reusable floating "window" dialog (simulates a detached
// multi-window panel). Opened from both the launch page and the main
// app, so it is intentionally a dialog, not a route.
//
// Visual language comes from lib/design/ (AppPalette / AppPanel /
// AppSectionLabel / tokens): panel surfaces, palette accent, bordered
// panels, custom rows / toggles / pill-segments — deliberately NOT the
// stock Material Card / AppBar / SwitchListTile / SegmentedButton widgets.
// The dialog previously carried its own GitHub-green hex accent, which
// fought the single-track palette; it now reads palette.accent.
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
import '../design/app_palette.dart';
import '../design/design_tokens.dart';
import '../design/panel.dart';
import '../design/section_label.dart';
import '../design/topbar.dart';
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
    final palette = context.palette;
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
        color: palette.panel,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palette.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(64),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 16),
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
                padding: const EdgeInsets.all(AppSpacing.xl),
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
    final palette = context.palette;
    return GestureDetector(
      onPanUpdate: (d) => onDrag(d.delta),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.raised,
          border: Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: Row(
          children: [
            Icon(Icons.settings_outlined, size: 18, color: palette.accent),
            const SizedBox(width: AppSpacing.md),
            Text(
              tr('settings.title'),
              style: TextStyle(
                fontSize: AppFontSize.title,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            const Spacer(),
            AppTopbarIconButton(
              icon: Icons.close,
              tooltip: tr('close'),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading — palette-accent icon + [AppSectionLabel].
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.palette.accent, size: 18),
        const SizedBox(width: AppSpacing.sm),
        AppSectionLabel(label),
      ],
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
    final palette = context.palette;
    final Color color;
    final String text;
    if (checking) {
      color = palette.textSecondary;
      text = tr('settings.backend.checking');
    } else if (reachable) {
      color = palette.online;
      text = tr('settings.backend.statusRunning');
    } else {
      color = palette.red;
      text = tr('settings.backend.statusStopped');
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
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
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: TextStyle(
              fontSize: AppFontSize.body,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Accent-filled button used across the dialog.
class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _DialogButton({
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return SizedBox(
      height: 36,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
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
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.onAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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

  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final sel = opt.value == selected;
          return GestureDetector(
            onTap: () => onChanged(opt.value),
            child: Container(
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: sel ? palette.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    color: sel ? palette.onAccent : palette.textSecondary,
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
    final palette = context.palette;
    return SizedBox(
      width: double.infinity,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: palette.raised,
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
                const SizedBox(width: AppSpacing.md),
                _StatusPill(checking: checking, reachable: reachable),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Port
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
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
                        fillColor: palette.panel,
                        hintText: tr('settings.backend.portHint'),
                        errorText: portError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: palette.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: palette.hairline),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      onSubmitted: (_) => onApplyPort(),
                    ),
                  ),
                ),
                if (canEditPort) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _DialogButton(
                    label: tr('settings.backend.apply'),
                    onPressed: onApplyPort,
                  ),
                ],
              ],
            ),
            if (portError == null && canEditPort)
              Padding(
                padding: const EdgeInsets.only(
                  left: 64,
                  top: AppSpacing.xs,
                ),
                child: Text(
                  tr('settings.backend.portHint'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.textSecondary),
                ),
              ),
            const SizedBox(height: AppSpacing.md),

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
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: autoStart,
                  activeThumbColor: palette.accent,
                  onChanged: onAutoStartChanged,
                ),
              ],
            ),

            // Restart
            if (canRestart) ...[
              const SizedBox(height: AppSpacing.md),
              _DialogButton(
                label: restarting
                    ? tr('settings.backend.restarting')
                    : tr('settings.backend.restart'),
                onPressed: restarting ? null : onRestart,
                loading: restarting,
              ),
            ],

            // Runtime info
            if (backendInfo != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Divider(color: palette.hairline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('settings.backend.runtimeInfo'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
      ),
    );
  }
}

class _CachePanel extends StatelessWidget {
  const _CachePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return SizedBox(
      width: double.infinity,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: palette.raised,
        child: Row(
          children: [
            Icon(Icons.delete_sweep_outlined,
                color: palette.accent, size: 20),
            const SizedBox(width: AppSpacing.md),
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
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _DialogButton(
              label: tr('settings.cache.cleanupButton'),
              onPressed: () => showCleanupCacheDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final themeProvider = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    return SizedBox(
      width: double.infinity,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: palette.raised,
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
                  options: [
                    _SegOption(true, tr('settings.appearance.themeDark')),
                    _SegOption(false, tr('settings.appearance.themeLight')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
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
                  options: [
                    _SegOption('zh', tr('settings.appearance.langZh')),
                    _SegOption('en', tr('settings.appearance.langEn')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return SizedBox(
      width: double.infinity,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: palette.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.adb, color: palette.accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  tr('settings.about.appName'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoRow(label: tr('settings.about.version'), value: kAppVersion),
            _InfoRow(label: tr('settings.about.build'), value: kAppBuild),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('settings.about.copyright'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
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
