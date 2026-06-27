// Emulator Java runtime status card widget.
// Displays and manages Java runtime configuration.
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../providers/emulator_java_provider.dart';
import '../services/api/emulator_java_api.dart';

class EmulatorJavaCard extends StatelessWidget {
  const EmulatorJavaCard({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final provider = context.watch<EmulatorJavaProvider>();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coffee, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('javaCard.title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(context, provider),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.selectedInvalid) ...[
              _buildSelectionInvalidWarning(context),
              const SizedBox(height: 12),
            ],
            _buildJavaInfo(context, provider),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(context, provider),
            ],
            if (provider.isDownloading) ...[
              const SizedBox(height: 12),
              _buildDownloadProgress(context, provider),
            ],
            const SizedBox(height: 16),
            _buildActions(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, EmulatorJavaProvider provider) {
    Color color;
    String label;
    IconData icon;

    switch (provider.javaStatus) {
      case JavaStatus.found:
        color = Colors.green;
        label = tr('engineCard.status.ready');
        icon = Icons.check_circle;
      case JavaStatus.notFound:
        color = Colors.orange;
        label = tr('javaCard.notFound');
        icon = Icons.warning;
      case JavaStatus.downloading:
        color = Colors.blue;
        label = tr('imageCard.downloading');
        icon = Icons.downloading;
      case JavaStatus.checking:
        color = Colors.blue;
        label = tr('javaCard.detecting');
        icon = Icons.sync;
      case JavaStatus.error:
        color = Colors.red;
        label = tr('imageCard.error');
        icon = Icons.error;
      case JavaStatus.unknown:
        color = Colors.grey;
        label = tr('javaCard.unknown');
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildJavaInfo(BuildContext context, EmulatorJavaProvider provider) {
    final runtimes = provider.runtimes;

    if (runtimes.isEmpty) {
      return Text(
        tr('javaCard.notDetected'),
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final selectedPath = provider.selectedPath;
    final effectivePath = provider.selectedInvalid
        ? null
        : (selectedPath != null && selectedPath.isNotEmpty)
            ? selectedPath
            : provider.status?.systemJava?.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('javaCard.runtimeListPrompt', {'count': '${runtimes.length}'}),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...runtimes.map(
          (rt) => _buildRuntimeTile(context, provider, rt, effectivePath),
        ),
      ],
    );
  }

  Widget _buildRuntimeTile(
    BuildContext context,
    EmulatorJavaProvider provider,
    JavaRuntimeInfo rt,
    String? effectivePath,
  ) {
    final theme = Theme.of(context);
    final isSelected = rt.path == effectivePath;
    final isBusy = provider.javaStatus == JavaStatus.checking;

    final subtitleParts = <String>[
      if (rt.vendor != null && rt.vendor!.isNotEmpty) rt.vendor!,
      if (rt.arch != null && rt.arch!.isNotEmpty) rt.arch!,
      if (rt.isEmbedded) tr('javaCard.downloaded'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withAlpha(20) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(120)
              : theme.dividerColor.withAlpha(80),
        ),
      ),
      child: ListTile(
        dense: true,
        enabled: !isBusy,
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: isSelected ? theme.colorScheme.primary : null,
          size: 20,
        ),
        onTap: (isBusy || isSelected) ? null : () => provider.select(rt.path),
        title: Text(
          rt.version ?? tr('javaCard.unknownVersion'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' · '),
                style: const TextStyle(fontSize: 11),
              ),
            Text(
              rt.path,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionInvalidWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('javaCard.selectedInvalid'),
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, EmulatorJavaProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(BuildContext context, EmulatorJavaProvider provider) {
    final progress = provider.downloadProgress;
    final percent = (progress * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(width: 8),
            Text('$percent%', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () => provider.cancelDownload(),
              child: Text(tr('javaCard.cancelDownload')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, EmulatorJavaProvider provider) {
    final isDownloading = provider.isDownloading;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: isDownloading ? null : () => provider.refreshStatus(),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(tr('javaCard.redetect')),
        ),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : () => _showDownloadDialog(context),
          icon: const Icon(Icons.download, size: 18),
          label: Text(tr('javaCard.downloadJava')),
        ),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : () => _importLocalZip(context, provider),
          icon: const Icon(Icons.archive_outlined, size: 18),
          label: Text(tr('javaCard.importZip')),
        ),
      ],
    );
  }

  Future<void> _importLocalZip(
      BuildContext context, EmulatorJavaProvider provider) async {
    final XFile? picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Java runtime zip', extensions: ['zip']),
      ],
    );
    if (picked == null || !context.mounted) return;

    // Suggest an id derived from the file name. The backend sanitizes /
    // rejects anything weird, so a user-edited value is still safe.
    final base = picked.name.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
    final idController = TextEditingController(text: 'imported-$base');

    final String? id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('javaCard.importZipTitle')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('javaCard.filePicked', {'name': picked.name}),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: idController,
                decoration: InputDecoration(
                  labelText: tr('javaCard.runtimeID'),
                  helperText: tr('javaCard.runtimeIDHint'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, idController.text.trim()),
            child: Text(tr('javaCard.import')),
          ),
        ],
      ),
    );
    if (id == null || id.isEmpty || !context.mounted) return;

    final ok = await provider.importJava(id: id, localPath: picked.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? tr('javaCard.importedSnack', {'id': id})
            : tr('javaCard.importFailed', {
                'error': provider.errorMessage ??
                    tr('emulatorSettings.common.unknownError'),
              })),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showDownloadDialog(BuildContext context) async {
    final urlController = TextEditingController();
    String selectedVersion = '17';
    String? selectedId = 'temurin-17';

    // Pull the backend's pre-resolved default list so the dialog can show
    // "Download Temurin 17" one-click buttons instead of forcing the user
    // to paste an Adoptium URL.
    final defaults = context.read<EmulatorJavaProvider>().status?.defaultDownloads ?? const <JavaDownloadOption>[];
    if (defaults.isNotEmpty) {
      selectedVersion = defaults.first.version;
      selectedId = defaults.first.id;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          JavaDownloadOption? matched;
          for (final d in defaults) {
            if (d.version == selectedVersion) {
              matched = d;
              break;
            }
          }

          return AlertDialog(
            title: Text(tr('javaCard.downloadTitle')),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('javaCard.downloadHelp'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedVersion,
                    decoration: InputDecoration(
                      labelText: tr('javaCard.versionLabel'),
                    ),
                    items: defaults
                        .map((d) => DropdownMenuItem(
                              value: d.version,
                              child: Text('Java ${d.version}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedVersion = value;
                          final m = defaults.firstWhere(
                            (d) => d.version == value,
                            orElse: () => defaults.first,
                          );
                          selectedId = m.id;
                          urlController.text = m.url;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: tr('javaCard.urlLabel'),
                      hintText: tr('javaCard.urlHint'),
                    ),
                  ),
                  if (matched != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('javaCard.sourceLabel', {'name': matched.name}),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  final provider = context.read<EmulatorJavaProvider>();
                  final ok = await provider.download(
                    id: selectedId ?? 'temurin-$selectedVersion',
                    url: urlController.text.trim().isEmpty
                        ? null
                        : urlController.text.trim(),
                    version: selectedVersion,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? tr('javaCard.kickoff', {'version': selectedVersion})
                          : tr('javaCard.kickoffFailed', {
                              'error': provider.errorMessage ??
                                  tr('emulatorSettings.common.unknownError'),
                            })),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(tr('engineCard.startDownload')),
              ),
            ],
          );
        },
      ),
    );
  }
}
