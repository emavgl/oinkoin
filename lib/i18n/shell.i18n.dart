import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Home",
        "it_it": "Movimenti",
        "es_es": "Principal",
        "fr_fr": "Principal",
        "de_de": "TODO",
      } +
      {
        "en_us": "Categories",
        "it_it": "Categorie",
        "es_es": "Categorias",
        "fr_fr": "Catégories",
        "de_de": "TODO",
      } +
      {
        "en_us": "Settings",
        "it_it": "Impostazioni",
        "es_es": "Configuraciones",
        "fr_fr": "Paramètres",
        "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
