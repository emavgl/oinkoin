import 'database/database-interface.dart';
import 'database/sqlite-database.dart';

class ServiceConfig {

  /// ServiceConfig is a class that contains all the services
  /// used in different parts of the applications.

  static final DatabaseInterface database = SqliteDatabase.instance;
}
