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
// Rendered as a section inside SettingsScreen. Kept as its own
// widget so the file is digestible and the per-feature logic stays
// together; the settings page just lays three of these out.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/recording_settings_provider.dart';

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
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon,
                  size: 24,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                                .withAlpha(200)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
