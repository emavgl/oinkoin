import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Categories",
        "it_it": "Categorie",
      } +
      {
        "en_us": "Income",
        "it_it": "Guadagni",
      } +
      {
        "en_us": "Add a new 'Expense' category",
        "it_it": "Nuova categoria sezione: Spese",
      } +
      {
        "en_us": "Add a new 'Income' category",
        "it_it": "Nuova categoria sezione: Guadagni",
      } +
      {
        "en_us": "Expenses",
        "it_it": "Spese",
      };

  String get i18n => localize(this, _translations);
}
