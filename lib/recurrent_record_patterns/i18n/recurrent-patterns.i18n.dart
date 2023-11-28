import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "No recurrent records yet.",
        "it_it": "Nessun movimento ricorrente.",
        "de_de": "Keine wiederkehrenden Einträge vorhanden.",
      } +
      {
        "en_us": "Recurrent record detail",
        "it_it": "Dettagli movimento ricorrente",
        "de_de": "Eintrag-Details",
      } +
      {
        "en_us": "Do you really want to delete this recurrent record?",
        "it_it": "Vuoi davvero cancellare il movimento ricorrente?",
        "de_de": "Soll der wiederkehrende Eintrag wirklich gelöscht werden?",
      } +
      {
        "en_us": "From:",
        "it_it": "Da:",
        "de_de": "Von:",
      } +
      {
        "en_us": "Repeat:",
        "it_it": "Ripeti:",
        "de_de": "Wiederholen:",
      } +
      {
        "en_us": "Every day",
        "it_it": "Ogni giorno",
        "de_de": "Täglich",
      } +
      {
        "en_us": "Every month",
        "it_it": "Ogni mese",
        "de_de": "Monatlich",
      } +
      {
        "en_us": "Every week",
        "it_it": "Ogni settimana",
        "de_de": "Wöchentlich",
      } +
      {
        "en_us": "Every two weeks",
        "it_it": "Ogni due settimane",
        "de_de": "Alle zwei Wochen",
      } +
      {
        "en_us": "Missing",
        "it_it": "Non definita",
        "de_de": "Fehlend",
      } +
      {
        "en_us": "Record name",
        "it_it": "Nome",
        "de_de": "Name",
      } +
      {
        "en_us": 'Edit record',
        "it_it": "Modifica movimento",
        "de_de": "Eintrag ändern",
      } +
      {
        "en_us": "Critical action",
        "it_it": "Azione irreversibile",
        "de_de": "Kritische Aktion",
      } +
      {
        "en_us": "Do you really want to delete this record?",
        "it_it": "Vuoi davvero rimuovere questo movimento?",
        "de_de": "Soll dieser Eintrag wirklich gelöscht werden?",
      } +
      {
        "en_us": "Yes",
        "it_it": "Si",
        "de_de": "Ja",
      } +
      {
        "en_us": "No",
        "it_it": "No",
        "de_de": "Nein",
      } +
      {
        "en_us": "Save",
        "it_it": "Salva",
        "de_de": "Speichern",
      } +
      {
        "en_us": "Delete",
        "it_it": "Cancella",
        "de_de": "Löschen",
      } +
      {
        "en_us": "Repeat",
        "it_it": "Ripeti",
        "de_de": "Wiederholen",
      } +
      {
        "en_us": "Please enter a value",
        "it_it": "Inserisci un valore",
        "de_de": "Bitte einen Wert eingeben",
      } +
      {
        "en_us": "Please enter a numeric value",
        "it_it": "Inserisci un valore numerico",
        "de_de": "Bitte einen numerischen Wert eingeben",
      } +
      {
        "en_us": "Add a note",
        "it_it": "Aggiungi note",
        "de_de": "Anmerkung hinzufügen",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Spese",
        "de_de": "Ausgaben",
      } +
      {
        "en_us": "Balance",
        "it_it": "Bilancio",
        "de_de": "Bilanz",
      } +
      {
        "en_us": 'Recurrent Records',
        "it_it": "Movimenti ricorrenti",
        "de_de": "Wiederkehrende Einträge",
      };
  String get i18n => localize(this, _translations);
}
