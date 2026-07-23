// Recording method picker — the "录屏" section widget inside the
// Settings page. Lets the user toggle between adb screenrecord
// (legacy, always-available) and the scrcpy windowless recording
// path. The scrcpy sandbox directory is owned by the backend
// (see ScrcpyRecordingSandboxDir in adb_scrcpy_record.go), so the
// UI no longer needs a path picker — files land in
// ~/.adb-tool/scrcpy_recordings/ during recording, and the user
// picks a final destination through the system save dialog at
// stop time (mirroring the adb flow).
//
// Rendered as a section inside the settings dialog. Kept as its own
// widget so the file is digestible and the per-feature logic stays
// together; the settings page just lays three of these out.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/recording_settings_provider.dart';

/// Accent colors — keep in sync with lib/screens/launch_page.dart (64:2).
const Color _accent = Color(0xFF2EA043);
const Color _accentBorder = Color(0xFF3FB950);

class RecordingSettingsSection extends StatelessWidget {
  const RecordingSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final settings = context.watch<RecordingSettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MethodCard(
          icon: Icons.adb,
          title: tr('settings.recording.methodAdb'),
          description: tr('settings.recording.methodAdbDesc'),
          selected: settings.method == ScreenRecordMethod.adb,
          onTap: () async {
            await settings.setMethod(ScreenRecordMethod.adb);
            if (!context.mounted) return;
            _showSavedToast(context);
          },
        ),
        const SizedBox(height: 8),
        _MethodCard(
          icon: Icons.cast,
          title: tr('settings.recording.methodScrcpy'),
          description: tr('settings.recording.methodScrcpyDesc'),
          selected: settings.method == ScreenRecordMethod.scrcpy,
          onTap: () async {
            await settings.setMethod(ScreenRecordMethod.scrcpy);
            if (!context.mounted) return;
            _showSavedToast(context);
          },
        ),
      ],
    );
  }

  void _showSavedToast(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('settings.recording.savedToast')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        selected ? _accentBorder : theme.colorScheme.outlineVariant;
    final iconColor =
        selected ? _accentBorder : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.10)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle,
                    color: _accentBorder, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
