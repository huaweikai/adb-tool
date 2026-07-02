// Settings hub — global page for cross-cutting app preferences.
// Replaces the previous "录屏设置" sidebar entry (which was just
// the recording method picker); now houses three sections:
//
//   * 录屏 (Recording) — adb / scrcpy method picker. The scrcpy
//     sandbox directory is owned by the backend; no UI for it.
//   * 缓存 (Cache) — "清理所有 adb-tool 缓存" lifted from
//     EmulatorSettingsScreen (the only entry point on that page
//     that wasn't emulator-specific). Pops the existing
//     CleanupCacheDialog.
//   * 关于 (About) — app version, sourced from pubspec.yaml (kept
//     in sync manually so we don't pull in package_info_plus just
//     to read a string).
//
// Layout: SingleChildScrollView of sectioned Cards, matching
// EmulatorSettingsScreen's shape so the two settings pages feel
// like siblings.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../widgets/cleanup_cache_dialog.dart';
import '../widgets/recording_settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings.title')),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.fiber_manual_record,
              label: tr('settings.sectionRecording'),
            ),
            const SizedBox(height: 12),
            const RecordingSettingsSection(),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.cleaning_services,
              label: tr('settings.sectionCache'),
            ),
            const SizedBox(height: 8),
            _CacheSection(),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.info_outline,
              label: tr('settings.sectionAbout'),
            ),
            const SizedBox(height: 8),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
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

class _CacheSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.delete_sweep_outlined,
                color: theme.colorScheme.onSurfaceVariant),
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: () => showCleanupCacheDialog(context),
              icon: const Icon(Icons.cleaning_services, size: 16),
              label: Text(tr('settings.cache.cleanupButton')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.adb, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('settings.about.appName'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AboutRow(
              label: tr('settings.about.version'),
              value: kAppVersion,
            ),
            _AboutRow(
              label: tr('settings.about.build'),
              value: kAppBuild,
            ),
            const SizedBox(height: 4),
            Text(
              tr('settings.about.copyright'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
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

// Version pulled from pubspec.yaml at build time. The Flutter
// desktop runners don't expose a runtime package_info API without
// adding package_info_plus as a dependency, which would be a heavy
// ask for a single string. Keep these in sync with pubspec.yaml's
// `version:` field by hand (the CI release script does the
// counterpart bump on the artifact side).
const String kAppVersion = '1.0.1';
const String kAppBuild = '2';
