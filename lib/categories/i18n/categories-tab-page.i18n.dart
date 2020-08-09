import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Categories",
        "it_it": "Categorie",
      } +
      {
        "en_us": "Income",
        "it_it": "Entrate",
      } +
      {
        "en_us": "Add a new 'Expense' category",
        "it_it": "Nuova categoria sezione: Uscite",
      } +
      {
        "en_us": "Add a new 'Income' category",
        "it_it": "Nuova categoria sezione: Entrate",
      } +
      {
        "en_us": "Select the category",
        "it_it": "Seleziona una categoria",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Uscite",
      };

  String get i18n => localize(this, _translations);
}
