import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Upgrade to Pro",
        "it_it": "Passa a Pro",
        "de_de": "Auf Pro-Version upgraden",
      } +
      {
        "en_us": 'Upgrade to',
        "it_it": "Passa a",
        "de_de": "Upgrade auf",
      } +
      {
        "en_us": 'Under Control Pro',
        "it_it": 'Under Control Pro',
        "de_de": 'Under Control Pro',
      } +
      {
        "en_us": "Filter records by year or custom date range",
        "it_it": "Filtra per anno o per date personalizzate",
        "de_de": "Einträge nach Jahr oder benutzerdefiniertem Datum filtern",

      } +
      {
        "en_us": "Full category icon pack and color picker",
        "it_it": "Pack completo di icone e colori",
        "de_de": "Vollständige Kategorie-Icons und Farbwähler",
      } +
      {
        "en_us": "Backup/Restore the application data",
        "it_it": "Backup/Ripristino dei dati",
        "de_de": "Sichern und Wiederherstellen der App-Daten",
      } +
      {
        "en_us": "Set budgets",
        "it_it": "Imposta dei budget",
        "de_de": "Setzen von Budgets",
      } +
      {
        "en_us": "DOWNLOAD IT NOW!",
        "it_it": "SCARICALA ADESSO!",
        "de_de": "JETZT HERUNTERLADEN!",
      } +
      {
        "en_us": "Add recurrent expenses",
        "it_it": "Aggiungi spese ricorrenti",
        "de_de": "Wiederkehrende Ausgaben hinzufügen",
      };
  String get i18n => localize(this, _translations);
}
