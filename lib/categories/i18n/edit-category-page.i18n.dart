import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Please enter the category name",
        "it_it": "Inserisci il nome della categoria",
      } +
      {
        "en_us": "Category name",
        "it_it": "Nome della categoria",
      } +
      {
        "en_us": "Edit category",
        "it_it": "Modifica categoria",
      } +
      {
        "en_us": "Delete",
        "it_it": "Cancella",
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
        "en_us": "Do you really want to delete the category?",
        "it_it": "Vuoi veramente cancellare la categoria?",
      } +
      {
        "en_us": "Deleting the category you will remove all the associated records",
        "it_it": "Cancellando la categoria cancellerai anche tutti i movimenti associati",
      } +
      {
        "en_us": "Save",
        "it_it": "Salva",
      } +
      {
        "en_us": "Color",
        "it_it": "Colore",
      } +
      {
        "en_us": "Icon",
        "it_it": "Icona",
      };

  String get i18n => localize(this, _translations);
}
