// Emulator settings screen.
// Main screen for managing Android emulator configuration.
import 'dart:async';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:flutter/material.dart';

import '../widgets/skeleton.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../providers/emulator_image_provider.dart';
import '../providers/emulator_instance_provider.dart';
import '../providers/emulator_engine_provider.dart';
import '../providers/emulator_java_provider.dart';
import '../services/api_client.dart';
import '../services/api/emulator_image_api.dart';
import '../widgets/emulator_engine_card.dart';
import '../widgets/emulator_java_card.dart';
import '../widgets/emulator_image_card.dart';
import '../widgets/add_image_dialog.dart';
import '../widgets/emulator_instance_card.dart';
import '../widgets/create_instance_dialog.dart';
import '../widgets/mirror_config_card.dart';

class EmulatorSettingsScreen extends StatefulWidget {
  const EmulatorSettingsScreen({super.key});

  @override
  State<EmulatorSettingsScreen> createState() => _EmulatorSettingsScreenState();
}

class _EmulatorSettingsScreenState extends State<EmulatorSettingsScreen> {
  // SDK-driven system image install — shows progress in the image section
  // until the job finishes, then we refresh the image list so the new
  // entry shows up. Separate from engine_card's emulator install, which
  // tracks `emulator` specifically.
  SDKInstallJob? _systemImageInstallJob;
  Timer? _systemImageInstallPoller;

  @override
  void dispose() {
    _systemImageInstallPoller?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Pull persisted state from backend on load so SDK / Java selections and
    // imported images are restored without requiring a manual scan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmulatorEngineProvider>().refreshStatus();
      context.read<EmulatorJavaProvider>().refreshStatus();
      context.read<EmulatorImageProvider>().loadImages();
      context.read<EmulatorInstanceProvider>().fetchInstances();
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final imageProvider = context.watch<EmulatorImageProvider>();
    final instanceProvider = context.watch<EmulatorInstanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('emulatorSettings.title')),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MirrorConfigCard(),
            const SizedBox(height: 16),
            const EmulatorEngineCard(),
            const SizedBox(height: 16),
            const EmulatorJavaCard(),
            const SizedBox(height: 24),
            _buildInstanceSection(context, instanceProvider),
            const SizedBox(height: 24),
            _buildImageSection(context, imageProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildInstanceSection(
      BuildContext context, EmulatorInstanceProvider provider) {
    final theme = Theme.of(context);
    // Block "create instance" when the engine isn't fully ready — we need
    // a working emulator binary + AVD manager to actually launch one.
    final engineProvider = context.watch<EmulatorEngineProvider>();
    final engineStatus = engineProvider.serverStatus;
    final emulatorReady = engineStatus != null &&
        engineStatus.emulatorPath != null &&
        engineStatus.emulatorPath!.isNotEmpty &&
        engineStatus.emulatorVersion != null &&
        engineStatus.emulatorVersion!.isNotEmpty;
    final canCreate = emulatorReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smartphone, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              tr('emulatorSettings.instanceSection'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Tooltip(
              message:
                  canCreate ? '' : tr('emulatorSettings.installEmulatorHint'),
              child: FilledButton.icon(
                onPressed:
                    canCreate ? () => _showCreateInstanceDialog(context) : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('emulatorSettings.createInstance')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInstanceList(context, provider),
      ],
    );
  }

  Widget _buildInstanceList(
      BuildContext context, EmulatorInstanceProvider provider) {
    final instances = provider.instances;

    if (provider.isLoading) {
      return const Card(
        child: SkeletonList(count: 4),
      );
    }

    if (instances.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.phone_android,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('emulatorSettings.emptyInstance'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('emulatorSettings.emptyInstanceHint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withAlpha(150),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: instances.map((instance) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EmulatorInstanceCard(instance: instance),
        );
      }).toList(),
    );
  }

  Widget _buildImageSection(
      BuildContext context, EmulatorImageProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storage, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              tr('emulatorSettings.imageSection'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _showAddImageDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr('emulatorSettings.addImage')),
            ),
          ],
        ),
        if (_systemImageInstallJob != null) ...[
          const SizedBox(height: 12),
          _buildSystemImageInstallProgress(context),
        ],
        const SizedBox(height: 12),
        _buildImageList(context, provider),
      ],
    );
  }

  /// Live progress card for the in-flight SDK system-image install. Shown
  /// between the section header and the image list whenever there's an
  /// active job — disappears once the job is done and we've shown the
  /// final status for a few seconds.
  Widget _buildSystemImageInstallProgress(BuildContext context) {
    final job = _systemImageInstallJob!;
    final running = job.isRunning;
    final isError = job.status == 'error';
    final isDone = job.status == 'completed';
    final pkg = job.packages.isNotEmpty ? job.packages.first : 'system image';

    Color barColor;
    IconData icon;
    if (isError) {
      barColor = Colors.red;
      icon = Icons.error_outline;
    } else if (isDone) {
      barColor = Colors.green;
      icon = Icons.check_circle;
    } else {
      barColor = Colors.blue;
      icon = Icons.downloading;
    }

    return Card(
      color: barColor.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: barColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isError
                        ? tr('emulatorSettings.install.downloadError',
                            {'error': job.error ?? pkg})
                        : isDone
                            ? tr('emulatorSettings.install.downloadDone',
                                {'pkg': pkg})
                            : (job.message.isNotEmpty
                                ? job.message
                                : tr('emulatorSettings.install.downloadPreparing')),
                    style: TextStyle(
                        fontSize: 13,
                        color: barColor,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(job.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: barColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: running && job.progress > 0
                    ? job.progress
                    : (running ? null : 1.0),
                minHeight: 6,
                backgroundColor: barColor.withAlpha(40),
                color: barColor,
              ),
            ),
            if (pkg.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                pkg,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageList(BuildContext context, EmulatorImageProvider provider) {
    final images = provider.images;

    if (images.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.cloud_download,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('emulatorSettings.emptyImage'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('emulatorSettings.emptyImageHint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withAlpha(150),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: images.map((image) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EmulatorImageCard(
            image: image,
            onDelete: () => _confirmDelete(context, image.id),
            onCreateInstance:
                image.isReady ? () => _showCreateInstanceDialog(context) : null,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddImageDialog(BuildContext context) async {
    final provider = context.read<EmulatorImageProvider>();
    await provider.loadSources();
    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddImageDialog(
        savedSources: provider.sources,
        onRemoveSource: (url) async {
          await provider.removeSource(url);
          if (context.mounted) {
            // ponytail: M11 — pop() then immediately showDialog() races
            // the navigator's exit transition (causes animation overlap
            // and on some Flutter versions "Navigator is currently
            // transitioning" assertion). Defer the re-show to the next
            // frame.
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _showAddImageDialog(context);
            });
          }
        },
      ),
    );

    if (result != null && context.mounted) {
      if (result['source'] == 'url') {
        await provider.addImage(url: result['url']);
      } else if (result['source'] == 'sdk') {
        // 通过 sdkmanager 下载 — 调 SDKInstaller 异步装包
        final apiLevel = result['apiLevel'] as int;
        final arch = result['arch'] as String;
        final variant = result['variant'] as String;
        final package = 'system-images;android-$apiLevel;$variant;$arch';
        await _installSystemImageViaSdk(context, package);
      } else {
        final path = result['path'] as String;
        final isZip = result['isZip'] == true;
        final ok = isZip
            ? await provider.importFromZip(path)
            : await provider.importFromPath(path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? tr('emulatorSettings.import.success')
                  : tr('emulatorSettings.import.failure', {
                      'error': provider.errorMessage ??
                          tr('emulatorSettings.common.unknownError'),
                    }),
            ),
          ),
        );
      }
    }
  }

  /// Start an sdkmanager-driven system image install. We kick off the job
  /// and poll its progress every 800ms — both to drive the progress bar
  /// in the image section and so the user can see when it finishes. On
  /// completion we refresh the image list so the new entry shows up.
  Future<void> _installSystemImageViaSdk(
    BuildContext context,
    String package,
  ) async {
    final api = context.read<ApiClient>();
    final imageProvider = context.read<EmulatorImageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr('emulatorSettings.install.kickoff', {'package': package})),
        duration: const Duration(seconds: 2),
      ),
    );

    SDKInstallJob job;
    try {
      job = await api.installPackages([package]);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr('emulatorSettings.install.kickoffError', {'error': '$e'}))),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _systemImageInstallJob = job);

    _systemImageInstallPoller?.cancel();
    _systemImageInstallPoller =
        Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      final current = _systemImageInstallJob;
      if (current == null || !current.isRunning) {
        timer.cancel();
        return;
      }
      try {
        final updated = await api.getInstallStatus(current.id);
        if (!mounted) return;
        setState(() => _systemImageInstallJob = updated);
        if (updated.isDone) {
          timer.cancel();
          if (updated.status == 'completed') {
            await imageProvider.refreshImages();
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(tr('emulatorSettings.install.completed', {'package': package}))),
              );
            }
          } else if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(tr('emulatorSettings.install.failed', {
                'error': updated.error ??
                    tr('emulatorSettings.common.unknownError'),
              }))),
            );
          }
          // Drop the job after a short delay so the user can see the final
          // status; then clear.
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _systemImageInstallJob = null);
          });
        }
      } catch (e) {
        // network blip — keep polling
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, String imageId) async {
    final imageProvider = context.read<EmulatorImageProvider>();
    final image =
        imageProvider.images.where((e) => e.id == imageId).firstOrNull;
    final sizeText = image != null ? image.fileSizeFormatted : '';
    final managed = image?.managed == true;
    final sizeLine = sizeText.isNotEmpty
        ? tr('emulatorSettings.delete.sizeLine', {'size': sizeText})
        : '';
    final pathLine = (image?.localPath.isNotEmpty ?? false)
        ? tr('emulatorSettings.delete.pathLine', {'path': image!.localPath})
        : '';
    final pathLineNoNl = (image?.localPath.isNotEmpty ?? false)
        ? tr('emulatorSettings.delete.pathLineNoNl', {'path': image!.localPath})
        : '';
    final name = image?.displayName ?? imageId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 32),
        title: Text(managed
            ? tr('emulatorSettings.delete.titleManaged')
            : tr('emulatorSettings.delete.titleRegistryOnly')),
        content: Text(
          managed
              ? tr('emulatorSettings.delete.bodyManaged', {
                  'name': name,
                  'sizeLine': sizeLine,
                  'pathLine': pathLine,
                })
              : tr('emulatorSettings.delete.bodyRegistryOnly', {
                  'name': name,
                  'pathLine': pathLineNoNl,
                }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('emulatorSettings.delete.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(managed
                ? tr('emulatorSettings.delete.confirmManaged')
                : tr('emulatorSettings.delete.confirmRegistryOnly')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await imageProvider.deleteImage(imageId);
      } on ImageInUseException catch (e) {
        if (!context.mounted) return;
        final users = e.inUseBy.isEmpty
            ? ''
            : '（${e.inUseBy.join('、')}）';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('emulatorSettings.delete.inUse',
                  {'users': users}))),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    tr('emulatorSettings.delete.failure', {'error': '$e'}))),
          );
        }
      }
    }
  }

  Future<void> _showCreateInstanceDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const CreateInstanceDialog(),
    );
  }
}
