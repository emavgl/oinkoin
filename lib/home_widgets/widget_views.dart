import 'package:flutter/material.dart';

/// Minimal stock-chart line with a soft fill underneath, rendered to a
/// transparent bitmap for the home screen widgets.
class HomeWidgetSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const HomeWidgetSparkline({
    super.key,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1.0 : (max - min).toDouble();
    const pad = 3.0;
    final points = List<Offset>.generate(values.length, (i) {
      final x = values.length == 1
          ? size.width / 2
          : pad + (size.width - pad * 2) * i / (values.length - 1);
      final y = size.height -
          pad -
          (size.height - pad * 2) * (values[i] - min) / span;
      return Offset(x, y);
    });
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
