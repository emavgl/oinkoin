import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Home",
        "it_it": "Movimenti",
        "de_de": "Start",
      } +
      {
        "en_us": "Categories",
        "it_it": "Categorie",
        "de_de": "Kategorien",
      } +
      {
        "en_us": "Settings",
        "it_it": "Impostazioni",
        "de_de": "Einstellungen",
      };

  String get i18n => localize(this, _translations);
}
