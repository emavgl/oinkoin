import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +

      {
        "en_us": "No categories yet.",
        "it_it": "Nessuna categoria da visualizzare.",
      };

  String get i18n => localize(this, _translations);
}
