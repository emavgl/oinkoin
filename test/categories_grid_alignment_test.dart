import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:piggybank/categories/categories-grid.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';

Widget _buildTestApp(Widget child) {
  return I18n(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('bottom-aligned grid renders categories without errors',
      (WidgetTester tester) async {
    final categories = <Category?>[
      Category('Food',
          color: Colors.green, categoryType: CategoryType.expense),
      Category('Rent',
          color: Colors.blue, categoryType: CategoryType.expense),
    ];

    await tester.pumpWidget(_buildTestApp(
      CategoriesGrid(
        categories,
        enableManualSorting: false,
        onChangeOrder: (_) {},
        alignToBottom: true,
      ),
    ));
    await tester.pump();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('default grid (top-aligned) still renders categories',
      (WidgetTester tester) async {
    final categories = <Category?>[
      Category('Salary',
          color: Colors.orange, categoryType: CategoryType.income),
    ];

    await tester.pumpWidget(_buildTestApp(
      CategoriesGrid(
        categories,
        enableManualSorting: false,
        onChangeOrder: (_) {},
      ),
    ));
    await tester.pump();

    expect(find.text('Salary'), findsOneWidget);
  });
}
