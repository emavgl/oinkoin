import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';

class MyI18n {
  static TranslationsByLocale translations = Translations.byLocale("en");

  static Future<void> loadTranslations() async {
    translations +=
    await JSONImporter().fromAssetDirectory("assets/locales");
  }
}

extension Localization on String {
  String get i18n => localize(this, MyI18n.translations);
  String plural(value) => localizePlural(value, this, MyI18n.translations);
  String fill(List<Object> params) => localizeFill(this, params);
}