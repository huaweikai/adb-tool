import 'package:flutter/material.dart';

/// Ultra-lightweight sparkline mini-chart.
/// Pure CustomPaint — no third-party chart library needed.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    this.color,
    this.height = 32,
    this.showArea = true,
    this.lineWidth = 1.5,
  });

  final List<double> data;
  final Color? color;
  final double height;
  final bool showArea;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);
    final lineColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: lineColor,
          showArea: showArea,
          lineWidth: lineWidth,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.color,
    required this.showArea,
    required this.lineWidth,
  });

  final List<double> data;
  final Color color;
  final bool showArea;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    if (range == 0) return;

    final stepX = size.width / (data.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range) * (size.height - 4) - 2;
      points.add(Offset(x, y));
    }

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw area fill
    if (showArea) {
      final areaPath = Path.from(path);
      areaPath.lineTo(points.last.dx, size.height);
      areaPath.lineTo(points.first.dx, size.height);
      areaPath.close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(60), color.withAlpha(10)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(areaPath, areaPaint);
    }

    // Draw start/end dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.first, 2, dotPaint);
    canvas.drawCircle(points.last, 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => data != old.data;
}
