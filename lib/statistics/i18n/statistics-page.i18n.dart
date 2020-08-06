import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Statistics",
        "it_it": "Statistiche",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Income",
        "it_it": "Entrate",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Uscite",
      } +
      {
        "en_us": "Charts",
        "it_it": "Grafici",
      } +
      {
        "en_us": "Trend in the selected period",
        "it_it": "Andamento nel periodo selezionato",
      } +
      {
        "en_us": "Entries for category: ",
        "it_it": "Movimenti per la categoria: ",
      } +
      {
        "en_us": "Others",
        "it_it": "Altre",
      } +
      {
        "en_us": "Entries grouped by category",
        "it_it": "Movimenti raggruppati per categoria",
      };
  String get i18n => localize(this, _translations);
}
