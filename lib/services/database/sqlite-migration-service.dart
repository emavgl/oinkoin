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
              recurrence_id TEXT,
              wallet_id   INTEGER,
              transfer_wallet_id INTEGER,
              transfer_value REAL,
              profile_id  INTEGER
          );
      """;
    batch.execute(query);
  }

  static void _createWalletsTable(Batch batch) {
    String query = """
      CREATE TABLE IF NOT EXISTS wallets (
              id            INTEGER PRIMARY KEY AUTOINCREMENT,
              name          TEXT,
              color         TEXT,
              icon          INTEGER,
              icon_emoji    TEXT,
              initial_amount REAL DEFAULT 0,
              is_archived   INTEGER DEFAULT 0,
              is_default    INTEGER DEFAULT 0,
              is_predefined INTEGER DEFAULT 0,
              sort_order    INTEGER DEFAULT 0,
              currency      TEXT,
              profile_id    INTEGER
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

  static void _createProfilesTable(Batch batch) {
    String query = """
        CREATE TABLE IF NOT EXISTS profiles (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            name      TEXT NOT NULL,
            is_default INTEGER DEFAULT 0,
            color     TEXT
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
                end_date INTEGER,
                wallet_id INTEGER,
                transfer_wallet_id INTEGER,
                transfer_value REAL,
                profile_id INTEGER
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
      _logger.warning(
          'Alter table failed (expected for existing columns): ${e.toString()}');
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
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN end_date INTEGER;");
  }

  static Future<void> _migrateTo18(Database db) async {
    // Step 1: Create wallets table
    var batch = db.batch();
    _createWalletsTable(batch);
    await batch.commit();

    // Step 2: Add wallet_id column to records
    await safeAlterTable(
        db, "ALTER TABLE records ADD COLUMN wallet_id INTEGER;");

    // Step 3: Insert default wallet and get its id
    int defaultWalletId = await db.rawInsert(
      "INSERT INTO wallets (name, is_default, sort_order) VALUES (?, 1, 0)",
      ["Default Wallet".i18n],
    );

    // Step 4: Backfill all existing records with the default wallet id
    await db.rawUpdate(
      "UPDATE records SET wallet_id = ?",
      [defaultWalletId],
    );
  }

  static Future<void> _migrateTo19(Database db) async {
    await safeAlterTable(
        db, "ALTER TABLE records ADD COLUMN transfer_wallet_id INTEGER;");
  }

  static Future<void> _migrateTo20(Database db) async {
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN wallet_id INTEGER;");
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN transfer_wallet_id INTEGER;");
    // Backfill existing patterns with the default wallet (created in v18)
    await _backfillPatternsWithDefaultWallet(db);
  }

  static Future<void> _migrateTo21(Database db) async {
    await safeAlterTable(db, "ALTER TABLE wallets ADD COLUMN currency TEXT;");
  }

  static Future<void> _migrateTo22(Database db) async {
    // Backfill any recurrent patterns still missing a wallet_id
    // (covers users who ran v20 before the backfill was added)
    await _backfillPatternsWithDefaultWallet(db);
  }

  static Future<void> _backfillPatternsWithDefaultWallet(Database db) async {
    final rows = await db
        .rawQuery("SELECT id FROM wallets WHERE is_default = 1 LIMIT 1");
    if (rows.isEmpty) return;
    final defaultWalletId = rows.first['id'] as int;
    await db.rawUpdate(
        "UPDATE recurrent_record_patterns SET wallet_id = ? WHERE wallet_id IS NULL",
        [defaultWalletId]);
  }

  static Future<void> _migrateTo24(Database db) async {
    await safeAlterTable(
        db, "ALTER TABLE records ADD COLUMN transfer_value REAL;");
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN transfer_value REAL;");
  }

  static Future<void> _migrateTo25(Database db) async {
    // Step 1: Add is_predefined column (existing databases don't have it yet)
    await safeAlterTable(
        db, "ALTER TABLE wallets ADD COLUMN is_predefined INTEGER DEFAULT 0;");
    // Step 2: Reset all wallets to no default or predefined
    await db.rawUpdate("UPDATE wallets SET is_default = 0, is_predefined = 0");
    // Step 3: Mark 'Default Wallet' as both system default and predefined
    await db.rawUpdate(
        "UPDATE wallets SET is_default = 1, is_predefined = 1 WHERE name = 'Default Wallet'");
  }

  static Future<void> _migrateTo26(Database db) async {
    // The "Set as predefined" feature was mistakenly calling
    // setDefaultWallet() instead of setPredefinedWallet(), causing the
    // system default to be moved away from the original Default Wallet.
    // This migration restores the correct default.

    // Find the original Default Wallet by name or fallback to oldest wallet
    final localizedDefault = "Default Wallet".i18n;
    var defaultWalletId = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT id FROM wallets WHERE name = ?", [localizedDefault]));
    defaultWalletId ??= Sqflite.firstIntValue(await db.rawQuery(
        "SELECT id FROM wallets WHERE name = 'Default Wallet'"));
    defaultWalletId ??= Sqflite.firstIntValue(await db.rawQuery(
        "SELECT id FROM wallets ORDER BY id ASC LIMIT 1"));

    // Reset is_default on all wallets, then set the correct one
    await db.rawUpdate("UPDATE wallets SET is_default = 0");
    if (defaultWalletId != null) {
      await db.rawUpdate(
          "UPDATE wallets SET is_default = 1 WHERE id = ?", [defaultWalletId]);
    }

    _logger.info(
        'Migration v26: restored is_default to wallet ID $defaultWalletId');
  }

  static Future<void> _migrateTo23(Database db) async {
    // Step 1: Create profiles table
    var batch = db.batch();
    _createProfilesTable(batch);
    await batch.commit();

    // Step 2: Insert Default Profile and get its id
    final defaultProfileId = await db.rawInsert(
      "INSERT INTO profiles (name, is_default) VALUES (?, 1)",
      ["Default Profile".i18n],
    );

    // Step 3: Add color column to profiles (for databases created before this column existed)
    await safeAlterTable(db, "ALTER TABLE profiles ADD COLUMN color TEXT;");

    // Step 4: Add profile_id column to the three profile-scoped tables
    await safeAlterTable(
        db, "ALTER TABLE records ADD COLUMN profile_id INTEGER;");
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN profile_id INTEGER;");
    await safeAlterTable(
        db, "ALTER TABLE wallets ADD COLUMN profile_id INTEGER;");

    // Step 5: Backfill all existing rows with the Default Profile id
    await db.rawUpdate("UPDATE records SET profile_id = ?", [defaultProfileId]);
    await db.rawUpdate("UPDATE recurrent_record_patterns SET profile_id = ?",
        [defaultProfileId]);
    await db.rawUpdate("UPDATE wallets SET profile_id = ?", [defaultProfileId]);
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
    18: SqliteMigrationService._migrateTo18,
    19: SqliteMigrationService._migrateTo19,
    20: SqliteMigrationService._migrateTo20,
    21: SqliteMigrationService._migrateTo21,
    22: SqliteMigrationService._migrateTo22,
    23: SqliteMigrationService._migrateTo23,
    24: SqliteMigrationService._migrateTo24,
    25: SqliteMigrationService._migrateTo25,
    26: SqliteMigrationService._migrateTo26,
  };

  // Public Methods
  static Future<void> onUpgrade(
      Database db, int oldVersion, int newVersion) async {
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

  static Future<void> onCreate(Database db, int version) async {
    _logger.info('Creating new database (version $version)');
    var batch = db.batch();

    // Create Tables
    _createCategoriesTable(batch);
    _createRecordsTable(batch);
    _createRecordsTagsTable(batch);
    _createRecurrentRecordPatternsTable(batch);
    _createWalletsTable(batch);
    _createProfilesTable(batch);

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

    // Insert Default Profile (need its id for wallet)
    final defaultProfileId = await db.rawInsert(
      "INSERT INTO profiles (name, is_default) VALUES (?, 1)",
      ["Default Profile".i18n],
    );

    // Insert Default Wallet with profile_id
    await db.rawInsert(
      "INSERT INTO wallets (name, is_default, sort_order, profile_id) VALUES (?, 1, 0, ?)",
      ["Default Wallet".i18n, defaultProfileId],
    );

    _logger.info('Database created successfully');
  }
}
