import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Upgrade to Pro",
        "it_it": "Passa a Pro",
      } +
      {
        "en_us": 'Upgrade to',
        "it_it": "Passa a",
      } +
      {
        "en_us": 'PiggyBank Pro',
        "it_it": 'PiggyBank Pro',
      } +
      {
        "en_us": "Filter records by year or custom date range",
        "it_it": "Filtra i movimenti per anno o personalizza il range delle date",
      } +
      {
        "en_us": "Full category icon pack and color picker",
        "it_it": "Pack completo di icone e colori per le categorie",
      } +
      {
        "en_us": "Backup/Restore the application data",
        "it_it": "Backup/Ripristino dei dati",
      } +
      {
        "en_us": "Set budgets",
        "it_it": "Imposta dei budget",
      } +
      {
        "en_us": "Add recurrent expenses",
        "it_it": "Aggiungi spese ricorrenti",
      };
  String get i18n => localize(this, _translations);
}
