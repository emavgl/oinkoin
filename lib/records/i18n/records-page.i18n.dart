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
      } +
      {
        "en_us": "Year",
        "it_it": "Anno",
      } +
      {
        "en_us": "Date Range",
        "it_it": "Intervallo di date",
      } +
      {
        "en_us": "No entries yet.",
        "it_it": "Nessun movimento da visualizzare.",
      } +
      {
        "en_us": 'Add a new record',
        "it_it": "Aggiungi un nuovo movimento.",
      } +
      {
        "en_us": "No Category is set yet.",
        "it_it": "Nessuna categoria inserita.",
      } +
      {
        "en_us": "You need to set a category first. Go to Category tab and add a new category.",
        "it_it": "Devi prima aggiungere almeno una categoria. Vai nella tab 'Categorie' per aggiungerne una.",
      } +
      {
        "en_us": "Available on Oinkoin Pro",
        "it_it": "Disponibile su Oinkoin Pro",
      } +
      {
        "en_us": "Export CSV",
        "it_it": "Esporta CSV",
      } +
      {
        "en_us": 'Rate this app',
        "it_it": "Vota Oinkoin",
      } +
      {
        "en_us": 'Add',
        "it_it": "Aggiungi",
      } +
      {
        "en_us": "If you like this app, please take a little bit of your time to review it !\nIt really helps us and it shouldn\'t take you more than one minute.",
        "it_it": "Se ti piace l'applicazione, aiutaci a crescere lasciando una recensione su Google Play store.",
      } +
      {
        "en_us": "Month",
        "it_it": "Mese",
      };

  String get i18n => localize(this, _translations);
}
