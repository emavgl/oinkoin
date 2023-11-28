import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Please enter the category name",
        "it_it": "Inserisci il nome della categoria",
        "de_de": "Bitte einen Kategorie-Namen eingeben",
      } +
      {
        "en_us": "Category name",
        "it_it": "Nome della categoria",
        "de_de": "Kategorie-Name",
      } +
      {
        "en_us": "Edit category",
        "it_it": "Modifica categoria",
        "de_de": "Kategorie ändern",
      } +
      {
        "en_us": "Delete",
        "it_it": "Cancella",
        "de_de": "Löschen",
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
        "en_us": "Do you really want to delete the category?",
        "it_it": "Vuoi veramente cancellare la categoria?",
        "de_de": "Kategorie wirklich löschen?",
      } +
      {
        "en_us": "Deleting the category you will remove all the associated records",
        "it_it": "Cancellando la categoria cancellerai anche tutti i movimenti associati",
        "de_de": "Löschen der Kategorie entfernt auch alle Einträge dieser Kategorie",
      } +
      {
        "en_us": "Add a new category",
        "it_it": "Salva la categoria",
        "de_de": "Eine neue Kategorie hinzufügen",
      } +
      {
        "en_us": "Color",
        "it_it": "Colore",
        "de_de": "Farbe",
      } +
      {
        "en_us": "Choose a color",
        "it_it": "Scegli un colore",
        "de_de": "Farbe auwählen",
      } +
      {
        "en_us": "Name",
        "it_it": "Nome",
        "de_de": "Name",
      } +
      {
        "en_us": "Icon",
        "it_it": "Icona",
        "de_de": "Symbol",
      };

  String get i18n => localize(this, _translations);
}
