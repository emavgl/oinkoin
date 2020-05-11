import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Settings",
        "it_it": "Impostazioni",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Currency",
        "it_it": "Valuta",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Select the currency for your expenses",
        "it_it": "Selezione la valuta per le tue spese",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Theme",
        "it_it": "Tema",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Select the theme of the app",
        "it_it": "Seleziona il tema dell'app",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Export",
        "it_it": "Esporta",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Make a backup of the data of the app",
        "it_it": "Fai un backup dei dati dell'app",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Import",
        "it_it": "Importa",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Import a backup of the data of the app",
        "it_it": "Importa un backup dei dati dell'app",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Feedback",
        "it_it": "Feedback",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Any suggestion? Tell us!",
        "it_it": "Qualche Suggerimento? Contattaci!",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Thanks",
        "it_it": "Ringraziamenti",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Pay us a coffee",
        "it_it": "Donaci un caffè",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
