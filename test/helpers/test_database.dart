import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common/sqflite.dart';

/// TestDatabaseHelper creates isolated in-memory database instances for testing.
/// Each test gets its own independent in-memory database, allowing parallel execution
/// without database locking issues.
class TestDatabaseHelper {
  /// Creates and sets up a new isolated in-memory database for testing
  /// Returns the created database instance
  static Future<Database> setupTestDatabase() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath, // Each call creates a new isolated in-memory database
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: SqliteDatabase.version,
        onCreate: SqliteMigrationService.onCreate,
        onUpgrade: SqliteMigrationService.onUpgrade,
        onDowngrade: SqliteMigrationService.onUpgrade,
      ),
    );

    // Set the database for the singleton instance to use
    SqliteDatabase.setDatabaseForTesting(db);

    return db;
  }
}
