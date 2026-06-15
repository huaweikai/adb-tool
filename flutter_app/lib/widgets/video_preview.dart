import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_selector/file_selector.dart';
import '../i18n.dart';

class VideoPreview extends StatefulWidget {
  final List<int> videoBytes;

  const VideoPreview({super.key, required this.videoBytes});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _playing = false;
  bool _saving = false;
  String? _error;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final dir = Directory.systemTemp;
      _tempFile = File(
          '${dir.path}/adb-tool-preview-${DateTime.now().millisecondsSinceEpoch}.mp4');
      await _tempFile!.writeAsBytes(widget.videoBytes);

      _controller = VideoPlayerController.file(_tempFile!);
      await _controller!.initialize();
      _controller!.addListener(_onControllerUpdate);
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final isPlaying = _controller?.value.isPlaying ?? false;
    if (_playing != isPlaying) {
      setState(() => _playing = isPlaying);
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekRelative(double seconds) {
    if (_controller == null) return;
    final dur = _controller!.value.duration;
    var newMs = _controller!.value.position.inMilliseconds +
        (seconds * 1000).round();
    if (newMs < 0) newMs = 0;
    if (newMs > dur.inMilliseconds) newMs = dur.inMilliseconds;
    _controller!.seekTo(Duration(milliseconds: newMs));
  }

  Future<void> _save() async {
    if (_tempFile == null) return;
    setState(() => _saving = true);
    try {
      final location = await getSaveLocation(
        suggestedName:
            'screen-record-${DateTime.now().millisecondsSinceEpoch}.mp4',
        confirmButtonText: tr('saveRecording'),
      );
      if (location == null) {
        setState(() => _saving = false);
        return;
      }
      await _tempFile!.copy(location.path);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('recordingSaved', {'path': location.path})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('recordingStopFailed')}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _tempFile?.delete();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: tr('close'),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
          title: Text(tr('record'), style: const TextStyle(fontSize: 16)),
          actions: [
            _buildSaveButton(),
          ],
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller!),
                    if (!_playing)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withAlpha(120),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Icon(Icons.play_arrow,
                              size: 48, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildControls(theme),
      ],
    );
  }

  Widget _buildControls(ThemeData theme) {
    if (_controller == null) return const SizedBox.shrink();
    final duration = _controller!.value.duration;
    final position = _controller!.value.position;
    final progress =
        duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;

    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final target =
                    Duration(milliseconds: (duration.inMilliseconds * v).round());
                _controller!.seekTo(target);
              },
            ),
          ),
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'Menlo'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white70),
                iconSize: 22,
                onPressed: () => _seekRelative(-5),
              ),
              IconButton(
                icon: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                iconSize: 32,
                onPressed: _togglePlay,
              ),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white70),
                iconSize: 22,
                onPressed: () => _seekRelative(5),
              ),
              const Spacer(),
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'Menlo'),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: _save,
      icon: const Icon(Icons.save, size: 16),
      label: Text(tr('save')),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
