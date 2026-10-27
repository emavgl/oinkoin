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
              id          TEXT PRIMARY KEY NOT NULL DEFAULT ($_uuidV4Sql),
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
              is_hidden     INTEGER DEFAULT 0,
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
           record_id TEXT NOT NULL,
           tag_name TEXT NOT NULL,
           PRIMARY KEY (record_id, tag_name)
        );
      """;
    batch.execute(query);
  }

  static void _createBudgetsTable(Batch batch) {
    String query = """
      CREATE TABLE IF NOT EXISTS budgets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              target_amount REAL NOT NULL,
              budget_type INTEGER NOT NULL,
              start_date INTEGER NOT NULL,
              end_date INTEGER,
              recurrent_period INTEGER,
              custom_interval_value INTEGER,
              custom_interval_unit INTEGER,
              category_names TEXT NOT NULL DEFAULT '[]',
              tags TEXT NOT NULL DEFAULT '[]',
              wallet_ids TEXT NOT NULL DEFAULT '[]',
              category_tag_or_logic INTEGER NOT NULL DEFAULT 1,
              tag_or_logic INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0,
              profile_id INTEGER,
              timezone TEXT
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
            color     TEXT,
            sort_order INTEGER DEFAULT 0
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
                profile_id INTEGER,
                custom_interval_value INTEGER,
                custom_interval_unit INTEGER
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

  static void _createAllTriggers(Batch batch) {
    _createAddRecordTrigger(batch);
    _createUpdateRecordTrigger(batch);
    _createDeleteRecordTrigger(batch);
    _createDeleteRecordTagsTrigger(batch);
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

  static Future<void> _migrateTo27(Database db) async {
    // Assign orphaned rows (profile_id IS NULL) in all profile-scoped tables
    // to the default profile. These rows were created with a bug that skipped
    // setting profile_id even after the profiles migration had already run.
    final defaultProfileId = Sqflite.firstIntValue(
        await db.rawQuery("SELECT id FROM profiles WHERE is_default = 1"));
    if (defaultProfileId != null) {
      await db.rawUpdate(
          "UPDATE records SET profile_id = ? WHERE profile_id IS NULL",
          [defaultProfileId]);
      await db.rawUpdate(
          "UPDATE recurrent_record_patterns SET profile_id = ? WHERE profile_id IS NULL",
          [defaultProfileId]);
      await db.rawUpdate(
          "UPDATE wallets SET profile_id = ? WHERE profile_id IS NULL",
          [defaultProfileId]);
      _logger.info(
          'Migration v27: assigned orphaned rows to default profile $defaultProfileId');
    }
  }

  static Future<void> _migrateTo28(Database db) async {
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN custom_interval_value INTEGER;");
    await safeAlterTable(db,
        "ALTER TABLE recurrent_record_patterns ADD COLUMN custom_interval_unit INTEGER;");
  }

  static Future<void> _migrateTo29(Database db) async {
    final batch = db.batch();
    _createBudgetsTable(batch);
    await batch.commit();
  }

  static Future<void> _migrateTo30(Database db) async {
    await safeAlterTable(
        db, "ALTER TABLE budgets ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;");
  }

  static Future<void> _migrateTo31(Database db) async {
    await safeAlterTable(
        db, "ALTER TABLE budgets ADD COLUMN wallet_ids TEXT NOT NULL DEFAULT '[]';");
  }

  static Future<void> _migrateTo32(Database db) async {
    await safeAlterTable(
        db, "ALTER TABLE profiles ADD COLUMN sort_order INTEGER DEFAULT 0;");
  }

  static Future<void> _migrateTo33(Database db) async {
    await safeAlterTable(
        db, "ALTER TABLE wallets ADD COLUMN is_hidden INTEGER DEFAULT 0;");
  }

  /// Columns of `records` copied when the table is rebuilt.
  static const String _recordColumns =
      'datetime, timezone, value, title, description, category_name, '
      'category_type, recurrence_id, wallet_id, transfer_wallet_id, '
      'transfer_value, profile_id';

  /// SQL expression generating a random uuid v4. Used to assign ids in bulk
  /// during migrations; the application itself uses `Uuid().v4()`.
  static const String _uuidV4Sql = "lower(hex(randomblob(4))) || '-' || "
      "lower(hex(randomblob(2))) || '-4' || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "substr('89ab', abs(random()) % 4 + 1, 1) || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "lower(hex(randomblob(6)))";

  /// Type of the `id` column of `records`, or null when the table is missing.
  static Future<String?> _recordsIdColumnType(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(records)');
    for (final row in rows) {
      if (row['name'] == 'id') {
        return (row['type'] as String?)?.toUpperCase();
      }
    }
    return null;
  }

  static Future<int> _countTableRows(Database db, String table) async {
    final result =
        await db.rawQuery('SELECT COUNT(*) AS occurrences FROM $table');
    return (result.first['occurrences'] as int?) ?? 0;
  }

  /// Number of tag associations that reference an existing record.
  static Future<int> _countAttachedTags(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS occurrences '
        'FROM records_tags rt '
        'WHERE EXISTS (SELECT 1 FROM records r WHERE r.id = rt.record_id)');
    return (result.first['occurrences'] as int?) ?? 0;
  }

  /// Rebuilds `records` and `records_tags` with the given id representation.
  /// Rows are copied in creation order (ascending id when converting to uuids,
  /// ascending new integer id when converting back), so the `rowid` sequence of
  /// the rebuilt table - used as creation order, see `SqliteDatabase` - keeps
  /// matching the original insertion order.
  static Future<void> _rebuildRecordsWithIds(
    Database db, {
    required bool uuidIds,
  }) async {
    final recordCount = await _countTableRows(db, 'records');
    // Only associations that actually point at a record are copied, so orphaned
    // rows (possible in databases written by older versions) must not make the
    // verification below fail.
    final tagCount = await _countAttachedTags(db);

    await db.execute('DROP TABLE IF EXISTS records_id_map');
    await db.execute(uuidIds
        // old integer id -> new uuid
        ? 'CREATE TEMP TABLE records_id_map ('
            'old_id INTEGER PRIMARY KEY, new_id TEXT NOT NULL)'
        // old uuid -> new integer id, assigned in rowid (creation) order
        : 'CREATE TEMP TABLE records_id_map ('
            'new_id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'old_id TEXT NOT NULL UNIQUE)');

    if (uuidIds) {
      await db.execute('INSERT INTO records_id_map (old_id, new_id) '
          'SELECT id, $_uuidV4Sql FROM records ORDER BY id');
    } else {
      await db.execute('INSERT INTO records_id_map (old_id) '
          'SELECT id FROM records ORDER BY rowid');
    }

    await db.execute(uuidIds
        ? 'CREATE TABLE records_new '
            '(id TEXT PRIMARY KEY NOT NULL DEFAULT ($_uuidV4Sql), '
            '$_recordColumns)'
        : 'CREATE TABLE records_new (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            '$_recordColumns)');
    await db.execute(
      'INSERT INTO records_new (id, $_recordColumns) '
      'SELECT m.new_id, r.$_recordColumns '
      'FROM records r JOIN records_id_map m ON m.old_id = r.id '
      '${uuidIds ? 'ORDER BY r.id' : 'ORDER BY m.new_id'}',
    );

    await db.execute(uuidIds
        ? 'CREATE TABLE records_tags_new ('
            'record_id TEXT NOT NULL, tag_name TEXT NOT NULL, '
            'PRIMARY KEY (record_id, tag_name))'
        : 'CREATE TABLE records_tags_new ('
            'record_id INTEGER NOT NULL, tag_name TEXT NOT NULL, '
            'PRIMARY KEY (record_id, tag_name))');
    await db.execute('INSERT INTO records_tags_new (record_id, tag_name) '
        'SELECT m.new_id, rt.tag_name FROM records_tags rt '
        'JOIN records_id_map m ON m.old_id = rt.record_id');

    await db.execute('DROP TABLE records');
    await db.execute('ALTER TABLE records_new RENAME TO records');
    await db.execute('DROP TABLE records_tags');
    await db.execute('ALTER TABLE records_tags_new RENAME TO records_tags');

    var batch = db.batch();
    _createAllTriggers(batch);
    await batch.commit(noResult: true);

    // The rebuild must be lossless: abort (rolling back the enclosing
    // transaction) instead of leaving the user with missing records or tags.
    final newRecordCount = await _countTableRows(db, 'records');
    final newTagCount = await _countAttachedTags(db);
    if (newRecordCount != recordCount || newTagCount != tagCount) {
      throw StateError('Record id rebuild lost data: '
          '$recordCount -> $newRecordCount records, '
          '$tagCount -> $newTagCount tag associations');
    }

    await db.execute('DROP TABLE records_id_map');
  }

  /// v34: record ids become uuids, so a record keeps its identity across
  /// backups and can be matched exactly on restore.
  static Future<void> _migrateTo34(Database db) async {
    // Idempotent on purpose: opening a database with an older version resets
    // `user_version`, so this migration can run again on a database that has
    // already been converted.
    if (await _recordsIdColumnType(db) == 'TEXT') {
      _logger.info('Records already use uuid ids, skipping migration to 34');
      return;
    }
    _logger.info('Migrating record ids to uuids');
    await _rebuildRecordsWithIds(db, uuidIds: true);
    _logger.info('Record ids migrated to uuids');
  }

  /// Converts a uuid database back to integer record ids, so that a build that
  /// still expects integer ids can open it. Shipped one release before the uuid
  /// migration, which is what makes the downgrade possible at all.
  static Future<void> _downgradeFrom34(Database db) async {
    if (await _recordsIdColumnType(db) != 'TEXT') {
      _logger.info('Records already use integer ids, skipping downgrade from 34');
      return;
    }
    _logger.info('Converting record ids back to integers');
    await _rebuildRecordsWithIds(db, uuidIds: false);
    _logger.info('Record ids converted back to integers');
  }

  static Future<void> onDowngrade(
      Database db, int oldVersion, int newVersion) async {
    _logger.info('Downgrading database from version $oldVersion to $newVersion');
    if (oldVersion >= 34 && newVersion < 34) {
      await _downgradeFrom34(db);
    }
    _logger.info('Database downgrade completed to version $newVersion');
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
    27: SqliteMigrationService._migrateTo27,
    28: SqliteMigrationService._migrateTo28,
    29: SqliteMigrationService._migrateTo29,
    30: SqliteMigrationService._migrateTo30,
    31: SqliteMigrationService._migrateTo31,
    32: SqliteMigrationService._migrateTo32,
    33: SqliteMigrationService._migrateTo33,
    34: SqliteMigrationService._migrateTo34,
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
    _createBudgetsTable(batch);

    // Create Triggers
    _createAllTriggers(batch);

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
