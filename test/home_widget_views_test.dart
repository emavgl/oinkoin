import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/home_widgets/widget_views.dart';

/// Home screen widget views render with preformatted values (no database).
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, height: 200, child: child)),
      ),
    );
    await tester.pump();
  }

  testWidgets('overview shows all three totals', (tester) async {
    await pump(
      tester,
      const HomeWidgetOverview(
        incomeText: '1,700.00',
        incomeColor: Colors.green,
        expensesText: '390.50',
        expenseColor: Colors.red,
        balanceText: '1,309.50',
        balanceColor: Colors.green,
      ),
    );

    expect(find.text('1,700.00'), findsOneWidget);
    expect(find.text('390.50'), findsOneWidget);
    expect(find.text('1,309.50'), findsOneWidget);
  });

  testWidgets('budget shows name, progress and bar', (tester) async {
    await pump(
      tester,
      const HomeWidgetBudget(
        name: 'Monthly food',
        progressText: '225.00 / 450.00',
        ratio: 0.5,
        color: Colors.red,
      ),
    );

    expect(find.text('Monthly food'), findsOneWidget);
    expect(find.text('225.00 / 450.00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
