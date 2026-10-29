import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:piggybank/services/locale-service.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';

import 'helpers/records-utility-functions.dart';

const String FontNameDefault = 'Montserrat';

/// The bundled Noto family that renders [locale]'s CJK glyphs, or null when
/// the locale needs no CJK font. Chinese splits by script: Traditional
/// locales (zh-TW and other Hant regions) get Noto Sans TC, every other
/// Chinese locale the Simplified variant.
String? getCjkFontFamilyForLocale(Locale locale) {
  switch (locale.languageCode) {
    case 'ja':
      return 'Noto Sans JP';
    case 'zh':
      return LocaleService.usesTraditionalChinese(locale)
          ? 'Noto Sans TC'
          : 'Noto Sans SC';
    default:
      return null;
  }
}

/// Returns the CJK font fallback matching the given locale, so that localized
/// glyph variants (Japanese vs Simplified vs Traditional Chinese) are
/// rendered with the appropriate font. Returns null when the locale needs no
/// special CJK font.
List<String>? getFontFamilyFallbackForLocale(Locale locale) {
  final family = getCjkFontFamilyForLocale(locale);
  return family == null ? null : [family];
}

class MaterialThemeInstance {
  static ThemeData? lightTheme;
  static ThemeData? darkTheme;
  static ThemeData? currentTheme;
  static ThemeMode? themeMode;
  static Color defaultSeedColor = Color.fromARGB(255, 255, 214, 91);

  /// The stored theme style index counts [ThemeMode] entries plus the black
  /// variant, so it cannot index [ThemeMode.values] directly. "Black" is a
  /// dark theme, only the generated colors change.
  static ThemeMode themeModeFromIndex(int? themeStyleIndex) {
    if (themeStyleIndex == PreferencesOptions.blackThemeMode) {
      return ThemeMode.dark;
    }
    if (themeStyleIndex == null ||
        themeStyleIndex < 0 ||
        themeStyleIndex >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[themeStyleIndex];
  }

  static bool isBlackTheme(int? themeStyleIndex) =>
      themeStyleIndex == PreferencesOptions.blackThemeMode;

  /// Makes the dark surfaces of [scheme] pure black, keeping the accent colors
  /// derived from the seed. The container shades stay just above black so
  /// elevated surfaces (cards, dialogs, sheets) remain distinguishable.
  static ColorScheme withBlackSurfaces(ColorScheme scheme) {
    return scheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: const Color(0xFF282828),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF242424),
    );
  }

  static getDefaultColorScheme(Brightness brightness) {
    ColorScheme defaultColorScheme = ColorScheme.fromSeed(
        seedColor: defaultSeedColor, brightness: brightness);
    return defaultColorScheme;
  }

  static Future<ColorScheme> getColorScheme(Brightness brightness) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? dynamicColorScheme =
        PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.themeColor);

    int? themeStyleIndex =
        PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.themeMode);

    ColorScheme colorScheme;
    switch (dynamicColorScheme) {
      case 1:
        {
          log("Using system colors");
          await SystemTheme.accentColor.load();
          SystemTheme.fallbackColor = defaultSeedColor;
          final accentColor = SystemTheme.accentColor.accent;
          if (accentColor == defaultSeedColor) {
            log("Failed to retrieve system color, using default instead");
          }
          colorScheme = ColorScheme.fromSeed(
              seedColor: accentColor, brightness: brightness);
        }

      case 2:
        {
          log("Using dynamic colors");
          ImageProvider backgroundImage =
              getBackgroundImage(DateTime.now().month);
          try {
            colorScheme = await ColorScheme.fromImageProvider(
                provider: backgroundImage, brightness: brightness);
          } catch (e) {
            log("Failed to derive colors from the banner image: $e");
            colorScheme = getDefaultColorScheme(brightness);
          }
        }

      default:
        {
          colorScheme = getDefaultColorScheme(brightness);
        }
    }

    if (brightness == Brightness.dark && isBlackTheme(themeStyleIndex)) {
      log("Using the Black dark theme");
      colorScheme = withBlackSurfaces(colorScheme);
    }
    return colorScheme;
  }

  static getMaterialThemeData(Brightness brightness) async {
    var colorScheme = await getColorScheme(brightness);
    final locale = LocaleService.resolveLanguageLocale();
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: brightness,
      fontFamilyFallback: getFontFamilyFallbackForLocale(locale),
    );
  }

  static Future<ThemeMode> getThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? themeModeIndex =
        PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.themeMode);
    themeMode = themeModeFromIndex(themeModeIndex);
    return themeMode!;
  }

  static Future<ThemeData> getLightTheme() async {
    if (lightTheme == null) {
      lightTheme = await getMaterialThemeData(Brightness.light);
    }
    return lightTheme!;
  }

  static Future<ThemeData> getDarkTheme() async {
    if (darkTheme == null) {
      darkTheme = await getMaterialThemeData(Brightness.dark);
    }
    return darkTheme!;
  }
}
