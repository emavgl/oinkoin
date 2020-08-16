import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Missing",
        "it_it": "Non definita",
      } +
      {
        "en_us": "Record name  (optional)",
        "it_it": "Nome (opzionale)",
      } +
      {
        "en_us": 'Edit record',
        "it_it": "Modifica movimento",
      } +
      {
        "en_us": "Critical action",
        "it_it": "Azione irreversibile",
      } +
      {
        "en_us": "Do you really want to delete this record?",
        "it_it": "Vuoi davvero rimuovere questo movimento?",
      } +
      {
        "en_us": "Yes",
        "it_it": "Si",
      } +
      {
        "en_us": "No",
        "it_it": "No",
      } +
      {
        "en_us": "Save",
        "it_it": "Salva",
      } +
      {
        "en_us": "How much?",
        "it_it": "Quanto?",
      } +
      {
        "en_us": "When?",
        "it_it": "Quando?",
      } +
      {
        "en_us": "How?",
        "it_it": "Perché?",
      } +
      {
        "en_us": "Description (optional)",
        "it_it": "Descrizione (opzionale)",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Spese",
      } +
      {
        "en_us": "Balance",
        "it_it": "Bilancio",
      };

  String get i18n => localize(this, _translations);
}
