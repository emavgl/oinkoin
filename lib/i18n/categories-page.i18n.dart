import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +

      {
        "en_us": " Delete",
        "it_it": " Elimina",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "DELETE",
        "it_it": "ELIMINA",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Confirm",
        "it_it": "Conferma",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "CANCEL",
        "it_it": "CANCELLA",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Are you sure you wish to delete this category?",
        "it_it": "Sei sicuro di voler eliminare questa categoria?",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Deleted category: ",
        "it_it": "Categoria eliminata: ",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "UNDO",
        "it_it": "INDIETRO",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
