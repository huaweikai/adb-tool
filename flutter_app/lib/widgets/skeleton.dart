import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// A single shimmering placeholder block, tinted from the active
/// theme so it reads correctly in both light and dark modes.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final lifted = theme.colorScheme.surfaceContainerHighest.withAlpha(120);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: Color.lerp(base, lifted, _controller.value),
        ),
      ),
    );
  }
}

/// A vertical list of skeleton rows for full-page loading states.
/// Drop-in replacement for a centered [CircularProgressIndicator]
/// when the loaded content is a list of items.
class SkeletonList extends StatelessWidget {
  final int count;
  final double spacing;

  const SkeletonList({
    super.key,
    this.count = 6,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, __) => const Row(
        children: [
          Skeleton(width: 40, height: 40, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 12, width: 160),
                SizedBox(height: 8),
                Skeleton(height: 10, width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
