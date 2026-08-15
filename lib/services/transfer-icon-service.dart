import 'package:flutter/material.dart';
import 'package:piggybank/helpers/color-utils.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';

/// Stores the app-wide icon used to represent transfers.
///
/// The default remains [Icons.swap_horiz]. Saved icons are resolved from the
/// same shared icon set used by categories and wallets, so icon code points
/// remain stable across app launches.
class TransferIconService {
  /// Default transfer icon background: the grey entry from the shared
  /// Category/Wallet color palette (Category.colors).
  static final Color? defaultColor = Colors.grey[400];

  static IconData get icon {
    final codePoint = ServiceConfig.sharedPreferences
        ?.getInt(PreferencesKeys.transferIconCodePoint);
    if (codePoint == null) return Icons.swap_horiz;

    for (final candidate in CategoryIcons.pro_category_icons) {
      if (candidate.codePoint == codePoint) return candidate;
    }
    return Icons.swap_horiz;
  }

  static String? get iconEmoji =>
      ServiceConfig.sharedPreferences?.getString(PreferencesKeys.transferIconEmoji);

  static Color? get color {
    final serialized = ServiceConfig.sharedPreferences
        ?.getString(PreferencesKeys.transferIconColor);
    if (serialized == null) return defaultColor;

    final components = serialized.split(':').map(int.tryParse).toList();
    if (components.length != 4 || components.any((component) => component == null)) {
      return null;
    }
    return Color.fromARGB(
      components[0]!,
      components[1]!,
      components[2]!,
      components[3]!,
    );
  }

  static Future<void> save({
    required String? iconEmoji,
    required IconData? icon,
    required Color? color,
  }) async {
    final prefs = ServiceConfig.sharedPreferences;
    if (prefs == null) return;

    if (iconEmoji != null) {
      await prefs.setString(PreferencesKeys.transferIconEmoji, iconEmoji);
      await prefs.remove(PreferencesKeys.transferIconCodePoint);
    } else if (icon != null) {
      await prefs.setInt(
          PreferencesKeys.transferIconCodePoint, icon.codePoint);
      await prefs.remove(PreferencesKeys.transferIconEmoji);
    }

    if (color != null) {
      await prefs.setString(
          PreferencesKeys.transferIconColor, serializeColorToString(color));
    } else {
      await prefs.remove(PreferencesKeys.transferIconColor);
    }
  }

  /// Restores the original transfer icon aspect: the default grey background
  /// and the [Icons.swap_horiz] icon with no emoji.
  static Future<void> reset() async {
    final prefs = ServiceConfig.sharedPreferences;
    if (prefs == null) return;
    await prefs.remove(PreferencesKeys.transferIconCodePoint);
    await prefs.remove(PreferencesKeys.transferIconEmoji);
    await prefs.remove(PreferencesKeys.transferIconColor);
  }
}
