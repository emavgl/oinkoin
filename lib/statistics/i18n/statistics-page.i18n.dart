import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
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
        "it_it": "Guadagno",
        "es_es": "Ingresos",
        "fr_fr": "Revenu",
        "de_de": "TODO",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Spese",
        "es_es": "Gastos",
        "fr_fr": "Dépenses",
        "de_de": "TODO",
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
        "en_us": "Others",
        "it_it": "Altre",
        "es_es": "Gastos",
        "fr_fr": "Dépenses",
        "de_de": "TODO",
      } +
      {
        "en_us": "Entries grouped by category",
        "it_it": "Movimenti raggruppati per categoria",
        "es_es": "Saldo",
        "fr_fr": "Balance",
        "de_de": "TODO",
      };
  String get i18n => localize(this, _translations);
}
