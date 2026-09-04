import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';

/// Home screen widgets styled after stock-tracking widgets: dark cards,
/// oversized figures, and sparklines.
///
/// They mirror the app's summary styling but take preformatted values, so
/// rendering needs no database access.

/// Small caps section label.
class _WidgetLabel extends StatelessWidget {
  final String text;

  const _WidgetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Rounded dark card shared by every widget.
class _WidgetCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WidgetCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Income / Expenses / Balance overview card, mirroring DaysSummaryBox.
class HomeWidgetOverview extends StatelessWidget {
  final String incomeText;
  final String expensesText;
  final String balanceText;
  final Color incomeColor;
  final Color expenseColor;
  final Color balanceColor;
  final List<double> sparkline;

  const HomeWidgetOverview({
    super.key,
    required this.incomeText,
    required this.incomeColor,
    required this.expensesText,
    required this.expenseColor,
    required this.balanceText,
    required this.balanceColor,
    this.sparkline = const [],
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Expanded(
                child: _HomeWidgetStatColumn(
                  label: "Income".i18n,
                  amount: incomeText,
                  color: incomeColor,
                ),
              ),
              Expanded(
                child: _HomeWidgetStatColumn(
                  label: "Expenses".i18n,
                  amount: expensesText,
                  color: expenseColor,
                ),
              ),
              Expanded(
                child: _HomeWidgetStatColumn(
                  label: "Balance".i18n,
                  amount: balanceText,
                  color: balanceColor,
                ),
              ),
            ],
          ),
          if (sparkline.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: _Sparkline(
                values: sparkline,
                color: balanceColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeWidgetStatColumn extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _HomeWidgetStatColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WidgetLabel(label),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Single labeled amount (Income, Expenses, or Balance widget) with a
/// stock-style big figure and sparkline.
class HomeWidgetAmount extends StatelessWidget {
  final String label;
  final String amount;
  final Color? color;
  final List<double> sparkline;

  const HomeWidgetAmount({
    super.key,
    required this.label,
    required this.amount,
    this.color,
    this.sparkline = const [],
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final valueColor =
        color ?? (brightness == Brightness.dark ? Colors.white : Colors.black);
    return _WidgetCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _WidgetLabel(label),
          const SizedBox(height: 2),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          if (sparkline.length > 1) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              width: double.infinity,
              child: _Sparkline(values: sparkline, color: valueColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// One budget: name, big spent figure, target line, and progress bar.
class HomeWidgetBudget extends StatelessWidget {
  final String name;
  final String progressText;
  final double ratio;
  final Color color;

  const HomeWidgetBudget({
    super.key,
    required this.name,
    required this.progressText,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _WidgetCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            progressText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: dark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal stock-chart line with a soft fill underneath.
class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _Sparkline({required this.values, required this.color});

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
