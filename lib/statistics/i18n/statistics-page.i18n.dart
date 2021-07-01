import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Statistics",
        "it_it": "Statistiche",
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
        "en_us": "No entries to show.",
        "it_it": "Nessun movimento da visualizzare.",
      } +
      {
        "en_us": "Records",
        "it_it": "Movimenti",
      } +
      {
        "en_us": "Sum",
        "it_it": "Somma",
      } +
      {
        "en_us": "Min",
        "it_it": "Minimo",
      } +
      {
        "en_us": "Max",
        "it_it": "Massimo",
      } +
      {
        "en_us": "Average",
        "it_it": "Media",
      } +
      {
        "en_us": "Median",
        "it_it": "Mediana",
      } +
      {
        "en_us": "Month",
        "it_it": "Mese",
      } +
      {
        "en_us": "Day",
        "it_it": "Giorno",
      } +
      {
        "en_us": "Trend in",
        "it_it": "Andamento",
      } +
      {
        "en_us": "Entries grouped by category",
        "it_it": "Movimenti raggruppati per categoria",
      };
  String get i18n => localize(this, _translations);
}
