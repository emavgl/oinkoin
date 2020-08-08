import 'package:i18n_extension/i18n_extension.dart';

// check doc in records-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Send a feedback",
        "it_it": "Invia un feedback",
      } +
      {
        "en_us": "Clicking the button below you can send us a feedback email. Your feedback is very appreciated and will help us to grow!",
        "it_it": "Cliccando sul bottone in basso puoi inviarci un email con il tuo commento. Ogni feedback è importante e ci aiuta a crescere!",
      } +
      {
        "en_us": "Currency",
        "it_it": "Valuta",
      } +
      {
        "en_us": "Currency",
        "it_it": "Valuta",
      } +
      {
        "en_us": "Currency",
        "it_it": "Valuta",
      } +
      {
        "en_us": "Currency",
        "it_it": "Valuta",
      } +
      {
        "en_us": "Pay us a coffee",
        "it_it": "Donaci un caffè",
      };

  String get i18n => localize(this, _translations);
}
