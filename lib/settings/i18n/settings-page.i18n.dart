import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Settings",
        "it_it": "Impostazioni",
      } +
      {
        "en_us": "Currency",
        "it_it": "Valuta",
      } +
      {
        "en_us": "Select the currency for your expenses",
        "it_it": "Selezione la valuta per le tue spese",
      } +
      {
        "en_us": "Theme",
        "it_it": "Tema",
      } +
      {
        "en_us": "Select the theme of the app",
        "it_it": "Seleziona il tema dell'app",
      } +
      {
        "en_us": "Export",
        "it_it": "Esporta",
      } +
      {
        "en_us": "Delete",
        "it_it": "Cancella",
      } +
      {
        "en_us": "Delete all the data",
        "it_it": "Cancella tutti i dati inseriti",
      } +
      {
        "en_us": "Make a backup of the data of the app",
        "it_it": "Fai un backup dei dati dell'app",
      } +
      {
        "en_us": "Import",
        "it_it": "Importa",
      } +
      {
        "en_us": "Backup",
        "it_it": "Backup",
      } +
      {
        "en_us": "Info",
        "it_it": "Info",
      } +
      {
        "en_us": "Feedback",
        "it_it": "Feedback",
      } +
      {
        "en_us": "Send us a feedback",
        "it_it": "Invia un feedback",
      } +
      {
        "en_us": "Privacy policy and credits",
        "it_it": "Privacy policy e crediti",
      } +
      {
        "en_us": "Import a backup of the data of the app",
        "it_it": "Importa un backup dei dati dell'app",
      } +
      {
        "en_us": "Thanks",
        "it_it": "Ringraziamenti",
      } +
      {
        "en_us": "Available on Piggybank Pro",
        "it_it": "Disponibile su Piggybank Pro",
      } +
      {
        "en_us": "Critical action",
        "it_it": "Azione irreversibile",
      } +
      {
        "en_us": "Do you really want to delete all the data?",
        "it_it": "Vuoi davvero rimuovere tutti i dati?",
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
        "en_us": "Available on Piggybank Pro",
        "it_it": "Disponibile su Piggybank Pro",
      } +
      {
        "en_us": "(Piggybank Pro) Make a backup of all the data",
        "it_it": "(Piggybank Pro) Crea un backup dei tuoi dati",
      } +
      {
        "en_us": "Restore Backup",
        "it_it": "Ripristino",
      } +
      {
        "en_us": "(Piggybank Pro) Restore a backup",
        "it_it": "(Piggybank Pro) Ripristina un backup",
      } +
      {
        "en_us": "Pay us a coffee",
        "it_it": "Donaci un caffè",
      };

  String get i18n => localize(this, _translations);
}
