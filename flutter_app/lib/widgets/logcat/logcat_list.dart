import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../i18n.dart';
import '../../models/device.dart';
import '../../providers/locale_provider.dart';
import '../../providers/logcat_state_provider.dart';
import 'highlight_rule.dart';

/// A chronological fixed-row document in compact mode. Soft wraps use a
/// centered pair of slivers so appends can leave a variable-height anchor in place.
class LogcatList extends StatefulWidget {
  const LogcatList({
    super.key,
    required this.deviceSerial,
    required this.active,
    required this.highlightRules,
    required this.highlightVersion,
  });

  final String deviceSerial;
  final bool active;
  final List<HighlightRule> highlightRules;
  final int highlightVersion;

  @override
  State<LogcatList> createState() => _LogcatListState();
}

class _LogcatListState extends State<LogcatList> {
  final _historyKey = GlobalKey();
  final _newerKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _horizontal = ScrollController();
  final _rowBoxes = <_LogRowBox>{};
  int? _newerFirstId;
  int? _seenFilterRevision;
  bool? _seenWrap;
  int _seenRemoved = 0;
  double? _seenRowHeight;
  bool _resetLiveViewport = true;
  late final _deviceState =
      context.read<LogcatStateProvider>().stateFor(widget.deviceSerial);
  late final _controller = _LogScrollController(
    _historyKey,
    onIdle: _scheduleFollow,
    restoreAtTail: () => _deviceState.followLatest.value,
  );
  Expando<_LogRow> _rows = Expando<_LogRow>();
  LogcatLines? _inactiveLines;
  int _latestId = -1;
  int _newerCount = 0;
  int? _liveAfterId;
  bool _followScheduled = false;
  bool _movingTowardTail = false;

  @override
  void initState() {
    super.initState();
    _deviceState.followLatest.addListener(_onFollowChanged);
  }

  @override
  void didUpdateWidget(LogcatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightVersion != oldWidget.highlightVersion ||
        widget.highlightRules != oldWidget.highlightRules) {
      _rows = Expando<_LogRow>();
    }
    if (widget.active != oldWidget.active) {
      _stopFollowAnimation();
      // Reopen a live tab at its current tail. A tab in review keeps its
      // original scroll coordinates while background collection continues.
      _liveAfterId = null;
      _resetLiveViewport = true;
    }
  }

  @override
  void dispose() {
    _deviceState.followLatest.removeListener(_onFollowChanged);
    _controller.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _onFollowChanged() {
    _movingTowardTail = false;
    _stopFollowAnimation();
    setState(() {
      if (_deviceState.followLatest.value) {
        _deviceState.reviewAfterId = null;
        if (_seenWrap ?? _deviceState.softWrap.value) {
          _rebaseLiveOrigin(_latestId);
        } else if (_controller.hasClients) {
          _controller.position.rebaseOnLayout(toTail: true);
        }
      } else {
        _deviceState.reviewAfterId = _liveAfterId ?? _latestId;
        if (_controller.hasClients) _controller.position.rememberOffset();
      }
    });
  }

  void _stopFollowAnimation() {
    if (_controller.hasClients) _controller.position.stopFollowingTail();
  }

  void _rebaseLiveOrigin(int id, {double? offsetShift}) {
    _liveAfterId = id;
    if (_controller.hasClients) {
      _controller.position.rebaseOnLayout(offsetShift: offsetShift);
    }
  }

  void _scheduleFollow() {
    if (!mounted ||
        !widget.active ||
        !_deviceState.followLatest.value ||
        _followScheduled) {
      return;
    }
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted ||
          !widget.active ||
          !_deviceState.followLatest.value ||
          !_controller.hasClients) {
        return;
      }
      final position = _controller.position;
      if (!position.hasContentDimensions ||
          (!position.isIdle && !position.isFollowingTail)) {
        return;
      }
      final distance = position.distanceToTail;
      if (distance > 0 && MediaQuery.disableAnimationsOf(context)) {
        _stopFollowAnimation();
        setState(() {
          if (position.tailAtMax) {
            position.rebaseOnLayout(toTail: true);
          } else {
            _rebaseLiveOrigin(_latestId);
          }
        });
        return;
      }
      if (_newerCount >= 64 &&
          distance <= position.viewportDimension / 2 &&
          _laidOutLatestLine) {
        // Swap to a short origin without changing any row's screen position.
        // Use the measured tail so this also works during sustained output,
        // when the animation may never settle between batches.
        setState(() {
          _rebaseLiveOrigin(_latestId, offsetShift: -position.minScrollExtent);
        });
      }
      if (distance > 0 && position.isIdle) {
        position.followTail();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _scheduleFollow();
    return false;
  }

  void _pauseFollow() => _deviceState.followLatest.value = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        !widget.active ||
        _controller.position.isFollowingTail) {
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta == 0) return false;
      final towardTail =
          notification.metrics.axisDirection == AxisDirection.down
              ? delta > 0
              : delta < 0;
      if (!towardTail && _deviceState.followLatest.value) _pauseFollow();
      _movingTowardTail = towardTail;
    } else if (notification is ScrollEndNotification && _movingTowardTail) {
      _movingTowardTail = false;
      // Variable-height slivers may estimate their extent while scrolling.
      // Check after the final layout, once the actual tail is in view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.active ||
            _deviceState.followLatest.value ||
            !_controller.hasClients) {
          return;
        }
        final position = _controller.position;
        if (!position.isScrollingNotifier.value &&
            position.distanceToTail <= 0 &&
            _laidOutLatestLine) {
          _deviceState.followLatest.value = true;
        }
      });
    }
    return false;
  }

  bool get _laidOutLatestLine {
    if (_newerCount == 0) return true;
    final sliver = _newerKey.currentContext?.findRenderObject()
        as RenderSliverMultiBoxAdaptor?;
    final lastChild = sliver?.lastChild;
    return lastChild != null && sliver!.indexOf(lastChild) == _newerCount - 1;
  }

  int _historyEnd(LogcatLines lines, int latestId, bool layoutChanged) {
    if (!_deviceState.followLatest.value) {
      final boundary = lines.indexAfter(_deviceState.reviewAfterId ?? latestId);
      final firstNewer = boundary < lines.length ? lines[boundary].id : null;
      if (layoutChanged ||
          (_newerFirstId != null && firstNewer != _newerFirstId)) {
        final anchor = _visibleAnchor(lines);
        if (anchor != null) {
          _deviceState.reviewAfterId = anchor.id;
          _controller.position.rebaseOnLayout(
              absoluteOffset: anchor.bottom - anchor.viewportHeight);
          return lines.indexAfter(anchor.id);
        }
      }
      return boundary;
    }
    final origin = _liveAfterId;
    if (origin == null || _latestId < 0 || latestId < _latestId) {
      _rebaseLiveOrigin(latestId);
      return lines.length;
    }
    final historyEnd = lines.indexAfter(origin);
    if (lines.length - historyEnd > 240) {
      // A suspended consumer can deliver thousands of lines at once.
      // Scroll the final part of such a burst instead of animating through
      // the entire buffer. The full retained history remains scrollable.
      final cutoff = lines.length - 12;
      _rebaseLiveOrigin(lines[cutoff - 1].id);
      return cutoff;
    }
    return historyEnd;
  }

  /// The reverse viewport's center is just below the history sliver.
  /// Recenter it on the first surviving painted row at the same screen Y.
  ({int id, double top, double bottom, double viewportHeight})? _visibleAnchor(
      LogcatLines lines) {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (!_controller.hasClients ||
        viewport is! RenderBox ||
        !viewport.hasSize) {
      return null;
    }
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final height = viewport.size.height;
    var topmost = height;
    ({int id, double top, double bottom, double viewportHeight})? anchor;
    for (final row in _rowBoxes) {
      if (!row.hasSize) continue;
      final top = row.localToGlobal(Offset.zero).dy - viewportTop;
      final bottom = top + row.size.height;
      if (top < topmost && bottom > 0 && lines.containsId(row.id)) {
        topmost = top;
        anchor = (id: row.id, top: top, bottom: bottom, viewportHeight: height);
      }
    }
    return anchor;
  }

  void _updateFixedViewport(LogcatLines lines, double rowHeight,
      {required bool layoutChanged}) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    position.updateFixedDocument(lines.length, rowHeight);
    if (_deviceState.followLatest.value &&
        (_resetLiveViewport ||
            layoutChanged ||
            _latestId < 0 ||
            position.willJumpToTail)) {
      position.rebaseOnLayout(toTail: true);
      return;
    }
    if (layoutChanged ||
        (_seenRowHeight != null && rowHeight != _seenRowHeight)) {
      final anchor = _visibleAnchor(lines);
      if (anchor != null) {
        final index = lines.indexAfter(anchor.id) - 1;
        position.rebaseOnLayout(absoluteOffset: index * rowHeight - anchor.top);
      }
    } else if (lines.removed != _seenRemoved) {
      // Indices move after FIFO eviction, but a retained row's screen Y
      // stays the same when its known prefix height is subtracted.
      position.rebaseOnLayout(
          offsetShift: (_seenRemoved - lines.removed) * rowHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _deviceState.softWrap,
      builder: (context, wrap, _) => Selector<LogcatStateProvider, int>(
        selector: (_, provider) => widget.active
            ? provider.stateFor(widget.deviceSerial).displayedVersion
            : -1,
        builder: (context, _, child) {
          final live = _deviceState.displayed;
          if (widget.active) _inactiveLines = null;
          final lines =
              widget.active ? live : (_inactiveLines ??= live.snapshot());
          final count = lines.length;
          final latestId = count == 0 ? -1 : lines[count - 1].id;
          final wrapChanged = _seenWrap != null && _seenWrap != wrap;
          if (wrapChanged) _rows = Expando<_LogRow>();
          final filterRevision = _deviceState.filterRevision;
          final layoutChanged = wrapChanged ||
              (_seenFilterRevision != null &&
                  _seenFilterRevision != filterRevision);
          final fontSize = MediaQuery.textScalerOf(context).scale(12);
          final rowHeight = math.max(18.0, fontSize * 1.5);
          if (wrapChanged && _deviceState.followLatest.value) {
            _liveAfterId = null;
          }
          if (!wrap) {
            _updateFixedViewport(lines, rowHeight,
                layoutChanged: layoutChanged);
          }
          final boundary =
              wrap ? _historyEnd(lines, latestId, layoutChanged) : 0;
          _resetLiveViewport = false;
          _seenRemoved = lines.removed;
          _seenRowHeight = rowHeight;
          _seenWrap = wrap;
          _seenFilterRevision = filterRevision;
          _latestId = latestId;
          _newerCount = wrap ? count - boundary : 0;
          _newerFirstId = _newerCount == 0 ? null : lines[boundary].id;
          if (count > 0) _scheduleFollow();
          return Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final width = wrap
                    ? constraints.maxWidth
                    : math.max(constraints.maxWidth,
                        530 + lines.widestColumns * fontSize * 0.7);
                return Scrollbar(
                  controller: _controller,
                  notificationPredicate: (notice) =>
                      notice.metrics.axis == Axis.vertical,
                  child: Scrollbar(
                    controller: _horizontal,
                    notificationPredicate: (notice) =>
                        notice.metrics.axis == Axis.horizontal,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        controller: _horizontal,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          height: constraints.maxHeight,
                          child:
                              NotificationListener<ScrollMetricsNotification>(
                            onNotification: _onMetrics,
                            child: NotificationListener<ScrollNotification>(
                              key: _viewportKey,
                              onNotification: _onScroll,
                              child: CustomScrollView(
                                key: PageStorageKey(
                                    'logcat:${widget.deviceSerial}'),
                                controller: _controller,
                                reverse: wrap,
                                center: wrap ? _historyKey : null,
                                physics: const ClampingScrollPhysics(),
                                slivers: [
                                  if (wrap) ...[
                                    _buildSliver(lines,
                                        key: _newerKey,
                                        start: boundary,
                                        end: count,
                                        wrap: true,
                                        rowHeight: rowHeight),
                                    _buildSliver(lines,
                                        key: _historyKey,
                                        start: 0,
                                        end: boundary,
                                        newestFirst: true,
                                        wrap: true,
                                        rowHeight: rowHeight),
                                  ] else
                                    _buildSliver(lines,
                                        key: _historyKey,
                                        start: 0,
                                        end: count,
                                        wrap: false,
                                        rowHeight: rowHeight),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (count == 0) const _EmptyLogList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliver(
    LogcatLines lines, {
    required Key key,
    required int start,
    required int end,
    required bool wrap,
    required double rowHeight,
    bool newestFirst = false,
  }) {
    final delegate = SliverChildBuilderDelegate(
      (context, index) {
        final line = lines[newestFirst ? end - 1 - index : start + index];
        return _rows[line] ??= _LogRow(
          key: ValueKey(line.id),
          line: line,
          rowBoxes: _rowBoxes,
          softWrap: wrap,
          highlightRules: widget.highlightRules,
          onInspect: _pauseFollow,
        );
      },
      childCount: end - start,
      addAutomaticKeepAlives: false,
      findChildIndexCallback: (key) {
        final id = (key as ValueKey<int>).value;
        final index = lines.indexAfter(id) - 1;
        if (index < start || index >= end || lines[index].id != id) return null;
        return newestFirst ? end - 1 - index : index - start;
      },
    );
    return wrap
        ? SliverList(key: key, delegate: delegate)
        : SliverFixedExtentList(
            key: key, itemExtent: rowHeight, delegate: delegate);
  }
}

class _LogRowMarker extends SingleChildRenderObjectWidget {
  const _LogRowMarker(this.id, this.rows, {required super.child});

  final int id;
  final Set<_LogRowBox> rows;

  @override
  _LogRowBox createRenderObject(BuildContext context) => _LogRowBox(id, rows);
}

class _LogRowBox extends RenderProxyBox {
  _LogRowBox(this.id, this.rows);

  final int id;
  final Set<_LogRowBox> rows;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    rows.add(this);
  }

  @override
  void detach() {
    rows.remove(this);
    super.detach();
  }
}

class _LogScrollController extends ScrollController {
  _LogScrollController(
    this.historyKey, {
    required this.onIdle,
    required this.restoreAtTail,
  });

  final GlobalKey historyKey;
  final VoidCallback onIdle;
  final bool Function() restoreAtTail;

  @override
  _LogScrollPosition get position => super.position as _LogScrollPosition;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _LogScrollPosition(
      historyKey: historyKey,
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      onIdle: onIdle,
      rebase: oldPosition == null && restoreAtTail(),
    );
  }
}

class _LogScrollPosition extends ScrollPositionWithSingleContext {
  _LogScrollPosition({
    required this.historyKey,
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.onIdle,
    required bool rebase,
  })  : _rebase = rebase,
        _toTail = rebase;

  final GlobalKey historyKey;
  final VoidCallback onIdle;
  bool _rebase;
  double? _offsetShift;
  double? _absoluteOffset;
  bool _toTail;
  int _fixedCount = 0;
  double? _fixedExtent;

  bool get willJumpToTail => _rebase && _toTail;
  bool get tailAtMax => axisDirection == AxisDirection.down;
  double get tail => tailAtMax ? maxScrollExtent : minScrollExtent;
  double get distanceToTail => tailAtMax ? tail - pixels : pixels - tail;

  bool get isIdle => activity is IdleScrollActivity;
  bool get isFollowingTail => activity is _FollowTailActivity;

  void rebaseOnLayout({
    double? offsetShift,
    double? absoluteOffset,
    bool toTail = false,
  }) {
    _rebase = true;
    _offsetShift = offsetShift;
    _absoluteOffset = absoluteOffset;
    _toTail = toTail;
  }

  void rememberOffset() => saveScrollOffset();

  void followTail() => beginActivity(_FollowTailActivity(this));

  void stopFollowingTail() {
    if (isFollowingTail) goIdle();
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    super.beginActivity(newActivity);
    if (newActivity is IdleScrollActivity) onIdle();
  }

  void updateFixedDocument(int count, double extent) {
    _fixedCount = count;
    _fixedExtent = extent;
  }

  @override
  bool applyViewportDimension(double viewportDimension) {
    final result = super.applyViewportDimension(viewportDimension);
    final extent = _fixedExtent;
    if (_rebase && tailAtMax && extent != null) {
      // Known dimensions let the viewport correct its origin before the
      // sliver constructs any children for the old scroll position.
      _applyRebase(0, math.max(0, _fixedCount * extent - viewportDimension));
    }
    return result;
  }

  bool _applyRebase(double minScrollExtent, double maxScrollExtent) {
    if (!_rebase) return false;
    _rebase = false;
    final target = _toTail
        ? (tailAtMax ? maxScrollExtent : minScrollExtent)
        : _absoluteOffset ?? 0;
    final shift = _offsetShift ?? target - pixels;
    final corrected = tailAtMax
        ? (pixels + shift).clamp(minScrollExtent, maxScrollExtent)
        : pixels + shift;
    _offsetShift = null;
    _absoluteOffset = null;
    _toTail = false;
    if (corrected == pixels) return false;
    correctBy(corrected - pixels);
    return true;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_applyRebase(minScrollExtent, maxScrollExtent)) return false;
    if (!tailAtMax && maxScrollExtent == 0) {
      final history =
          historyKey.currentContext?.findRenderObject() as RenderSliver?;
      final extent = history?.geometry?.scrollExtent;
      if (extent != null) {
        maxScrollExtent = extent - viewportDimension;
        // Underfilled logs grow from the top like an editor. This also
        // prevents a blank viewport if all rows before the origin expire.
        minScrollExtent = math.min(minScrollExtent, maxScrollExtent);
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}

/// Follows the changing laid-out tail with one damped motion. A new batch
/// updates the target without restarting the animation or losing velocity.
/// Flutter replaces this activity when a wheel, drag or scrollbar takes over.
class _FollowTailActivity extends ScrollActivity {
  _FollowTailActivity(_LogScrollPosition position) : super(position) {
    _ticker = position.context.vsync.createTicker(_tick)..start();
  }

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _velocity = 0;

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => true;

  @override
  double get velocity =>
      (delegate as _LogScrollPosition).tailAtMax ? -_velocity : _velocity;

  void _tick(Duration elapsed) {
    final position = delegate as _LogScrollPosition;
    final target = position.tail;
    final distance = position.distanceToTail;
    final seconds =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (distance <= 0.25) {
      position.setPixels(target);
      position.goIdle();
      return;
    }

    const frequency = 35.0;
    final coefficient = _velocity + frequency * distance;
    final damping = math.exp(-frequency * seconds);
    final remaining = (distance + coefficient * seconds) * damping;
    // Bound a single frame's layout work even with exceptionally long rows.
    final step = (distance - remaining).clamp(
      0.0,
      math.min(
          distance, position.viewportDimension / (position.tailAtMax ? 1 : 3)),
    );
    if (seconds > 0) {
      _velocity = step < distance - remaining
          ? -step / seconds
          : (_velocity - frequency * coefficient * seconds) * damping;
    }
    position.setPixels(position.pixels + (position.tailAtMax ? step : -step));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _EmptyLogList extends StatelessWidget {
  const _EmptyLogList();

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider?>();
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 48, color: color.withAlpha(80)),
          const SizedBox(height: 12),
          Text(tr('logcatSelectDevice'),
              style: theme.textTheme.bodyMedium?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(tr('logsHint'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: color.withAlpha(150))),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required super.key,
    required this.line,
    required this.rowBoxes,
    required this.softWrap,
    required this.highlightRules,
    required this.onInspect,
  });

  final LogcatLine line;
  final Set<_LogRowBox> rowBoxes;
  final bool softWrap;
  final List<HighlightRule> highlightRules;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const mono = TextStyle(fontFamily: 'Menlo', height: 1.5);
    final entry = line.entry;
    final highlightRule = HighlightRules.match(highlightRules, entry, tr);
    final highlightColor = highlightRule?.color;
    final rowBackground = highlightColor?.withAlpha(26);
    final messageColor = highlightColor ?? theme.colorScheme.onSurface;

    return _LogRowMarker(
      line.id,
      rowBoxes,
      child: InkWell(
        onTap: () {
          onInspect();
          Clipboard.setData(ClipboardData(text: entry.raw));
        },
        child: Container(
          color: rowBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildLogEntryContent(
            entry,
            theme,
            mono,
            messageColor,
            highlightColor,
          ),
        ),
      ),
    );
  }

  Text _message(String text, TextStyle style) => Text(
        text.replaceAll('\n', '↵ '),
        style: style,
        maxLines: softWrap ? null : 1,
        softWrap: softWrap,
      );

  Widget _buildLogEntryContent(
    LogEntry entry,
    ThemeData theme,
    TextStyle mono,
    Color messageColor,
    Color? highlightColor,
  ) {
    if (!softWrap && entry.time.isNotEmpty) {
      return _buildCompactLine(entry, theme, mono, messageColor);
    }
    if (entry.isContinuation) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('│ ',
              style: mono.copyWith(fontSize: 12, color: theme.dividerColor)),
          Expanded(
            child: _message(
              entry.message,
              mono.copyWith(
                fontSize: 12,
                color: highlightColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    if (entry.time.isEmpty) {
      return _message(
          entry.raw, mono.copyWith(fontSize: 12, color: messageColor));
    }

    final prioColor = _prioColor(entry.priority, theme);
    final displayTime = _formatLogTimeWithYear(entry.time);
    final pidTid = '${entry.pid}-${entry.tid}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 175,
          child: Text(
            displayTime,
            style: mono.copyWith(
                fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            softWrap: false,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 160,
          child: Text(
            entry.tag.replaceAll('\n', '↵ '),
            style:
                mono.copyWith(fontSize: 11, color: theme.colorScheme.primary),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            pidTid,
            style: mono.copyWith(fontSize: 11, color: Colors.green.shade300),
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: prioColor.withAlpha(30),
              borderRadius: BorderRadius.circular(3)),
          child: Text(entry.priority,
              style: mono.copyWith(
                  fontSize: 11, fontWeight: FontWeight.w700, color: prioColor)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _message(
            entry.message,
            mono.copyWith(fontSize: 11, color: messageColor),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLine(
      LogEntry entry, ThemeData theme, TextStyle mono, Color messageColor) {
    final colors = theme.colorScheme;
    final time = _formatLogTimeWithYear(entry.time);
    final process = '${entry.pid}-${entry.tid}';
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '${time.padRight(26)}  ',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        TextSpan(
          text: '${_compactTag(entry.tag)}  ',
          style: TextStyle(color: colors.primary),
        ),
        TextSpan(
          text: '${process.padRight(13)}  ',
          style: TextStyle(color: Colors.green.shade300),
        ),
        TextSpan(
          text: '${entry.priority}  ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _prioColor(entry.priority, theme),
          ),
        ),
        TextSpan(text: entry.message.replaceAll('\n', '↵ ')),
      ]),
      style: mono.copyWith(fontSize: 11, color: messageColor),
      maxLines: 1,
      softWrap: false,
    );
  }

  String _compactTag(String tag) {
    const columns = 24;
    if (tag.length <= columns) return tag.padRight(columns);
    return '${String.fromCharCodes(tag.runes.take(columns - 1))}…';
  }

  static final _timePattern =
      RegExp(r'^(\d{2})-(\d{2})\s+\d{2}:\d{2}:\d{2}\.\d+$');

  String _formatLogTimeWithYear(String raw) {
    final m = _timePattern.firstMatch(raw.trim());
    if (m == null) return raw;
    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    final now = DateTime.now();
    var year = now.year;
    final parsedThisYear = DateTime(year, month, day);
    if (parsedThisYear.difference(now).inDays > 30) {
      year -= 1;
    }
    return '$year-$raw';
  }

  Color _prioColor(String prio, ThemeData theme) {
    switch (prio) {
      case 'V':
        return theme.colorScheme.onSurfaceVariant;
      case 'D':
        return Colors.blue;
      case 'I':
        return Colors.green;
      case 'W':
        return Colors.orange;
      case 'E':
        return Colors.red;
      case 'F':
        return Colors.purple;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
