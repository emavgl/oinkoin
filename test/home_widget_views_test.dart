import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/home_widgets/widget_views.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/home-widget-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Home screen widget helpers: sparkline painting and daily series math.
/// Data pushing itself is covered on-device (needs the widget plugin).
void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
  });

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

  group('dailySeries converts to the default currency', () {
    const walletCurrencyMap = {1: 'EUR', 2: 'USD', 3: 'JPY'};

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'defaultCurrency': 'EUR',
        'currencyConversionRates': '{"USD_EUR": 0.92}',
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('balance series keeps converted signs', () {
      final food = Category('Food', categoryType: CategoryType.expense);

      final series = HomeWidgetService.dailySeries(
        <Record?>[
          Record(-100.0, 'a', food, DateTime.utc(2026, 7, 1),
              walletId: 1, timeZoneName: 'UTC'),
          Record(-100.0, 'b', food, DateTime.utc(2026, 7, 1),
              walletId: 2, timeZoneName: 'UTC'),
        ],
        isBalance: true,
        walletCurrencyMap: walletCurrencyMap,
      );

      // -100 EUR + (-100 USD -> -92 EUR) = -192, not -200.
      expect(series.length, 1);
      expect(series.single, closeTo(-192.0, 0.001));
    });

    test('non-balance series sums converted magnitudes', () {
      final food = Category('Food', categoryType: CategoryType.expense);

      final series = HomeWidgetService.dailySeries(
        <Record?>[
          Record(-100.0, 'a', food, DateTime.utc(2026, 7, 1),
              walletId: 1, timeZoneName: 'UTC'),
          Record(-100.0, 'b', food, DateTime.utc(2026, 7, 1),
              walletId: 2, timeZoneName: 'UTC'),
        ],
        isBalance: false,
        walletCurrencyMap: walletCurrencyMap,
      );

      expect(series.length, 1);
      expect(series.single, closeTo(192.0, 0.001));
    });

    test('missing rate falls back to the raw value', () {
      final food = Category('Food', categoryType: CategoryType.expense);

      final series = HomeWidgetService.dailySeries(
        <Record?>[
          Record(-100.0, 'a', food, DateTime.utc(2026, 7, 1),
              walletId: 3, timeZoneName: 'UTC'),
        ],
        isBalance: false,
        walletCurrencyMap: walletCurrencyMap,
      );

      expect(series, [100.0]);
    });
  });
}
