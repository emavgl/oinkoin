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
        "en_us": "Make a backup of all the data",
        "it_it": "Crea un backup dei tuoi dati",
      } +
      {
        "en_us": "Restore Backup",
        "it_it": "Ripristino",
      } +

      {
        "en_us": "Restore successful",
        "it_it": "Ripristino riusciuto",
      } +
      {
        "en_us": "Restore unsuccessful",
        "it_it": "Ripristino non riuscito",
      } +
      {
        "en_us": "The data from the backup file are now restored.",
        "it_it": "I dati dal file di backup sono stati ripristinati.",
      } +
      {
        "en_us": "Make sure you have the latest version of the app. If so, the backup file may be corrupted.",
        "it_it": "Assicurati di avere l'ultima versione dell'app. Se già aggiornata, allora il file di backup potrebbe essere corrotto.",
      } +
      {
        "en_us": "Restore Backup",
        "it_it": "Ripristino",
      } +

      {
        "en_us": "Restore data from a backup file",
        "it_it": "Ripristina dati da un file di backup",
      } +
      {
        "en_us": "Recurrent Records",
        "it_it": "Movimenti ricorrenti",
      } +
      {
        "en_us": "View or delete recurrent records",
        "it_it": "Visualizza o cancella movimenti ricorrenti",
      } +
      {
        "en_us": "Customization",
        "it_it": "Preferenze",
      } +
      {
        "en_us": "Dynamic colors",
        "it_it": "Colori dinamici",
      } +
      {
        "en_us": "System",
        "it_it": "Sistema",
      } +
      {
        "en_us": "Light",
        "it_it": "Chiaro",
      } +
      {
        "en_us": "Dark",
        "it_it": "Scuro",
      } +
      {
        "en_us": "Theme style",
        "it_it": "Stile del tema",
      } +
      {
        "en_us": "Select the app theme style - Require App restart",
        "it_it": "Seleziona il tema dell'app - Richiede riavvio dell'app",
      } +
      {
        "en_us": "Dynamic colors",
        "it_it": "Colori dinamici",
      } +
      {
        "en_us": "Use a color palette based on the main image - Require App restart",
        "it_it": "Use una palette di colori basata sull'immagine principale - Richiede riavvio dell'app",
      } +
      {
        "en_us": "Set visual preferences",
        "it_it": "Imposta preferenze grafiche",
      } +
      {
        "en_us": "Pay us a coffee",
        "it_it": "Donaci un caffè",
      };

  String get i18n => localize(this, _translations);
}
