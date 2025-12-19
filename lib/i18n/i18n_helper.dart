import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

abstract class Importer {
  String get _extension;

  Map<String, String> _load(String source);

  Future<Map<String, Map<String, String>>> fromAssetFile(
      String language, String fileName) async {
    return {language: _load(await rootBundle.loadString(fileName))};
  }

  Future<Map<String, Map<String, String>>> fromAssetDirectory(
      String dir) async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();

    Map<String, Map<String, String>> translations = HashMap();

    for (String path in assets) {
      if (!path.startsWith(dir)) continue;
      var fileName = path.split("/").last;
      if (!fileName.endsWith(_extension)) {
        print("➜ Ignoring file $path with unexpected file type "
            "(expected: $_extension).");
        continue;
      }
      var languageCode = fileName.split(".")[0];
      translations.addAll(await fromAssetFile(languageCode, path));
    }

    return translations;
  }

  Future<Map<String, Map<String, String>>> fromString(
      String language, String source) async {
    return {language: _load(source)};
  }
}

class JSONImporter extends Importer {
  @override
  String get _extension => ".json";

  @override
  Map<String, String> _load(String source) {
    return Map<String, String>.from(json.decode(source));
  }
}