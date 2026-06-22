// Settings panel for the screen-mirror tab.
//
// Lives on the left side of the split layout in ScreenMirrorScreen.
// Exposes every scrcpy 4.0 option the user is likely to tweak, grouped
// by domain. Each control mutates the active device's ScrcpyOptions
// via ScrcpySettingsProvider, which persists to SharedPreferences
// immediately so a tab switch / app restart doesn't lose the setting.
//
// Design notes:
//   * The "common" controls (display ↔ camera, video size, audio
//     mute, window borderless, recording) are always visible.
//   * A single "Advanced" section folds the long tail so the panel
//     doesn't get scroll-fatigue on a small window.
//   * No "Apply" button — every change is persisted + sent on next
//     Start. scrcpy 4.0 doesn't support live mutation of most flags.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../models/scrcpy_options.dart';
import '../providers/scrcpy_settings_provider.dart';

class ScrcpySettingsPanel extends StatelessWidget {
  const ScrcpySettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ScrcpySettingsProvider>();
    final opts = settings.current ?? const ScrcpyOptions();
    return _PanelBody(opts: opts);
  }
}

class _PanelBody extends StatelessWidget {
  final ScrcpyOptions opts;
  const _PanelBody({required this.opts});

  void _mutate(BuildContext context, ScrcpyOptions Function(ScrcpyOptions) f) {
    context.read<ScrcpySettingsProvider>().update(f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Header row with reset button
        Row(
          children: [
            Text(
              tr('scrcpyPanelTitle'),
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  context.read<ScrcpySettingsProvider>().resetActiveToDefaults(),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(tr('scrcpyReset')),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // ── Video source (display vs camera) ─────────────────────
        _SectionHeader(text: tr('scrcpySectionVideoSource')),
        _SegmentedRow(
          value: opts.videoSource ?? 'display',
          options: const [
            ('display', Icons.smartphone),
            ('camera', Icons.camera_alt_outlined),
          ],
          labelBuilder: (v) =>
              v == 'display' ? tr('scrcpySourceDisplay') : tr('scrcpySourceCamera'),
          onChanged: (v) => _mutate(context, (o) => o.copyWith(videoSource: v)),
        ),
        if (opts.videoSource == 'camera') ..._cameraSection(context, opts),

        // ── Video ────────────────────────────────────────────────
        _SectionHeader(text: tr('scrcpySectionVideo')),
        _SliderRow(
          label: tr('scrcpyMaxSize'),
          value: opts.maxSize == 0 ? 1024 : opts.maxSize.toDouble(),
          min: 320,
          max: 2560,
          divisions: 16,
          suffix: 'px',
          allowUnset: true,
          isUnset: opts.maxSize == 0,
          onChanged: (v) => _mutate(context, (o) =>
              o.copyWith(maxSize: v.round())),
        ),
        _DropdownRow<String>(
          label: tr('scrcpyBitRate'),
          value: opts.videoBitRate ?? '8M',
          options: const ['1M', '2M', '4M', '8M', '12M', '16M', '24M'],
          onChanged: (v) => _mutate(context, (o) => o.copyWith(videoBitRate: v)),
        ),
        _SliderRow(
          label: tr('scrcpyMaxFps'),
          value: opts.maxFps == 0 ? 30 : opts.maxFps.toDouble(),
          min: 15,
          max: 120,
          divisions: 7,
          suffix: 'fps',
          allowUnset: false,
          isUnset: false,
          onChanged: (v) => _mutate(context, (o) =>
              o.copyWith(maxFps: v.round())),
        ),
        _DropdownRow<String>(
          label: tr('scrcpyCodec'),
          value: opts.videoCodec ?? 'h264',
          options: const ['h264', 'h265', 'av1'],
          onChanged: (v) => _mutate(context, (o) => o.copyWith(videoCodec: v)),
        ),

        // ── Audio ────────────────────────────────────────────────
        _SectionHeader(text: tr('scrcpySectionAudio')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyNoAudio')),
          value: opts.noAudio,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(noAudio: v)),
        ),
        if (!opts.noAudio)
          _DropdownRow<String>(
            label: tr('scrcpyAudioSource'),
            value: opts.audioSource ?? 'output',
            options: const [
              'output', 'playback', 'mic', 'mic-unprocessed',
              'mic-camcorder', 'mic-voice-recognition', 'mic-voice-communication',
            ],
            onChanged: (v) => _mutate(context, (o) => o.copyWith(audioSource: v)),
          ),

        // ── Window ───────────────────────────────────────────────
        _SectionHeader(text: tr('scrcpySectionWindow')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyBorderless')),
          value: opts.borderless,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(borderless: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyAlwaysOnTop')),
          value: opts.alwaysOnTop,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(alwaysOnTop: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyFullscreen')),
          value: opts.fullscreen,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(fullscreen: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyDisableScreensaver')),
          value: opts.disableScreensaver,
          onChanged: (v) => _mutate(
              context, (o) => o.copyWith(disableScreensaver: v)),
        ),

        // ── Control ──────────────────────────────────────────────
        _SectionHeader(text: tr('scrcpySectionControl')),
        _DropdownRow<String>(
          label: tr('scrcpyKeyboard'),
          value: opts.keyboard ?? 'sdk',
          options: const ['sdk', 'uhid', 'aoa', 'disabled'],
          onChanged: (v) => _mutate(context, (o) => o.copyWith(keyboard: v)),
        ),
        _DropdownRow<String>(
          label: tr('scrcpyMouse'),
          value: opts.mouse ?? 'sdk',
          options: const ['sdk', 'uhid', 'aoa', 'disabled'],
          onChanged: (v) => _mutate(context, (o) => o.copyWith(mouse: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyNoControl')),
          subtitle: Text(tr('scrcpyNoControlHint'),
              style: theme.textTheme.bodySmall),
          value: opts.noControl,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(noControl: v)),
        ),

        // ── Device ───────────────────────────────────────────────
        _SectionHeader(text: tr('scrcpySectionDevice')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyStayAwake')),
          value: opts.stayAwake,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(stayAwake: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyTurnScreenOff')),
          subtitle: Text(tr('scrcpyTurnScreenOffHint'),
              style: theme.textTheme.bodySmall),
          value: opts.turnScreenOff,
          onChanged: (v) => _mutate(
              context, (o) => o.copyWith(turnScreenOff: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyKeepActive')),
          subtitle: Text(tr('scrcpyKeepActiveHint'),
              style: theme.textTheme.bodySmall),
          value: opts.keepActive,
          onChanged: (v) => _mutate(context, (o) => o.copyWith(keepActive: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyShowTouches')),
          value: opts.showTouches,
          onChanged: (v) => _mutate(
              context, (o) => o.copyWith(showTouches: v)),
        ),

        // ── Recording (M2) ───────────────────────────────────────
        _SectionHeader(text: tr('scrcpySectionRecording')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('scrcpyRecordEnable')),
          value: (opts.record ?? '').isNotEmpty,
          onChanged: (v) {
            _mutate(context, (current) {
              if (v) {
                // Opening the switch: if record is null/empty (closed
                // state), use the default path. Plain `current.record
                // ?? _defaultRecordPath()` is NOT enough because the
                // closed state uses '' (empty string), not null, and
                // '' is non-null so ?? won't fall back.
                final saved = current.record;
                return current.copyWith(
                  record: (saved == null || saved.isEmpty)
                      ? _defaultRecordPath()
                      : saved,
                  recordFormat: current.recordFormat ?? 'mp4',
                );
              }
              // Closing: blank the record. recordFormat keeps its
              // previous value (copyWith's `??` semantics preserve
              // null arguments), which is fine — Switch state only
              // looks at `record`.
              return current.copyWith(
                record: '',
                recordFormat: null,
              );
            });
          },
        ),
        if ((opts.record ?? '').isNotEmpty) ...[
          _TextFieldRow(
            label: tr('scrcpyRecordPath'),
            value: opts.record ?? '',
            onChanged: (v) => _mutate(context, (o) => o.copyWith(record: v)),
          ),
          _DropdownRow<String>(
            label: tr('scrcpyRecordFormat'),
            value: opts.recordFormat ?? 'mp4',
            options: const ['mp4', 'mkv', 'm4a', 'opus', 'flac', 'wav'],
            onChanged: (v) =>
                _mutate(context, (o) => o.copyWith(recordFormat: v)),
          ),
          _SliderRow(
            label: tr('scrcpyTimeLimit'),
            value: opts.timeLimit == 0 ? 60 : opts.timeLimit.toDouble(),
            min: 10,
            max: 1800,
            divisions: 18,
            suffix: opts.timeLimit == 0 ? tr('scrcpyUnlimited') : 's',
            allowUnset: true,
            isUnset: opts.timeLimit == 0,
            onChanged: (v) => _mutate(context, (o) =>
                o.copyWith(timeLimit: v.round())),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _cameraSection(BuildContext context, ScrcpyOptions opts) {
    return [
      _DropdownRow<String>(
        label: tr('scrcpyCameraFacing'),
        value: opts.cameraFacing ?? 'back',
        options: const ['front', 'back', 'external', 'any'],
        onChanged: (v) => _mutate(context, (o) => o.copyWith(cameraFacing: v)),
      ),
      _SliderRow(
        label: tr('scrcpyCameraFps'),
        value: opts.cameraFps == 0 ? 30 : opts.cameraFps.toDouble(),
        min: 15,
        max: 240,
        divisions: 15,
        suffix: 'fps',
        allowUnset: false,
        isUnset: false,
        onChanged: (v) => _mutate(context, (o) =>
            o.copyWith(cameraFps: v.round())),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(tr('scrcpyCameraTorch')),
        value: opts.cameraTorch,
        onChanged: (v) =>
            _mutate(context, (o) => o.copyWith(cameraTorch: v)),
      ),
    ];
  }

  String _defaultRecordPath() {
    // Cross-platform best-effort default. On macOS/iOS/Android, path_provider
    // would give us the real Documents dir, but we don't need the recording
    // feature to be production-grade in M2 — the user can edit the path.
    return 'screen-record.mp4';
  }
}

// ── Small building blocks ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final String value;
  final List<(String, IconData)> options;
  final String Function(String) labelBuilder;
  final ValueChanged<String> onChanged;
  const _SegmentedRow({
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SegmentedButton<String>(
        segments: options
            .map((o) => ButtonSegment<String>(
                  value: o.$1,
                  icon: Icon(o.$2, size: 16),
                  label: Text(labelBuilder(o.$1)),
                ))
            .toList(),
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final bool allowUnset;
  final bool isUnset;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.allowUnset,
    required this.isUnset,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final displayValue = isUnset
        ? (allowUnset ? tr('scrcpyUnlimited') : '?')
        : '${value.toInt()}$suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
              Text(displayValue,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          Row(
            children: [
              if (allowUnset)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: isUnset ? tr('scrcpySetLimit') : tr('scrcpyUnsetLimit'),
                  icon: Icon(isUnset
                      ? Icons.lock_open
                      : Icons.lock_outline),
                  onPressed: () => onChanged(isUnset ? 60 : 0),
                ),
              Expanded(
                child: Slider(
                  // When "unlimited" is selected, pin the Slider thumb to
                  // `min` (not 0) — Slider's invariant is value in
                  // [min, max], so 0 with min=10/15/320 would assert.
                  // The visual "unlimited" cue comes from the label text
                  // and the disabled look, not from the thumb position.
                  value: isUnset ? min : value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: displayValue,
                  onChanged: isUnset ? null : onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          DropdownButton<T>(
            value: value,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: options
                .map((o) => DropdownMenuItem<T>(
                      value: o,
                      child: Text(o.toString(),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _TextFieldRow extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _TextFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  State<_TextFieldRow> createState() => _TextFieldRowState();
}

class _TextFieldRowState extends State<_TextFieldRow> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _TextFieldRow old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
    }
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: widget.onChanged,
      ),
    );
  }
}
