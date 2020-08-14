import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/services/database/exceptions.dart';
import 'package:piggybank/services/service-config.dart';

import 'database/database-interface.dart';

class BackupService {
  /// BackupService contains the methods to create/restore backup file

  static final DatabaseInterface database = ServiceConfig.database;

  static Future<File> createJsonBackupFile({backupFileName: "backup"}) async {
    var records = await database.getAllRecords();
    var categories = await database.getAllCategories();
    var backup = Backup(categories, records);
    var backupJsonStr = jsonEncode(backup.toMap());
    final path = await getApplicationDocumentsDirectory();
    var backupJsonOnDisk = File(path.path + "/${backupFileName}.json");
    return await backupJsonOnDisk.writeAsString(backupJsonStr);
  }

  static Future<bool> importDataFromBackupFile(File inputFile) async {
    try {
      String fileContent = await inputFile.readAsString();
      var jsonMap = jsonDecode(fileContent);
      Backup backup = Backup.fromMap(jsonMap);
      for(var backupCategory in backup.categories) {
        try {
          await database.addCategory(backupCategory);
        } on ElementAlreadyExists {
          print("${backupCategory.name} already exists.");
        }
      }
      for(var backupRecord in backup.records) {
        if (await database.getMatchingRecord(backupRecord) == null){
          await database.addRecord(backupRecord);
        } else {
          print("${backupRecord.category.name} of value ${backupRecord
              .value} already exists.");
        }
      }
      return true;
    } catch (err) {
     return false;
    }
  }

}