import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/records-utility-functions.dart';

const String FontNameDefault = 'Montserrat';

class MaterialThemeInstance {

  static ThemeData? lightTheme;
  static ThemeData? darkTheme;
  static ThemeData? currentTheme;
  static ThemeMode? themeMode;

  static getDefaultColorScheme(Brightness brightness) {
    Color defaultSeedColor = Color.fromARGB(255, 0, 92, 184);
    ColorScheme defaultColorScheme = ColorScheme.fromSeed(seedColor: defaultSeedColor, brightness: brightness);
    return defaultColorScheme;
  }

  static Future<ColorScheme> getColorScheme(Brightness brightness) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? dynamicColorScheme = prefs.getBool("dynamicColorScheme") == null ? false : prefs.getBool("dynamicColorScheme");
    if (dynamicColorScheme!) {
      AssetImage assetImage = getBackgroundImage();
      ColorScheme colorScheme = await ColorScheme.fromImageProvider(provider: assetImage, brightness: brightness);
      return colorScheme;
    }
    return Future.value(getDefaultColorScheme(brightness));
  }


  static getMaterialThemeData(Brightness brightness) async {
    return ThemeData(
        colorScheme: await getColorScheme(brightness),
        useMaterial3: true,
        brightness: brightness
    );
  }

  static Future<ThemeMode> getThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int themeModeIndex = prefs.getInt("themeMode") ?? 0;
    themeMode = ThemeMode.values[themeModeIndex];
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