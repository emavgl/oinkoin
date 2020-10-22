import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "No recurrent records yet.",
        "it_it": "Nessun movimento ricorrente.",
      } +
      {
        "en_us": "Recurrent record detail",
        "it_it": "Dettagli movimento ricorrente",
      } +
      {
        "en_us": "Do you really want to delete this recurrent record?",
        "it_it": "Vuoi davvero cancellare il movimento ricorrente?",
      } +
      {
        "en_us": "From:",
        "it_it": "Da:",
      } +
      {
        "en_us": "Repeat:",
        "it_it": "Ripeti:",
      } +
      {
        "en_us": "Every day",
        "it_it": "Ogni giorno",
      } +
      {
        "en_us": "Every month",
        "it_it": "Ogni mese",
      } +
      {
        "en_us": "Every week",
        "it_it": "Ogni settimana",
      } +
      {
        "en_us": "Missing",
        "it_it": "Non definita",
      } +
      {
        "en_us": "Record name",
        "it_it": "Nome",
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
        "en_us": "Delete",
        "it_it": "Cancella",
      } +
      {
        "en_us": "Repeat",
        "it_it": "Ripeti",
      } +
      {
        "en_us": "Please enter a value",
        "it_it": "Inserisci un valore",
      } +
      {
        "en_us": "Please enter a numeric value",
        "it_it": "Inserisci un valore numerico",
      } +
      {
        "en_us": "Add a note",
        "it_it": "Aggiungi note",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Spese",
      } +
      {
        "en_us": "Balance",
        "it_it": "Bilancio",
      } +
      {
        "en_us": 'Recurrent Records',
        "it_it": "Movimenti ricorrenti",
      };
  String get i18n => localize(this, _translations);
}
