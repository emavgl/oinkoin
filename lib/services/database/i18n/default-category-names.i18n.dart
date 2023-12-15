import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "House",
        "it_it": "Casa",
        "de_de": "Wohnen",
      } +
      {
        "en_us": "Transports",
        "it_it": "Transporti",
        "de_de": "Verkehr",
      } +
      {
        "en_us": "Food",
        "it_it": "Cibo",
        "de_de": "Lebensmittel",
      } +
      {
        "en_us": "Salary",
        "it_it": "Salario",
        "de_de": "Gehalt",
      };

  String get i18n => localize(this, _translations);
}
