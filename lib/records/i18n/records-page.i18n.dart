import 'package:i18n_extension/i18n_extension.dart';

// this extension is for localizing and translating strings for the
// 'movements-page.dart' widget. Essentially, for each string in the
// widget, you report here the translation and related locale.
// Then, in the 'movements-page.dart' widget, you just append '.i18n' to
// the strings you want to translate (and of course import this dart file)
// e.g., "This is my message." => "This is my message.".i18n
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Shows records per",
        "it_it": "Mostra movimenti per",
        "de_de": "Zeigt Einträge pro",
      } +
      {
        "en_us": "Year",
        "it_it": "Anno",
        "de_de": "Jahr",
      } +
      {
        "en_us": "Date Range",
        "it_it": "Intervallo di date",
        "de_de": "Datumsbereich",
      } +
      {
        "en_us": "No entries yet.",
        "it_it": "Nessun movimento da visualizzare.",
        "de_de": "Noch keine Einträge vorhanden.",
      } +
      {
        "en_us": "Add a new record",
        "it_it": "Aggiungi un nuovo movimento.",
        "de_de": "Neuen Eintrag hinzufügen",
      } +
      {
        "en_us": "No Category is set yet.",
        "it_it": "Nessuna categoria inserita.",
        "de_de": "Es wurde noch keine Kategorie festgelegt.",
      } +
      {
        "en_us": "You need to set a category first. Go to Category tab and add a new category.",
        "it_it": "Devi prima aggiungere almeno una categoria. Vai nella tab 'Categorie' per aggiungerne una.",
        "de_de": "Sie müssen zuerst eine Kategorie festlegen. Gehen Sie zum Tab 'Kategorie' und fügen Sie eine neue Kategorie hinzu.",
      } +
      {
        "en_us": "Available on Oinkoin Pro",
        "it_it": "Disponibile su Oinkoin Pro",
        "de_de": "Verfügbar auf Oinkoin Pro",
      } +
      {
        "en_us": "Export CSV",
        "it_it": "Esporta CSV",
        "de_de": "CSV exportieren",
      } +
      {
        "en_us": "Rate this app",
        "it_it": "Vota Oinkoin",
        "de_de": "Diese App bewerten",
      } +
      {
        "en_us": "Add",
        "it_it": "Aggiungi",
        "de_de": "Hinzufügen",
      } +
      {
        "en_us": "If you like this app, please take a little bit of your time to review it !\nIt really helps us and it shouldn\'t take you more than one minute.",
        "it_it": "Se ti piace l'applicazione, aiutaci a crescere lasciando una recensione su Google Play store.",
        "de_de": "Wenn Ihnen diese App gefällt, nehmen Sie sich bitte etwas Zeit, um sie zu bewerten! Es hilft uns wirklich und sollte nicht länger als eine Minute dauern.",
      } +
      {
        "en_us": "Month",
        "it_it": "Mese",
        "de_de": "Monat",
      };


  String get i18n => localize(this, _translations);
}
