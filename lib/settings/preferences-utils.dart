import 'package:shared_preferences/shared_preferences.dart';

import 'constants/preferences-defaults-values.dart';

class PreferencesUtils {
  static T? getOrDefault<T>(SharedPreferences prefs, String key) {
    var retrievedValue = prefs.get(key);
    if (retrievedValue != null) {
      return retrievedValue as T;
    }
    return PreferencesDefaultValues.defaultValues[key];
  }
}