// lib/services/local_database.dart
// ─────────────────────────────────────────────────────────────────────────────
// SQLite local database for GBook app — multi-khatabook support + Staff
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

  // Bumped to 7: adds `staff` and `staff_attendance` tables for the Staff
  // Management feature (add staff, permissions, daily attendance, salary due).
  static const int _dbVersion = 7;

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
    // re-ran), make sure every table/column we depend on actually exists.
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
        isActive INTEGER NOT NULL DEFAULT 0,
        deletedAt TEXT
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

    // bills table — includes deletedAt for Recycle Bin (soft-delete) support.
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
        bookId TEXT NOT NULL DEFAULT '',
        deletedAt TEXT
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

    // ── Staff (NEW) ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        salaryType TEXT NOT NULL DEFAULT 'monthly',
        salaryAmount REAL NOT NULL DEFAULT 0,
        salaryStartDate TEXT NOT NULL,
        permissionsEnabled INTEGER NOT NULL DEFAULT 0,
        fullPermission INTEGER NOT NULL DEFAULT 0,
        partyPermission TEXT NOT NULL DEFAULT 'none',
        createdAt TEXT NOT NULL,
        bookId TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE staff_attendance (
        id TEXT PRIMARY KEY,
        staffId TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'present',
        bookId TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (staffId) REFERENCES staff(id)
      )
    ''');
  }

  // ── Incremental migrations ────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: add isActive to business_profile, add bookId to all data tables
    if (oldVersion < 2) {
      await _safeAlter(db,
          'ALTER TABLE business_profile ADD COLUMN isActive INTEGER NOT NULL DEFAULT 0');

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

    // v3 → v4: no schema change — bump exists purely to force
    // _ensureSchema() to run on devices whose onUpgrade silently failed.

    // v4 → v5: add deletedAt to bills (Recycle Bin).
    if (oldVersion < 5) {
      await _safeAlter(db, 'ALTER TABLE bills ADD COLUMN deletedAt TEXT');
    }

    // v5 → v6: add deletedAt to business_profile (Delete Khata Recycle Bin).
    if (oldVersion < 6) {
      await _safeAlter(
          db, 'ALTER TABLE business_profile ADD COLUMN deletedAt TEXT');
    }

    // v6 → v7 (NEW): create `staff` and `staff_attendance` tables for the
    // Staff Management feature.
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT NOT NULL DEFAULT '',
          salaryType TEXT NOT NULL DEFAULT 'monthly',
          salaryAmount REAL NOT NULL DEFAULT 0,
          salaryStartDate TEXT NOT NULL,
          permissionsEnabled INTEGER NOT NULL DEFAULT 0,
          fullPermission INTEGER NOT NULL DEFAULT 0,
          partyPermission TEXT NOT NULL DEFAULT 'none',
          createdAt TEXT NOT NULL,
          bookId TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_attendance (
          id TEXT PRIMARY KEY,
          staffId TEXT NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'present',
          bookId TEXT NOT NULL DEFAULT '',
          FOREIGN KEY (staffId) REFERENCES staff(id)
        )
      ''');
    }
  }

  /// Runs an ALTER TABLE, swallowing "duplicate column" errors only.
  Future<void> _safeAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains('duplicate column')) {
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

  /// Whether a table with this name currently exists.
  Future<bool> _tableExists(Database db, String name) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [name],
    );
    return res.isNotEmpty;
  }

  /// Defensive self-heal: guarantees every table/column the app code
  /// reads/writes actually exists, regardless of what the stored
  /// user_version claims.
  Future<void> _ensureSchema(Database db) async {
    final bpCols = await _columnsOf(db, 'business_profile');
    if (!bpCols.contains('isActive')) {
      await _safeAlter(db,
          'ALTER TABLE business_profile ADD COLUMN isActive INTEGER NOT NULL DEFAULT 0');
      final activeCount = await db.rawQuery(
          'SELECT COUNT(*) as c FROM business_profile WHERE isActive = 1');
      final hasActive = ((activeCount.first['c'] as int?) ?? 0) > 0;
      if (!hasActive) {
        final profiles = await db.query('business_profile', limit: 1);
        if (profiles.isNotEmpty) {
          await db.update('business_profile', {'isActive': 1},
              where: 'id = ?', whereArgs: [profiles.first['id']]);
        }
      }
    }
    if (!bpCols.contains('deletedAt')) {
      await _safeAlter(
          db, 'ALTER TABLE business_profile ADD COLUMN deletedAt TEXT');
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

    final billsCols = await _columnsOf(db, 'bills');
    if (!billsCols.contains('deletedAt')) {
      await _safeAlter(db, 'ALTER TABLE bills ADD COLUMN deletedAt TEXT');
    }

    // ── Staff (NEW) — create tables if a prior failed/skipped upgrade left
    // them missing even though user_version says otherwise.
    if (!await _tableExists(db, 'staff')) {
      await db.execute('''
        CREATE TABLE staff (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT NOT NULL DEFAULT '',
          salaryType TEXT NOT NULL DEFAULT 'monthly',
          salaryAmount REAL NOT NULL DEFAULT 0,
          salaryStartDate TEXT NOT NULL,
          permissionsEnabled INTEGER NOT NULL DEFAULT 0,
          fullPermission INTEGER NOT NULL DEFAULT 0,
          partyPermission TEXT NOT NULL DEFAULT 'none',
          createdAt TEXT NOT NULL,
          bookId TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (!await _tableExists(db, 'staff_attendance')) {
      await db.execute('''
        CREATE TABLE staff_attendance (
          id TEXT PRIMARY KEY,
          staffId TEXT NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'present',
          bookId TEXT NOT NULL DEFAULT '',
          FOREIGN KEY (staffId) REFERENCES staff(id)
        )
      ''');
    }
  }

  // ── BusinessProfile ───────────────────────────────────────────────────────

  Future<BusinessProfile?> getBusinessProfile() async {
    final db = await database;
    try {
      final maps = await db.query('business_profile',
          where: 'isActive = 1 AND deletedAt IS NULL', limit: 1);
      if (maps.isNotEmpty) return BusinessProfile.fromMap(maps.first);
      final any = await db.query('business_profile',
          where: 'deletedAt IS NULL', limit: 1);
      if (any.isEmpty) return null;
      await db.update('business_profile', {'isActive': 1},
          where: 'id = ?', whereArgs: [any.first['id']]);
      return BusinessProfile.fromMap(any.first);
    } catch (e) {
      await _ensureSchema(db);
      final maps = await db.query('business_profile', limit: 1);
      if (maps.isEmpty) return null;
      return BusinessProfile.fromMap(maps.first);
    }
  }

  Future<List<BusinessProfile>> getAllBusinessProfiles() async {
    final db = await database;
    final maps = await db.query('business_profile',
        where: 'deletedAt IS NULL', orderBy: 'createdAt ASC');
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

  // ── Khata (business profile) Recycle Bin ────────────────────────────────

  Future<void> softDeleteBusinessProfile(String id) async {
    final db = await database;
    await db.update(
      'business_profile',
      {
        'deletedAt': DateTime.now().toIso8601String(),
        'isActive': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreBusinessProfile(String id) async {
    final db = await database;
    await db.update(
      'business_profile',
      {'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    final activeCount = await db.rawQuery(
        'SELECT COUNT(*) as c FROM business_profile WHERE isActive = 1 AND deletedAt IS NULL');
    final hasActive = ((activeCount.first['c'] as int?) ?? 0) > 0;
    if (!hasActive) {
      await db.update('business_profile', {'isActive': 1},
          where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<Map<String, dynamic>>> getDeletedBusinessProfiles() async {
    await purgeExpiredDeletedBusinessProfiles();
    final db = await database;
    return db.query(
      'business_profile',
      where: 'deletedAt IS NOT NULL',
      orderBy: 'deletedAt DESC',
    );
  }

  Future<void> purgeExpiredDeletedBusinessProfiles() async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final expired = await db.query(
      'business_profile',
      where: 'deletedAt IS NOT NULL AND deletedAt < ?',
      whereArgs: [cutoff],
    );
    for (final row in expired) {
      await permanentlyDeleteBusinessProfile(row['id'] as String);
    }
  }

  Future<void> permanentlyDeleteBusinessProfile(String bookId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('customer_transactions',
          where: 'bookId = ?', whereArgs: [bookId]);
      await txn.delete('customers', where: 'bookId = ?', whereArgs: [bookId]);
      await txn.delete('suppliers', where: 'bookId = ?', whereArgs: [bookId]);
      await txn.delete('items', where: 'bookId = ?', whereArgs: [bookId]);
      await txn.delete('app_transactions',
          where: 'bookId = ?', whereArgs: [bookId]);
      await txn.delete('cashbook_entries',
          where: 'bookId = ?', whereArgs: [bookId]);
      await txn.delete('staff', where: 'bookId = ?', whereArgs: [bookId]);

      final billRows = await txn.query('bills',
          columns: ['id'], where: 'bookId = ?', whereArgs: [bookId]);
      for (final row in billRows) {
        await txn.delete('bill_items',
            where: 'billId = ?', whereArgs: [row['id']]);
      }
      await txn.delete('bills', where: 'bookId = ?', whereArgs: [bookId]);

      await txn.delete('business_profile', where: 'id = ?', whereArgs: [bookId]);
    });
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
    final conditions = <String>['deletedAt IS NULL'];
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
      where: conditions.join(' AND '),
      whereArgs: args,
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
    await db.update(
      'bills',
      {'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreBill(String id) async {
    final db = await database;
    await db.update(
      'bills',
      {'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteBill(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('bill_items', where: 'billId = ?', whereArgs: [id]);
      await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Bill>> getDeletedBills({String bookId = ''}) async {
    await purgeExpiredDeletedBills();
    final db = await database;
    final conditions = <String>['deletedAt IS NOT NULL'];
    final args = <Object?>[];
    if (bookId.isNotEmpty) {
      conditions.add('bookId = ?');
      args.add(bookId);
    }
    final billMaps = await db.query(
      'bills',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'deletedAt DESC',
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

  Future<void> purgeExpiredDeletedBills() async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final expired = await db.query(
      'bills',
      where: 'deletedAt IS NOT NULL AND deletedAt < ?',
      whereArgs: [cutoff],
    );
    if (expired.isEmpty) return;
    await db.transaction((txn) async {
      for (final row in expired) {
        final id = row['id'] as String;
        await txn.delete('bill_items', where: 'billId = ?', whereArgs: [id]);
        await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
      }
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

  // ── Staff (NEW) ─────────────────────────────────────────────────────────

  Future<List<Staff>> getStaff(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'staff',
      where: bookId.isEmpty ? null : 'bookId = ?',
      whereArgs: bookId.isEmpty ? null : [bookId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Staff.fromMap(m)).toList();
  }

  Future<void> insertStaff(Staff staff) async {
    final db = await database;
    await db.insert('staff', staff.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStaff(Staff staff) async {
    final db = await database;
    await db.update('staff', staff.toMap(),
        where: 'id = ?', whereArgs: [staff.id]);
  }

  Future<void> deleteStaff(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('staff_attendance',
          where: 'staffId = ?', whereArgs: [id]);
      await txn.delete('staff', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── Staff Attendance (NEW) ───────────────────────────────────────────────

  Future<List<StaffAttendance>> getAttendanceForStaff(String staffId) async {
    final db = await database;
    final maps = await db.query('staff_attendance',
        where: 'staffId = ?', whereArgs: [staffId], orderBy: 'date DESC');
    return maps.map((m) => StaffAttendance.fromMap(m)).toList();
  }

  /// Upserts one attendance record per (staff, day) — marking the same day
  /// twice updates the existing record instead of creating a duplicate.
  Future<void> setAttendance(StaffAttendance attendance) async {
    final db = await database;
    final normalizedDate =
        StaffAttendance.normalize(attendance.date).toIso8601String();
    final existing = await db.query(
      'staff_attendance',
      where: 'staffId = ? AND date = ?',
      whereArgs: [attendance.staffId, normalizedDate],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'staff_attendance',
        attendance.copyWith(id: existing.first['id'] as String).toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('staff_attendance', attendance.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<StaffAttendance>> getAttendanceInRange(
      String staffId, DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'staff_attendance',
      where: 'staffId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        staffId,
        StaffAttendance.normalize(from).toIso8601String(),
        StaffAttendance.normalize(to).toIso8601String(),
      ],
    );
    return maps.map((m) => StaffAttendance.fromMap(m)).toList();
  }
}