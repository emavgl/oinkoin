import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Unlock to access.",
        "it_it": "Sblocca per accedere.",
      };

  String get i18n => localize(this, _translations);
}
