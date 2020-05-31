import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Monday",
        "it_it": "Lunedì",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Tuesday",
        "it_it": "Martedì",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Wednesday",
        "it_it": "Mercoledì",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Thursday",
        "it_it": "Giovedì",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Friday",
        "it_it": "Venerdì",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Saturday",
        "it_it": "Sabato",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Sunday",
        "it_it": "Domenica",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }




      +





      {
        "en_us": "January",
        "it_it": "Gennaio",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "February",
        "it_it": "Febbraio",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "March",
        "it_it": "Marzo",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "April",
        "it_it": "Aprile",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "May",
        "it_it": "Maggio",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "June",
        "it_it": "Giugno",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "July",
        "it_it": "Luglio",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "August",
        "it_it": "Agosto",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "September",
        "it_it": "Settembre",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "October",
        "it_it": "Ottobre",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "November",
        "it_it": "Novembre",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      }
      +
      {
        "en_us": "December",
        "it_it": "Dicembre",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
