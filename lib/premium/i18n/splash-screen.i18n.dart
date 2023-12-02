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
        "en_us": "Filter records by year or custom date range",
        "it_it": "Filtra per anno o per date personalizzate",
      } +
      {
        "en_us": "Full category icon pack and color picker",
        "it_it": "Pack completo di icone e colori",
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
        "en_us": "DOWNLOAD IT NOW!",
        "it_it": "SCARICALA ADESSO!",
      } +
      {
        "en_us": "Add recurrent expenses",
        "it_it": "Aggiungi spese ricorrenti",
      };
  String get i18n => localize(this, _translations);
}
