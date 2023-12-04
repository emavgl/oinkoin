import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Statistics",
        "it_it": "Statistiche",
        "de_de": "Statistiken",
      } +
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
        "en_us": "Charts",
        "it_it": "Grafici",
        "de_de": "Grafiken",
      } +
      {
        "en_us": "Trend in the selected period",
        "it_it": "Andamento nel periodo selezionato",
        "de_de": "Verlauf in ausgewähltem Zeitraum",
      } +
      {
        "en_us": "Entries for category: ",
        "it_it": "Movimenti per la categoria: ",
        "de_de": "Einträge für die Kategorie: ",
      } +
      {
        "en_us": "Others",
        "it_it": "Altre",
        "de_de": "Andere",
      } +
      {
        "en_us": "No entries to show.",
        "it_it": "Nessun movimento da visualizzare.",
        "de_de": "Keine Einträge anzeigbar.",
      } +
      {
        "en_us": "Records",
        "it_it": "Movimenti",
        "de_de": "Eintrag",
      } +
      {
        "en_us": "Sum",
        "it_it": "Somma",
        "de_de": "Summe"
      } +
      {
        "en_us": "Min",
        "it_it": "Minimo",
        "de_de": "Minimum"
      } +
      {
        "en_us": "Max",
        "it_it": "Massimo",
        "de_de": "Maximum"
      } +
      {
        "en_us": "Average",
        "it_it": "Media",
        "de_de": "Durchschnitt",
      } +
      {
        "en_us": "Median",
        "it_it": "Mediana",
        "de_de": "Median",
      } +
      {
        "en_us": "Month",
        "it_it": "Mese",
        "de_de": "Monat",
      } +
      {
        "en_us": "Day",
        "it_it": "Giorno",
        "de_de": "Tag",
      } +
      {
        "en_us": "Trend in",
        "it_it": "Andamento",
        "de_de": "Verlauf",
      } +
      {
        "en_us": "Dismiss",
        "it_it": "Chiudi",
        "de_de": "Verwerfen",
      } +
      {
        "en_us": "Entries grouped by category",
        "it_it": "Movimenti raggruppati per categoria",
        "de_de": "Einträge nach Kategorie grupiert",
      };
  String get i18n => localize(this, _translations);
}
