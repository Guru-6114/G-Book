// lib/services/local_database.dart
// ─────────────────────────────────────────────────────────────────────────────
// SQLite local database for GBook app
// ─────────────────────────────────────────────────────────────────────────────
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gbook.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

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
        createdAt TEXT NOT NULL
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
        createdAt TEXT NOT NULL
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
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cashbook_entries (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        isCashIn INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        paymentMode TEXT NOT NULL DEFAULT 'cash',
        date TEXT NOT NULL
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
        createdAt TEXT NOT NULL
      )
    ''');

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
        createdAt TEXT NOT NULL
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
        createdAt TEXT NOT NULL
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

  // ── BusinessProfile ───────────────────────────────────────────────────────

  Future<BusinessProfile?> getBusinessProfile() async {
    final db = await database;
    final maps = await db.query('business_profile', limit: 1);
    if (maps.isEmpty) return null;
    return BusinessProfile.fromMap(maps.first);
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    final db = await database;
    await db.insert(
      'business_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<String> insertCustomer(Customer customer) async {
    final db = await database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return customer.id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
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
    await db.insert(
      'customer_transactions',
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomerTransaction(String id) async {
    final db = await database;
    await db.delete('customer_transactions',
        where: 'id = ?', whereArgs: [id]);
  }

  // ── AppTransactions ───────────────────────────────────────────────────────

  Future<List<AppTransaction>> getTransactions(
      {DateTime? from, DateTime? to}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
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
    await db.insert(
      'app_transactions',
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('app_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<String> insertSupplier(Supplier supplier) async {
    final db = await database;
    await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return supplier.id;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await database;
    await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<void> deleteSupplier(String id) async {
    final db = await database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<Item>> getItems() async {
    final db = await database;
    final maps = await db.query('items', orderBy: 'name ASC');
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<String> insertItem(Item item) async {
    final db = await database;
    await db.insert(
      'items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item.id;
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  Future<List<Bill>> getBills(
      {BillType? type, DateTime? from, DateTime? to}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
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
      final itemMaps = await db.query(
        'bill_items',
        where: 'billId = ?',
        whereArgs: [bm['id']],
      );
      bills.add(
        Bill.fromMap(bm, itemMaps.map((m) => BillItem.fromMap(m)).toList()),
      );
    }
    return bills;
  }

  Future<void> insertBill(Bill bill) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'bills',
        bill.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final item in bill.items) {
        await txn.insert(
          'bill_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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

  Future<int> getNextBillNumber(BillType type) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bills WHERE billType = ?',
      [type.name],
    );
    return ((result.first['count'] as int?) ?? 0) + 1;
  }

  // ── Cashbook ──────────────────────────────────────────────────────────────

  Future<List<CashbookEntry>> getCashbookEntries(
      {DateTime? from, DateTime? to}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
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
    await db.insert(
      'cashbook_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCashbookEntry(String id) async {
    final db = await database;
    await db.delete('cashbook_entries', where: 'id = ?', whereArgs: [id]);
  }
}