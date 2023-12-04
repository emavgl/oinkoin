import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Categories",
        "it_it": "Categorie",
        "de_de": "Kategorien",
      } +
      {
        "en_us": "Income",
        "it_it": "Entrate",
        "de_de": "Einkommen",
      } +
      {
        "en_us": "Add a new 'Expense' category",
        "it_it": "Nuova categoria sezione: Uscite",
        "de_de": "Ene neue 'Ausgaben'-Kategorie hinzufügen",
      } +
      {
        "en_us": "Add a new 'Income' category",
        "it_it": "Nuova categoria sezione: Entrate",
        "de_de": "Ene neue 'Einkommen'-Kategorie hinzufügen",
      } +
      {
        "en_us": "Select the category",
        "it_it": "Seleziona una categoria",
        "de_de": "Kategorie auswählen",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Uscite",
        "de_de": "Ausgaben",
      };

  String get i18n => localize(this, _translations);
}
