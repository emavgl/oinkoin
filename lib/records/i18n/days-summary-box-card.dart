import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Income",
        "it_it": "Entrate",
        "de_de": "Einkommen",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Uscite",
        "de_de": "Ausgaben",
      } +
      {
        "en_us": "Balance",
        "it_it": "Bilancio",
        "de_de": "Bilanz",
      };

  String get i18n => localize(this, _translations);
}
