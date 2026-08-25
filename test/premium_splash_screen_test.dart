import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/services/purchase-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'purchase_service_test.dart' show FakePurchaseGateway, product, purchase;

void main() {
  late FakePurchaseGateway gateway;
  late PurchaseService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.setPremium(false);

    gateway = FakePurchaseGateway();
    service = PurchaseService(gateway: gateway);
  });

  tearDown(() {
    service.dispose();
  });

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PremiumSplashScreen(purchaseService: service),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void configureProducts() {
    gateway.productDetailsResult = [
      product(ProProductIds.oneTime, price: 4.99),
    ];
  }

  testWidgets('shows a loading indicator while products are fetched', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PremiumSplashScreen(purchaseService: service)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('ready state shows Lifetime Pro with the store price', (
    tester,
  ) async {
    configureProducts();
    await pumpSplash(tester);

    // Headline + hero structure.
    expect(find.text('Upgrade to Oinkoin Pro'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget); // hero artwork
    // The single purchase is represented by the CTA; there is no separate
    // offer card.
    expect(find.text('Lifetime Pro'), findsNothing);
    expect(find.text('One-time purchase'), findsNothing);
    // Restore sits below the CTA.
    expect(find.text('Get Lifetime Pro for \$4.99'), findsOneWidget);
    expect(find.text('And many more...'), findsOneWidget);
    expect(
      find.text('Filter records by year or custom date range'),
      findsNothing,
    );
    expect(find.text('Create wallets'), findsOneWidget);
    expect(find.text('Manage budgets'), findsOneWidget);
    expect(find.text('Full category icon pack and color picker'), findsNothing);
    expect(find.text('Support more profiles'), findsNothing);
    expect(
      find.widgetWithText(TextButton, 'Restore purchases'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the CTA launches billing for the selected offer', (
    tester,
  ) async {
    configureProducts();
    await pumpSplash(tester);

    // One-time selected by default.
    await tester.tap(find.text('Get Lifetime Pro for \$4.99'));
    await tester.pumpAndSettle();
    expect(gateway.lastBuyParam?.productDetails.id, ProProductIds.oneTime);
  });

  testWidgets('failed billing flow shows an error snackbar', (tester) async {
    configureProducts();
    gateway.buyResult = false;
    await pumpSplash(tester);

    await tester.tap(find.text('Get Lifetime Pro for \$4.99'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to start the purchase. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('restore reports when there are no purchases', (tester) async {
    configureProducts();
    await pumpSplash(tester);

    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();

    expect(find.text('No purchases to restore'), findsOneWidget);
  });

  testWidgets('restore reports restored purchases', (tester) async {
    configureProducts();
    gateway.queryResult = [
      purchase(ProProductIds.oneTime, status: PurchaseStatus.restored),
    ];
    await pumpSplash(tester);

    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();

    expect(find.text('Purchases restored'), findsOneWidget);
  });

  testWidgets('demo mode is shown when no products are configured', (
    tester,
  ) async {
    gateway.productDetailsResult = [];
    await pumpSplash(tester);

    expect(
      find.text('Demo mode: purchases are not available in this build.'),
      findsOneWidget,
    );

    // Demo CTA explains that purchases are unavailable.
    await tester.tap(find.text('Get Lifetime Pro for \$4.99'));
    await tester.pumpAndSettle();
    expect(
      find.text('Purchases are not available in demo mode.'),
      findsOneWidget,
    );
    expect(gateway.lastBuyParam, isNull); // never launches billing
  });

  testWidgets('becoming Pro closes the screen with a welcome message', (
    tester,
  ) async {
    configureProducts();
    await pumpSplash(tester);
    expect(find.text('Upgrade to Oinkoin Pro'), findsOneWidget);

    // Simulate a completed purchase: premium flips and the notifier fires.
    ServiceConfig.setPremium(true);
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Oinkoin Pro'), findsNothing);
    expect(find.text('Welcome to Oinkoin Pro!'), findsOneWidget);
    expect(find.text('open'), findsOneWidget); // back on the previous screen
  });

  testWidgets('closing the screen returns to the previous page', (
    tester,
  ) async {
    configureProducts();
    await pumpSplash(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Oinkoin Pro'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
