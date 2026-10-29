import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('theme style mapping', () {
    test('maps the built-in styles to their ThemeMode', () {
      expect(MaterialThemeInstance.themeModeFromIndex(0), ThemeMode.system);
      expect(MaterialThemeInstance.themeModeFromIndex(1), ThemeMode.light);
      expect(MaterialThemeInstance.themeModeFromIndex(2), ThemeMode.dark);
    });

    test('Black behaves as a dark theme', () {
      final index = PreferencesOptions.blackThemeMode;
      expect(MaterialThemeInstance.themeModeFromIndex(index), ThemeMode.dark);
      expect(MaterialThemeInstance.isBlackTheme(index), isTrue);
      expect(MaterialThemeInstance.isBlackTheme(2), isFalse);
      expect(MaterialThemeInstance.isBlackTheme(null), isFalse);
    });

    test('unknown stored values fall back to the system theme', () {
      expect(MaterialThemeInstance.themeModeFromIndex(null), ThemeMode.system);
      expect(MaterialThemeInstance.themeModeFromIndex(-1), ThemeMode.system);
      expect(MaterialThemeInstance.themeModeFromIndex(42), ThemeMode.system);
    });
  });

  group('Black color scheme', () {
    final darkScheme = MaterialThemeInstance.getDefaultColorScheme(
      Brightness.dark,
    );

    test('uses pure black surfaces and keeps the accent colors', () {
      final black = MaterialThemeInstance.withBlackSurfaces(darkScheme);

      expect(black.surface, Colors.black);
      expect(black.surfaceDim, Colors.black);
      expect(black.surfaceContainerLowest, Colors.black);
      expect(black.surfaceContainer, isNot(darkScheme.surfaceContainer));
      expect(black.primary, darkScheme.primary);
      expect(black.onSurface, darkScheme.onSurface);
      // Elevated containers stay distinguishable but very close to black.
      expect(
        black.surfaceContainerLow.computeLuminance(),
        lessThan(black.surfaceContainerHigh.computeLuminance()),
      );
      expect(black.surfaceContainerHighest.computeLuminance(), lessThan(0.1));
    });

    test('applies to the dark theme only', () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.themeColor: 0,
        PreferencesKeys.themeMode: PreferencesOptions.blackThemeMode,
      });

      final dark = await MaterialThemeInstance.getColorScheme(Brightness.dark);
      final light = await MaterialThemeInstance.getColorScheme(
        Brightness.light,
      );

      expect(dark.surface, Colors.black);
      expect(light.surface, isNot(Colors.black));
    });

    test('the Dark style keeps the generated grey surfaces', () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.themeColor: 0,
        PreferencesKeys.themeMode: 2,
      });

      final dark = await MaterialThemeInstance.getColorScheme(Brightness.dark);

      expect(dark.surface, isNot(Colors.black));
    });

    testWidgets('the app theme paints a pure black page background',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.themeColor: 0,
        PreferencesKeys.themeMode: PreferencesOptions.blackThemeMode,
      });
      MaterialThemeInstance.darkTheme = null;

      final scheme =
          await MaterialThemeInstance.getColorScheme(Brightness.dark);
      final dark = ThemeData(
        colorScheme: scheme,
        brightness: Brightness.dark,
        useMaterial3: true,
      );
      expect(dark.scaffoldBackgroundColor, Colors.black);

      await tester.pumpWidget(
        MaterialApp(theme: dark, home: const Scaffold(body: Text('content'))),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.black);
    });
  });
}
