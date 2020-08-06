import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Income",
        "it_it": "Entrate",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Uscite",
      } +
      {
        "en_us": "Balance",
        "it_it": "Bilancio",
      };

  String get i18n => localize(this, _translations);
}
