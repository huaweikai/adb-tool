// Recording settings — global page for choosing the screen-recording
// method (adb screenrecord vs the new scrcpy windowless path) and
// the scrcpy output directory. Persisted on AppStates via
// RecordingSettingsProvider; no per-device state.
//
// Layout mirrors EmulatorSettingsScreen — single scrollable column
// of Cards. The two method cards are mutually exclusive (one card
// highlighted = currently selected) so the user can read both
// descriptions before picking. The directory picker is only visible
// when scrcpy mode is selected.
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/recording_settings_provider.dart';

class RecordingSettingsScreen extends StatelessWidget {
  const RecordingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final settings = context.watch<RecordingSettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('screenRecord.title')),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMethodSection(context, settings),
            const SizedBox(height: 16),
            _buildOutputDirSection(context, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSection(
      BuildContext context, RecordingSettingsProvider settings) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fiber_manual_record, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              tr('screenRecord.method'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MethodCard(
          icon: Icons.adb,
          title: tr('screenRecord.methodAdb'),
          description: tr('screenRecord.methodAdbDesc'),
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
          title: tr('screenRecord.methodScrcpy'),
          description: tr('screenRecord.methodScrcpyDesc'),
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

  Widget _buildOutputDirSection(
      BuildContext context, RecordingSettingsProvider settings) {
    final theme = Theme.of(context);
    final isScrcpy = settings.method == ScreenRecordMethod.scrcpy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_open, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              tr('screenRecord.scrcpyOutputDir'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr('screenRecord.dirHelp'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isScrcpy
                        ? (settings.outputDir ?? tr('screenRecord.dirNotSet'))
                        : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: settings.outputDir != null && settings.outputDir!.isNotEmpty
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: isScrcpy
                      ? () => _pickDirectory(context, settings)
                      : null,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: Text(tr('screenRecord.chooseDir')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory(
      BuildContext context, RecordingSettingsProvider settings) async {
    final picked = await getDirectoryPath();
    if (picked == null) return;
    // Sanity check that the directory actually exists and is writable
    // before we save it. The backend re-checks on each start call,
    // but failing here too saves the user from a confusing flow
    // ("set dir → start → 'directory missing' 30s later").
    final dir = Directory(picked);
    if (!await dir.exists()) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, tr('screenRecord.dirMissing'));
      return;
    }
    try {
      final probe = File('${dir.path}/.adb-tool-write-probe');
      await probe.writeAsString('ok');
      await probe.delete();
    } catch (_) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, tr('screenRecord.dirMissing'));
      return;
    }
    await settings.setOutputDir(picked);
    if (!context.mounted) return;
    _showSavedToast(context);
  }

  void _showSavedToast(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('screenRecord.savedToast')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
