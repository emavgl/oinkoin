import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Select the currency",
        "it_it": "Seleziona la moneta",
        "de_de": "Währung auswählen",
      };

  String get i18n => localize(this, _translations);
}
