import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/i18n.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/category-type.dart';
import '../../models/category.dart';

class SqliteMigrationService {
  // SQL Queries
  static void _createCategoriesTable(Batch batch) {
    String query = """
        CREATE TABLE IF NOT EXISTS categories (
            name  TEXT,
            color TEXT,
            icon INTEGER,
            category_type INTEGER,
            last_used INTEGER,
            record_count INTEGER DEFAULT 0,
            is_archived INTEGER DEFAULT 0,
            sort_order INTEGER DEFAULT 0,
            PRIMARY KEY (name, category_type)
        );
        """;
    batch.execute(query);
  }

  static void _createRecordsTable(Batch batch) {
    String query = """
        CREATE TABLE IF NOT EXISTS  records (
                id          INTEGER  PRIMARY KEY AUTOINCREMENT,
                datetime    INTEGER,
                value       REAL,
                title       TEXT,
                description TEXT,
                category_name TEXT,
                category_type INTEGER,
                recurrence_id TEXT
            );
        """;
    batch.execute(query);
  }

  static void _createRecordsTagsTable(Batch batch) {
    String query = """
            CREATE TABLE IF NOT EXISTS records_tags (
               record_id INTEGER,
               tag_name TEXT,
               PRIMARY KEY (record_id, tag_name)
            );
        """;
    batch.execute(query);
  }

  static void _createRecurrentRecordPatternsTable(Batch batch) {
    String query = """
        CREATE TABLE IF NOT EXISTS  recurrent_record_patterns (
                id          TEXT  PRIMARY KEY,
                datetime    INTEGER,
                value       REAL,
                title       TEXT,
                description TEXT,
                category_name TEXT,
                category_type INTEGER,
                last_update INTEGER,
                recurrent_period INTEGER,
                recurrence_id TEXT
            );
        """;
    batch.execute(query);
  }

  static void _createAddRecordTrigger(Batch batch) {
    batch.execute("DROP TRIGGER IF EXISTS update_category_usage;");
    String addRecordTriggerQuery = """
      CREATE TRIGGER update_category_usage
      AFTER INSERT ON records
      FOR EACH ROW
      BEGIN
          UPDATE categories
          SET 
              record_count = record_count + 1,
              last_used = strftime('%s', 'now') * 1000 -- Convert seconds to milliseconds
          WHERE
              name = NEW.category_name AND
              category_type = NEW.category_type;
      END;
    """;
    batch.execute(addRecordTriggerQuery);
  }

  static void _createUpdateRecordTrigger(Batch batch) {
    batch.execute("DROP TRIGGER IF EXISTS update_category_usage_on_update;");
    String addRecordTriggerQuery = """
      CREATE TRIGGER update_category_usage_on_update
      AFTER UPDATE ON records
      FOR EACH ROW
      BEGIN
          -- Increment the record count and update the last_used timestamp for the new category
          UPDATE categories
          SET 
              record_count = record_count + 1,
              last_used = strftime('%s', 'now') * 1000 -- Convert seconds to milliseconds
          WHERE
              name = NEW.category_name AND
              category_type = NEW.category_type;
      
          -- Decrement the record count for the old category only if the category has changed
          UPDATE categories
          SET
              record_count = record_count - 1
          WHERE
              name = OLD.category_name AND
              category_type = OLD.category_type
              AND (NEW.category_name != OLD.category_name OR NEW.category_type != OLD.category_type);
      END;
    """;
    batch.execute(addRecordTriggerQuery);
  }

  static void _createDeleteRecordTrigger(Batch batch) {
    batch.execute("DROP TRIGGER IF EXISTS update_category_usage_on_delete;");
    String addRecordTriggerQuery = """
      CREATE TRIGGER update_category_usage_on_delete
      AFTER DELETE ON records
      FOR EACH ROW
      BEGIN
          UPDATE categories
          SET 
              record_count = record_count - 1
          WHERE
              name = OLD.category_name AND
              category_type = OLD.category_type;
      END;
    """;
    batch.execute(addRecordTriggerQuery);
  }

  // Default Data
  static List<Category> getDefaultCategories() {
    List<Category> defaultCategories = <Category>[];
    defaultCategories.add(new Category("House".i18n,
        color: Category.colors[0],
        iconCodePoint: FontAwesomeIcons.house.codePoint,
        categoryType: CategoryType.expense));
    defaultCategories.add(new Category("Transport".i18n,
        color: Category.colors[1],
        iconCodePoint: FontAwesomeIcons.bus.codePoint,
        categoryType: CategoryType.expense));
    defaultCategories.add(new Category("Food".i18n,
        color: Category.colors[2],
        iconCodePoint: FontAwesomeIcons.burger.codePoint,
        categoryType: CategoryType.expense));
    defaultCategories.add(new Category("Salary".i18n,
        color: Category.colors[3],
        iconCodePoint: FontAwesomeIcons.wallet.codePoint,
        categoryType: CategoryType.income));
    return defaultCategories;
  }

  static void safeAlterTable(Database db, String alterTableQuery) {
    try {
      db.execute(alterTableQuery);
    } catch (DatabaseException) {
      // so that this method is idempotent
    }
  }

  // Migration Functions
  static void _migrateTo6(Database db) async {
    var batch = db.batch();
    _createRecurrentRecordPatternsTable(batch);
    await batch.commit();
    // Ensure this column is added, if the table exists and the transaction
    // above is aborted
    try {
      safeAlterTable(db, "ALTER TABLE records ADD COLUMN recurrence_id TEXT;");
    } catch (DatabaseException) {
      // so that this method is idempotent
    }
  }

  static void _migrateTo7(Database db) async {
    safeAlterTable(db, "ALTER TABLE categories ADD COLUMN last_used INTEGER;");
    safeAlterTable(
        db, "ALTER TABLE categories ADD COLUMN is_archived INTEGER DEFAULT 0;");
    safeAlterTable(db,
        "ALTER TABLE categories ADD COLUMN record_count INTEGER DEFAULT 0;");

    var batch = db.batch();
    try {
      // Populate this column with rough estimation
      String updateLastUsedQuery = """
        UPDATE categories
        SET last_used = (
            SELECT MAX(datetime) 
            FROM records
            WHERE records.category_name = categories.name 
              AND records.category_type = categories.category_type
        );
      """;
      batch.execute(updateLastUsedQuery);

      // Populate record_count
      String updateRecordCount = """
        UPDATE categories
        SET record_count = (
            SELECT COUNT(*)
            FROM records
            WHERE records.category_name = categories.name
              AND records.category_type = categories.category_type
        );
      """;
      batch.execute(updateRecordCount);

      // Add Triggers
      _createAddRecordTrigger(batch);
      _createUpdateRecordTrigger(batch);
      _createDeleteRecordTrigger(batch);

      // Commit now the schema changes
      await batch.commit();
    } catch (DatabaseException) {
      // so that this method is idempotent
    }
  }

  static void _migrateTo8(Database db) async {
    safeAlterTable(
        db, "ALTER TABLE categories ADD COLUMN sort_order INTEGER DEFAULT 0;");
  }

  static Map<int, Function(Database)?> migrationFunctions = {
    6: SqliteMigrationService._migrateTo6,
    7: SqliteMigrationService._migrateTo7,
    8: SqliteMigrationService._migrateTo8
  };

  // Public Methods
  static void onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int i = oldVersion + 1; i <= newVersion; i++) {
      if (migrationFunctions.containsKey(i)) {
        var migrationFunction = migrationFunctions[i];
        if (migrationFunction != null) {
          await migrationFunction.call(db);
        }
      }
    }
  }

  static void onCreate(Database db, int version) async {
    var batch = db.batch();

    // Create Tables
    _createCategoriesTable(batch);
    _createRecordsTable(batch);
    _createRecordsTagsTable(batch);
    _createRecurrentRecordPatternsTable(batch);

    // Create Triggers
    _createAddRecordTrigger(batch);
    _createUpdateRecordTrigger(batch);
    _createDeleteRecordTrigger(batch);

    // Insert Default Categories
    List<Category> defaultCategories = getDefaultCategories();
    for (var defaultCategory in defaultCategories) {
      batch.insert("categories", defaultCategory.toMap());
    }

    await batch.commit();
  }
}
