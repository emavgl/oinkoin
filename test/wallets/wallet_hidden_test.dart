import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  test('Wallet defaults to visible (isHidden == false)', () {
    expect(Wallet('Cash').isHidden, false);
  });

  test('Wallet toMap/fromMap round-trips isHidden', () {
    final hidden = Wallet('Piggy', isHidden: true);
    final visible = Wallet('Cash');

    expect(hidden.toMap()['is_hidden'], 1);
    expect(visible.toMap()['is_hidden'], 0);
    expect(Wallet.fromMap(hidden.toMap()).isHidden, true);
    expect(Wallet.fromMap(visible.toMap()).isHidden, false);
  });

  test('fromMap treats a missing is_hidden column as visible', () {
    final map = Wallet('Legacy').toMap()..remove('is_hidden');
    expect(Wallet.fromMap(map).isHidden, false);
  });

  test('addWallet persists isHidden and updateWallet toggles it', () async {
    DatabaseInterface db = ServiceConfig.database;

    final id = await db.addWallet(Wallet('Savings', isHidden: true));
    expect((await db.getWalletById(id))!.isHidden, true);

    final wallet = (await db.getWalletById(id))!;
    wallet.isHidden = false;
    await db.updateWallet(id, wallet);
    expect((await db.getWalletById(id))!.isHidden, false);
  });

  test('getAllWallets keeps hidden and visible wallets distinct', () async {
    DatabaseInterface db = ServiceConfig.database;
    await db.addWallet(Wallet('Hidden one', isHidden: true));
    await db.addWallet(Wallet('Visible one'));

    final wallets = await db.getAllWallets();
    expect(wallets.where((w) => w.isHidden).map((w) => w.name),
        contains('Hidden one'));
    expect(wallets.where((w) => !w.isHidden).map((w) => w.name),
        contains('Visible one'));
  });

  test('migration 32 -> 33 adds is_hidden defaulting existing wallets to 0',
      () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 32,
      ),
    );

    // v32 wallets table, without the is_hidden column.
    await db.execute("""
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        color TEXT,
        icon INTEGER,
        initial_amount REAL,
        currency TEXT,
        is_default INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        icon_emoji TEXT
      );
    """);
    await db.insert('wallets', {'name': 'Existing', 'is_default': 0});

    await SqliteMigrationService.onUpgrade(db, 32, 33);

    final rows = await db.query('wallets');
    expect(rows.length, 1);
    expect(rows.first['is_hidden'], 0,
        reason: 'Wallets existing before v33 must stay visible');

    await db.close();
  });
}
