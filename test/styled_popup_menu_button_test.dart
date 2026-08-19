import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/records/components/styled_popup_menu_button.dart';
import 'package:piggybank/services/service-config.dart';

Widget _buildTestApp() {
  return MaterialApp(
    home: Scaffold(
      body: StyledPopupMenuButton(onSelected: (_) {}),
    ),
  );
}

void main() {
  testWidgets('Export PDF shows a PRO label for non-premium users',
      (tester) async {
    ServiceConfig.isPremium = false;
    addTearDown(() => ServiceConfig.isPremium = false);

    await tester.pumpWidget(_buildTestApp());
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
  });

  testWidgets('Export PDF has no PRO label for premium users',
      (tester) async {
    ServiceConfig.isPremium = true;
    addTearDown(() => ServiceConfig.isPremium = false);

    await tester.pumpWidget(_buildTestApp());
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('PRO'), findsNothing);
  });
}