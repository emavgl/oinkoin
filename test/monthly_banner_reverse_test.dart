import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/banner-image-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/monthly-banner-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A valid 1x1 transparent PNG, returned by the mocked asset bundle so the
/// month tiles (which render [Image] widgets backed by [AssetImage]) can be
/// laid out in widget tests without hitting the real asset bundle.
final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// A fake [AssetBundle] used in widget tests. It answers the
/// `AssetManifest.bin` lookup with an empty manifest and every other asset
/// request with the transparent PNG, so [Image] widgets backed by
/// [AssetImage] can be built without the real app asset bundle.
class _FakeAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    return kTransparentImage.buffer.asByteData();
  }
}

void main() {
  Future<void> initPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  }

  setUpAll(() async {
    // extractMonthString() in the month tiles needs the default locale's date
    // symbols to be loaded before any DateFormat is constructed.
    await initializeDateFormatting('en_US', null);
  });

  setUp(() {
    ServiceConfig.isPremium = true;
    ServiceConfig.sharedPreferences = null;
  });

  group('BannerImageService.displayMonth', () {
    test('returns the same month when reversal is disabled', () async {
      await initPrefs({});
      for (var month = 1; month <= 12; month++) {
        expect(BannerImageService.displayMonth(month), month);
      }
    });

    test('shifts each month by 6 when reversal is enabled', () async {
      await initPrefs({'reverseMonthlyImages': true});
      expect(BannerImageService.displayMonth(1), 7);
      expect(BannerImageService.displayMonth(2), 8);
      expect(BannerImageService.displayMonth(3), 9);
      expect(BannerImageService.displayMonth(6), 12);
      expect(BannerImageService.displayMonth(7), 1);
      expect(BannerImageService.displayMonth(8), 2);
      expect(BannerImageService.displayMonth(12), 6);
    });

    test('is its own inverse (applying twice returns the original)', () async {
      await initPrefs({'reverseMonthlyImages': true});
      for (var month = 1; month <= 12; month++) {
        expect(BannerImageService.displayMonth(
            BannerImageService.displayMonth(month)), month);
      }
    });

    test('leaves out-of-range month indices unchanged', () async {
      await initPrefs({'reverseMonthlyImages': true});
      expect(BannerImageService.displayMonth(0), 0);
      expect(BannerImageService.displayMonth(13), 13);
      expect(BannerImageService.displayMonth(-1), -1);
    });

    test('defaults to no reversal when preferences are not initialized',
        () async {
      // ServiceConfig.sharedPreferences is null here (reset in setUp).
      expect(BannerImageService.displayMonth(1), 1);
    });
  });

  group('BannerImageService.getBannerImage with reversal', () {
    test('returns the shifted built-in image when reversal is enabled',
        () async {
      await initPrefs({'reverseMonthlyImages': true});
      final result = BannerImageService.getBannerImage(1);
      expect((result as AssetImage).assetName, 'assets/images/bkg-7.png');
    });

    test('returns the unshifted built-in image when reversal is disabled',
        () async {
      await initPrefs({});
      final result = BannerImageService.getBannerImage(1);
      expect((result as AssetImage).assetName, 'assets/images/bkg-1.png');
    });

    test('a custom assignment still wins even with reversal enabled',
        () async {
      await initPrefs({
        'reverseMonthlyImages': true,
        'monthlyBannerAssignments': '{"1":"asset:assets/images/bkg-3.png"}',
      });
      final result = BannerImageService.getBannerImage(1);
      expect((result as AssetImage).assetName, 'assets/images/bkg-3.png');
    });

    test('non-premium users still get the default image with reversal enabled',
        () async {
      ServiceConfig.isPremium = false;
      await initPrefs({'reverseMonthlyImages': true});
      final result = BannerImageService.getBannerImage(1);
      expect(
          (result as AssetImage).assetName, 'assets/images/bkg-default.png');
    });
  });

  group('MonthlyBannerPage buttons', () {
    /// A fake [AssetBundle] that satisfies the [AssetImage] resolution path
    /// (the `AssetManifest.bin` lookup plus the actual image bytes) so the
    /// month tiles can be rendered in a widget test.
    Future<void> pumpPage(WidgetTester tester) async {
      final bundle = _FakeAssetBundle();
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: bundle,
            child: const MonthlyBannerPage(),
          ),
        ),
      );
      await tester.pump();
    }

    AssetImage januaryTileImage(WidgetTester tester) {
      // The first Image in the first month tile belongs to the "January"
      // tile (month 1). Its provider is the built-in January image (bkg-1)
      // by default, or bkg-7 when Southern Hemisphere reordering is active.
      final image = tester.widget<Image>(
        find.byType(Image).first,
      );
      return image.image as AssetImage;
    }

    testWidgets('shows the Defaults and Southern Hemisphere buttons',
        (WidgetTester tester) async {
      await pumpPage(tester);

      expect(find.text('Defaults'), findsOneWidget);
      expect(find.text('Southern Hemisphere'), findsOneWidget);
    });

    testWidgets(
        'Southern Hemisphere reorders the January tile to July\'s image',
        (WidgetTester tester) async {
      await initPrefs({});
      await pumpPage(tester);

      expect(januaryTileImage(tester).assetName, 'assets/images/bkg-1.png');

      await tester.tap(find.text('Southern Hemisphere'));
      await tester.pump();

      expect(
          ServiceConfig.sharedPreferences!
              .getBool('reverseMonthlyImages'),
          isTrue);
      expect(januaryTileImage(tester).assetName, 'assets/images/bkg-7.png');
    });

    testWidgets('Defaults restores the original image order',
        (WidgetTester tester) async {
      await initPrefs({'reverseMonthlyImages': true});
      await pumpPage(tester);

      expect(januaryTileImage(tester).assetName, 'assets/images/bkg-7.png');

      await tester.tap(find.text('Defaults'));
      await tester.pump();

      expect(
          ServiceConfig.sharedPreferences!
              .getBool('reverseMonthlyImages'),
          isFalse);
      expect(januaryTileImage(tester).assetName, 'assets/images/bkg-1.png');
    });
  });
}
