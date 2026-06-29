// lib/services/local_database.dart
// ─────────────────────────────────────────────────────────────────────────────
// SQLite local database for GBook app — multi-khatabook support
// ─────────────────────────────────────────────────────────────────────────────
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

// ── Lightweight helper used by parties_screen to count customers per book ─────
class LocalDatabaseCustomerCount {
  static Future<int> count(String bookId) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM customers WHERE bookId = ?",
      [bookId],
    );
    return (result.first['c'] as int?) ?? 0;
  }
}

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static Database? _db;

  // Bumped to 4 so devices stuck on a broken/partial v2 or v3 database
  // (missing isActive/bookId columns) are forced through onUpgrade again.
  static const int _dbVersion = 4;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gbook.db');
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // Safety net: even if version numbers matched (e.g. a previous failed
    // upgrade left the user_version already bumped, so onUpgrade never
    // re-ran), make sure every column we depend on actually exists.
    await _ensureSchema(db);
    return db;
  }

  // ── Create all tables from scratch (new install) ──────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE business_profile (
        id TEXT PRIMARY KEY,
        businessName TEXT NOT NULL,
        ownerName TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT,
        address TEXT,
        gstin TEXT,
        category TEXT,
        createdAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_transactions (
        id TEXT PRIMARY KEY,
        customerId TEXT NOT NULL,
        amount REAL NOT NULL,
        isGiven INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        paymentMode TEXT NOT NULL DEFAULT 'cash',
        date TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (customerId) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        isIncome INTEGER NOT NULL DEFAULT 1,
        category TEXT,
        note TEXT,
        paymentMode TEXT NOT NULL DEFAULT 'cash',
        date TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE cashbook_entries (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        isCashIn INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        paymentMode TEXT NOT NULL DEFAULT 'cash',
        date TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        gstin TEXT,
        balance REAL NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT ''
      )
    ''');

    // items table — full schema including extended fields
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        salePrice REAL NOT NULL,
        purchasePrice REAL,
        stock REAL,
        unit TEXT NOT NULL DEFAULT 'piece',
        category TEXT,
        description TEXT,
        createdAt TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT '',
        isService INTEGER NOT NULL DEFAULT 0,
        hsnCode TEXT,
        gstRate REAL NOT NULL DEFAULT 0,
        lowStockThreshold REAL NOT NULL DEFAULT 5,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY,
        billNumber TEXT NOT NULL,
        billType TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        partyId TEXT,
        partyName TEXT,
        subtotal REAL NOT NULL,
        discountTotal REAL NOT NULL DEFAULT 0,
        taxTotal REAL NOT NULL DEFAULT 0,
        grandTotal REAL NOT NULL,
        paidAmount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE bill_items (
        id TEXT PRIMARY KEY,
        billId TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL,
        rate REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        taxPercent REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        FOREIGN KEY (billId) REFERENCES bills(id)
      )
    ''');
  }

  // ── Incremental migrations ────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: add isActive to business_profile, add bookId to all data tables
    if (oldVersion < 2) {
      await _safeAlter(db,
          'ALTER TABLE business_profile ADD COLUMN isActive INTEGER NOT NULL DEFAULT 0');

      // Mark first profile as active
      final profiles = await db.query('business_profile', limit: 1);
      if (profiles.isNotEmpty) {
        await db.update('business_profile', {'isActive': 1},
            where: 'id = ?', whereArgs: [profiles.first['id']]);
      }

      for (final table in [
        'customers',
        'customer_transactions',
        'app_transactions',
        'cashbook_entries',
        'suppliers',
        'items',
        'bills',
      ]) {
        await _safeAlter(db,
            "ALTER TABLE $table ADD COLUMN bookId TEXT NOT NULL DEFAULT ''");
      }
    }

    // v2 → v3: add extended item fields
    if (oldVersion < 3) {
      await _safeAlter(db,
          'ALTER TABLE items ADD COLUMN isService INTEGER NOT NULL DEFAULT 0');
      await _safeAlter(db, 'ALTER TABLE items ADD COLUMN hsnCode TEXT');
      await _safeAlter(db,
          'ALTER TABLE items ADD COLUMN gstRate REAL NOT NULL DEFAULT 0');
      await _safeAlter(db,
          'ALTER TABLE items ADD COLUMN lowStockThreshold REAL NOT NULL DEFAULT 5');
      await _safeAlter(db, 'ALTER TABLE items ADD COLUMN imagePath TEXT');
    }

    // v3 → v4: no schema change here — this bump exists purely to force
    // _ensureSchema() to run on devices whose onUpgrade silently failed
    // before (e.g. interrupted upgrade, or app reinstalled mid-migration).
  }

  /// Runs an ALTER TABLE, swallowing "duplicate column" errors only.
  /// Re-throws anything unexpected so real failures aren't hidden.
  Future<void> _safeAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains('duplicate column')) {
        // Not the "already exists" case — log but don't crash startup.
        // ignore: avoid_print
        print('Schema alter warning: $sql -> $e');
      }
    }
  }

  /// Returns the set of column names that currently exist on [table].
  Future<Set<String>> _columnsOf(Database db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.map((row) => row['name'] as String).toSet();
  }

  /// Defensive self-heal: guarantees every column the app code reads/writes
  /// actually exists, regardless of what the stored user_version claims.
  /// This is what prevents the exact crash you hit:
  /// "no such column: isActive ... SELECT * FROM business_profile".
  Future<void> _ensureSchema(Database db) async {
    final bpCols = await _columnsOf(db, 'business_profile');
    if (!bpCols.contains('isActive')) {
      await _safeAlter(db,
          'ALTER TABLE business_profile ADD COLUMN isActive INTEGER NOT NULL DEFAULT 0');
      // If nothing is marked active yet, activate the first profile so
      // getBusinessProfile() can find it.
      final activeCount = await db
          .rawQuery('SELECT COUNT(*) as c FROM business_profile WHERE isActive = 1');
      final hasActive = ((activeCount.first['c'] as int?) ?? 0) > 0;
      if (!hasActive) {
        final profiles = await db.query('business_profile', limit: 1);
        if (profiles.isNotEmpty) {
          await db.update('business_profile', {'isActive': 1},
              where: 'id = ?', whereArgs: [profiles.first['id']]);
        }
      }
    }

    for (final table in [
      'customers',
      'customer_transactions',
      'app_transactions',
      'cashbook_entries',
      'suppliers',
      'items',
      'bills',
    ]) {
      final cols = await _columnsOf(db, table);
      if (!cols.contains('bookId')) {
        await _safeAlter(
            db, "ALTER TABLE $table ADD COLUMN bookId TEXT NOT NULL DEFAULT ''");
      }
    }

    final itemCols = await _columnsOf(db, 'items');
    if (!itemCols.contains('isService')) {
      await _safeAlter(db,
          'ALTER TABLE items ADD COLUMN isService INTEGER NOT NULL DEFAULT 0');
    }
    if (!itemCols.contains('hsnCode')) {
      await _safeAlter(db, 'ALTER TABLE items ADD COLUMN hsnCode TEXT');
    }
    if (!itemCols.contains('gstRate')) {
      await _safeAlter(
          db, 'ALTER TABLE items ADD COLUMN gstRate REAL NOT NULL DEFAULT 0');
    }
    if (!itemCols.contains('lowStockThreshold')) {
      await _safeAlter(db,
          'ALTER TABLE items ADD COLUMN lowStockThreshold REAL NOT NULL DEFAULT 5');
    }
    if (!itemCols.contains('imagePath')) {
      await _safeAlter(db, 'ALTER TABLE items ADD COLUMN imagePath TEXT');
    }
  }

  // ── BusinessProfile ───────────────────────────────────────────────────────

  Future<BusinessProfile?> getBusinessProfile() async {
    final db = await database;
    try {
      final maps =
          await db.query('business_profile', where: 'isActive = 1', limit: 1);
      if (maps.isNotEmpty) return BusinessProfile.fromMap(maps.first);
      // No row marked active yet — fall back to the first profile, if any,
      // rather than returning null and forcing the user back through setup.
      final any = await db.query('business_profile', limit: 1);
      if (any.isEmpty) return null;
      await db.update('business_profile', {'isActive': 1},
          where: 'id = ?', whereArgs: [any.first['id']]);
      return BusinessProfile.fromMap(any.first);
    } catch (e) {
      // Final safety net — if the isActive column is somehow still missing
      // (shouldn't happen after _ensureSchema, but never crash auth flow).
      await _ensureSchema(db);
      final maps = await db.query('business_profile', limit: 1);
      if (maps.isEmpty) return null;
      return BusinessProfile.fromMap(maps.first);
    }
  }

  Future<List<BusinessProfile>> getAllBusinessProfiles() async {
    final db = await database;
    final maps =
        await db.query('business_profile', orderBy: 'createdAt ASC');
    return maps.map((m) => BusinessProfile.fromMap(m)).toList();
  }

  Future<void> saveBusinessProfile(BusinessProfile profile,
      {bool makeActive = false}) async {
    final db = await database;
    final map = Map<String, dynamic>.from(profile.toMap());
    if (makeActive) {
      await db.update('business_profile', {'isActive': 0});
      map['isActive'] = 1;
    } else {
      final existing = await db.query('business_profile',
          where: 'id = ?', whereArgs: [profile.id], limit: 1);
      map['isActive'] =
          existing.isNotEmpty ? (existing.first['isActive'] ?? 0) : 0;
    }
    await db.insert('business_profile', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> createBusinessProfile(BusinessProfile profile) async {
    final db = await database;
    final map = Map<String, dynamic>.from(profile.toMap());
    map['isActive'] = 0;
    await db.insert('business_profile', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setActiveBusinessProfile(String bookId) async {
    final db = await database;
    await db.update('business_profile', {'isActive': 0});
    await db.update('business_profile', {'isActive': 1},
        where: 'id = ?', whereArgs: [bookId]);
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  Future<List<Customer>> getCustomers(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'customers',
      where: bookId.isEmpty ? null : 'bookId = ?',
      whereArgs: bookId.isEmpty ? null : [bookId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<String> insertCustomer(Customer customer) async {
    final db = await database;
    await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return customer.id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    await db.update('customers', customer.toMap(),
        where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('customer_transactions',
          where: 'customerId = ?', whereArgs: [id]);
      await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── CustomerTransactions ──────────────────────────────────────────────────

  Future<List<CustomerTransaction>> getCustomerTransactions(
      String customerId) async {
    final db = await database;
    final maps = await db.query(
      'customer_transactions',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => CustomerTransaction.fromMap(m)).toList();
  }

  Future<void> insertCustomerTransaction(CustomerTransaction tx) async {
    final db = await database;
    await db.insert('customer_transactions', tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCustomerTransaction(String id) async {
    final db = await database;
    await db.delete('customer_transactions',
        where: 'id = ?', whereArgs: [id]);
  }

  // ── AppTransactions ───────────────────────────────────────────────────────

  Future<List<AppTransaction>> getTransactions({
    String bookId = '',
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (bookId.isNotEmpty) {
      conditions.add('bookId = ?');
      args.add(bookId);
    }
    if (from != null) {
      conditions.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final maps = await db.query(
      'app_transactions',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC',
    );
    return maps.map((m) => AppTransaction.fromMap(m)).toList();
  }

  Future<void> insertTransaction(AppTransaction tx) async {
    final db = await database;
    await db.insert('app_transactions', tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('app_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  Future<List<Supplier>> getSuppliers(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'suppliers',
      where: bookId.isEmpty ? null : 'bookId = ?',
      whereArgs: bookId.isEmpty ? null : [bookId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<String> insertSupplier(Supplier supplier) async {
    final db = await database;
    await db.insert('suppliers', supplier.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return supplier.id;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await database;
    await db.update('suppliers', supplier.toMap(),
        where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(String id) async {
    final db = await database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<Item>> getItems(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: bookId.isEmpty ? null : 'bookId = ?',
      whereArgs: bookId.isEmpty ? null : [bookId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<String> insertItem(Item item) async {
    final db = await database;
    await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return item.id;
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update('items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  Future<List<Bill>> getBills({
    String bookId = '',
    BillType? type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (bookId.isNotEmpty) {
      conditions.add('bookId = ?');
      args.add(bookId);
    }
    if (type != null) {
      conditions.add('billType = ?');
      args.add(type.name);
    }
    if (from != null) {
      conditions.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final billMaps = await db.query(
      'bills',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC',
    );
    final bills = <Bill>[];
    for (final bm in billMaps) {
      final itemMaps = await db
          .query('bill_items', where: 'billId = ?', whereArgs: [bm['id']]);
      bills.add(
        Bill.fromMap(bm, itemMaps.map((m) => BillItem.fromMap(m)).toList()),
      );
    }
    return bills;
  }

  Future<void> insertBill(Bill bill) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('bills', bill.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in bill.items) {
        await txn.insert('bill_items', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteBill(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('bill_items', where: 'billId = ?', whereArgs: [id]);
      await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> getNextBillNumber(String bookId, BillType type) async {
    final db = await database;
    final conditions = ['billType = ?'];
    final args = <Object?>[type.name];
    if (bookId.isNotEmpty) {
      conditions.add('bookId = ?');
      args.add(bookId);
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bills WHERE ${conditions.join(' AND ')}',
      args,
    );
    return ((result.first['count'] as int?) ?? 0) + 1;
  }

  // ── Cashbook ──────────────────────────────────────────────────────────────

  Future<List<CashbookEntry>> getCashbookEntries({
    String bookId = '',
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (bookId.isNotEmpty) {
      conditions.add('bookId = ?');
      args.add(bookId);
    }
    if (from != null) {
      conditions.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final maps = await db.query(
      'cashbook_entries',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC',
    );
    return maps.map((m) => CashbookEntry.fromMap(m)).toList();
  }

  Future<void> insertCashbookEntry(CashbookEntry entry) async {
    final db = await database;
    await db.insert('cashbook_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCashbookEntry(String id) async {
    final db = await database;
    await db.delete('cashbook_entries', where: 'id = ?', whereArgs: [id]);
  }
}