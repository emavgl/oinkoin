import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/i18n.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/category-type.dart';
import '../../models/category.dart';
import '../logger.dart';

class SqliteMigrationService {

  static final _logger = Logger.withClass(SqliteMigrationService);

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
            icon_emoji TEXT,
            PRIMARY KEY (name, category_type)
        );
        """;
    batch.execute(query);
  }

  static void _createRecordsTable(Batch batch) {
    String query = """
      CREATE TABLE IF NOT EXISTS records (
              id          INTEGER  PRIMARY KEY AUTOINCREMENT,
              datetime    INTEGER,
              timezone     TEXT,
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
           record_id INTEGER NOT NULL,
           tag_name TEXT NOT NULL,
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
                timezone     TEXT,
                value       REAL,
                title       TEXT,
                description TEXT,
                category_name TEXT,
                category_type INTEGER,
                last_update INTEGER,
                recurrent_period INTEGER,
                recurrence_id TEXT,
                date_str TEXT,
                tags TEXT,
                end_date INTEGER
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

  static void _createDeleteRecordTagsTrigger(Batch batch) {
    String triggerQuery = """
      CREATE TRIGGER IF NOT EXISTS delete_record_tags
      AFTER DELETE ON records
      FOR EACH ROW
      BEGIN
          DELETE FROM records_tags WHERE record_id = OLD.id;
      END;
    """;
    batch.execute(triggerQuery);
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

  static Future<void> safeAlterTable(
      Database db, String alterTableQuery) async {
    try {
      await db.execute(alterTableQuery);
      _logger.debug('Alter table succeeded');
    } on DatabaseException catch (e) {
      // This block specifically handles DatabaseException
      _logger.warning('Alter table failed (expected for existing columns): ${e.toString()}');
    } catch (e, st) {
      // This block is a generic catch-all for any other exception types
      _logger.handle(e, st, 'Unexpected error in alter table');
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

  static void _migrateTo9(Database db) async {
    safeAlterTable(db, "ALTER TABLE categories ADD COLUMN icon_emoji TEXT;");
  }

  static void _migrateTo10(Database db) async {
    // Schema migration
    await safeAlterTable(db, "ALTER TABLE records ADD COLUMN timezone TEXT;");
    await safeAlterTable(
        db, "ALTER TABLE recurrent_record_patterns ADD COLUMN timezone TEXT;");
  }

  static void skip(Database db) async {
    // skip, wrong version
  }

  static void _migrateTo13(Database db) async {
    String createRecordsTagTable = """
            CREATE TABLE IF NOT EXISTS records_tags (
               record_id INTEGER,
               tag_name TEXT,
               PRIMARY KEY (record_id, tag_name)
            );
        """;
    await db.execute(createRecordsTagTable);

    // Add tags to recurrent_record_patterns
    await safeAlterTable(
        db, "ALTER TABLE recurrent_record_patterns ADD COLUMN tags TEXT;");

    // Add trigger to delete associated tags when a record is deleted
    String deleteRecordTagsTriggerQuery = """
      CREATE TRIGGER IF NOT EXISTS delete_record_tags
      AFTER DELETE ON records
      FOR EACH ROW
      BEGIN
          DELETE FROM records_tags WHERE record_id = OLD.id;
      END;
    """;
    await db.execute(deleteRecordTagsTriggerQuery);
  }

  static Future<void> _migrateTo16(Database db) async {
    // Step 1: Create a new table with the NOT NULL constraint
    String createNewRecordsTagsTable = """
      CREATE TABLE IF NOT EXISTS new_records_tags (
         record_id INTEGER NOT NULL,
         tag_name TEXT NOT NULL,
         PRIMARY KEY (record_id, tag_name)
      );
    """;
    await db.execute(createNewRecordsTagsTable);

    // Step 2: Copy data from the old table to the new table
    String copyDataQuery = """
      INSERT INTO new_records_tags (record_id, tag_name)
      SELECT record_id, tag_name FROM records_tags
      WHERE record_id IS NOT NULL;
    """;
    await db.execute(copyDataQuery);

    // Step 3: Drop the old table
    String dropOldTableQuery = "DROP TABLE IF EXISTS records_tags;";
    await db.execute(dropOldTableQuery);

    // Step 4: Rename the new table to the original table name
    String renameTableQuery =
        "ALTER TABLE new_records_tags RENAME TO records_tags;";
    await db.execute(renameTableQuery);

    // Step 5: Recreate triggers and indexes for records_tags table if needed
    // Recreate the delete_record_tags trigger using the existing function
    var batch = db.batch();
    _createDeleteRecordTagsTrigger(batch);
    await batch.commit();
  }

  static Future<void> _migrateTo17(Database db) async {
    // Add end_date column to recurrent_record_patterns
    await safeAlterTable(
        db, "ALTER TABLE recurrent_record_patterns ADD COLUMN end_date INTEGER;");
  }

  static Map<int, Function(Database)?> migrationFunctions = {
    6: SqliteMigrationService._migrateTo6,
    7: SqliteMigrationService._migrateTo7,
    8: SqliteMigrationService._migrateTo8,
    9: SqliteMigrationService._migrateTo9,
    10: SqliteMigrationService._migrateTo10,
    11: SqliteMigrationService.skip,
    12: SqliteMigrationService.skip,
    13: SqliteMigrationService._migrateTo13,
    15: SqliteMigrationService._migrateTo13,
    16: SqliteMigrationService._migrateTo16,
    17: SqliteMigrationService._migrateTo17,
  };

  // Public Methods
  static void onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.info('Upgrading database from version $oldVersion to $newVersion');
    for (int i = oldVersion + 1; i <= newVersion; i++) {
      if (migrationFunctions.containsKey(i)) {
        var migrationFunction = migrationFunctions[i];
        if (migrationFunction != null) {
          _logger.debug('Running migration to version $i');
          await migrationFunction.call(db);
        }
      }
    }
    _logger.info('Database upgrade completed to version $newVersion');
  }

  static void onCreate(Database db, int version) async {
    _logger.info('Creating new database (version $version)');
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
    _createDeleteRecordTagsTrigger(batch);

    // Insert Default Categories
    List<Category> defaultCategories = getDefaultCategories();
    _logger.debug('Inserting ${defaultCategories.length} default categories');
    for (var defaultCategory in defaultCategories) {
      batch.insert("categories", defaultCategory.toMap());
    }

    await batch.commit();
    _logger.info('Database created successfully');
  }
}
