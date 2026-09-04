import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/home_widgets/widget_views.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/home-widget-service.dart';

/// Home screen widget helpers: sparkline painting and daily series math.
/// Data pushing itself is covered on-device (needs the widget plugin).
void main() {
  testWidgets('sparkline paints without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 60,
            child: HomeWidgetSparkline(
              values: [10.0, 30.0, 20.0, 50.0],
              color: Colors.green,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('dailySeries groups signed daily totals', () {
    final food = Category('Food', categoryType: CategoryType.expense);
    final salary = Category('Salary', categoryType: CategoryType.income);

    final series = HomeWidgetService.dailySeries(
      <Record?>[
        Record(-100.0, 'a', food, DateTime.utc(2026, 7, 1)),
        Record(-50.0, 'b', food, DateTime.utc(2026, 7, 1)),
        Record(1000.0, 'c', salary, DateTime.utc(2026, 7, 2)),
      ],
      isBalance: true,
    );

    expect(series, [-150.0, 1000.0]);
  });

  test('dailySeries uses absolute values unless balance', () {
    final food = Category('Food', categoryType: CategoryType.expense);

    final series = HomeWidgetService.dailySeries(
      <Record?>[
        Record(-100.0, 'a', food, DateTime.utc(2026, 7, 1)),
      ],
      isBalance: false,
    );

    expect(series, [100.0]);
  });
}
