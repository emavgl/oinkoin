import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';

class MyI18n {
  static TranslationsByLocale translations = Translations.byLocale("en_US");

  static Future<void> loadTranslations() async {
    translations += await JSONImporter().fromAssetDirectory("assets/locales");
  }

  static void replaceTranslations(String replaceFrom, String replaceTo) {
    var wordTranslations = translations.translations;
    for (var wordTranslation in wordTranslations.values) {
      wordTranslation[replaceFrom] = wordTranslation[replaceTo]!;
    }
  }
}

extension Localization on String {
  String get i18n => localize(this, MyI18n.translations);
  String plural(value) => localizePlural(value, this, MyI18n.translations);
  String fill(List<Object> params) => localizeFill(this, params);
}