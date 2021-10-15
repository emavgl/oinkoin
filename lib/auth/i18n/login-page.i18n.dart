import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Login",
        "it_it": "Accedi",
      } +
      {
        "en_us": "Start saving with Oinkoin!",
        "it_it": "Inizia a risparmiare con Oinkoin!",
      } +
      {
        "en_us": "Sign in with Google",
        "it_it": "Accedi con Google",
      };

  String get i18n => localize(this, _translations);
}
