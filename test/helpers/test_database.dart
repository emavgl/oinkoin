import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common/sqflite_logger.dart';

/// TestDatabaseHelper creates isolated in-memory database instances for testing.
/// Each test gets its own independent in-memory database, allowing parallel execution
/// without database locking issues.
class TestDatabaseHelper {
  /// Creates and sets up a new isolated in-memory database for testing
  /// Returns the created database instance
  static Future<Database> setupTestDatabase() async {
    var factoryWithLogs = SqfliteDatabaseFactoryLogger(databaseFactory,
        options:
            SqfliteLoggerOptions(type: SqfliteDatabaseFactoryLoggerType.all));
    
    final db = await factoryWithLogs.openDatabase(
      inMemoryDatabasePath, // Each call creates a new isolated in-memory database
      options: OpenDatabaseOptions(
          version: SqliteDatabase.version,
          onCreate: SqliteMigrationService.onCreate,
          onUpgrade: SqliteMigrationService.onUpgrade,
          onDowngrade: SqliteMigrationService.onUpgrade),
    );
    
    // Set the database for the singleton instance to use
    SqliteDatabase.setDatabaseForTesting(db);
    
    return db;
  }
}
