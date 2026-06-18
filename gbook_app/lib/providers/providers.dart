// lib/providers/providers.dart
// ─────────────────────────────────────────────────────────────────────────────
// All providers for GBook app
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/local_database.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// ── AuthProvider ──────────────────────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  BusinessProfile? _profile;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;

  BusinessProfile? get profile => _profile;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BusinessProfile? get user => _profile;
  BusinessProfile? get business => _profile;

  Future<bool> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        final p = await LocalDatabase.instance.getBusinessProfile();
        if (p != null) {
          _profile = p;
          _isAuthenticated = true;
          _accessToken = token;
        }
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _isAuthenticated;
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final url = '${AppConstants.baseUrl}/auth/send-otp/';
      debugPrint('📱 sendOtp → URL: $url');
      debugPrint('📱 sendOtp → phone: $phone');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      debugPrint('📱 sendOtp ← status: ${response.statusCode}');
      debugPrint('📱 sendOtp ← body: ${response.body}');

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) return true;

      final body = jsonDecode(response.body);
      _error = body['error'] ?? body['detail'] ?? 'Failed to send OTP';
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('📱 sendOtp ✗ exception: $e');
      debugPrint('📱 sendOtp ✗ stack: $stack');
      _isLoading = false;
      _error = 'Network error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final url = '${AppConstants.baseUrl}/auth/verify-otp/';
      debugPrint('📱 verifyOtp → URL: $url');
      debugPrint('📱 verifyOtp → phone: $phone, otp: $otp');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );

      debugPrint('📱 verifyOtp ← status: ${response.statusCode}');
      debugPrint('📱 verifyOtp ← body: ${response.body}');

      final body = jsonDecode(response.body);
      _isLoading = false;

      if (response.statusCode == 200) {
        _accessToken = body['access'];
        _refreshToken = body['refresh'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        final existing = await LocalDatabase.instance.getBusinessProfile();
        if (existing != null) {
          _profile = existing;
          _isAuthenticated = true;
        }
        notifyListeners();
        return true;
      }

      _error = body['error'] ?? body['detail'] ?? 'Invalid OTP';
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('📱 verifyOtp ✗ exception: $e');
      debugPrint('📱 verifyOtp ✗ stack: $stack');
      _isLoading = false;
      _error = 'Network error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> saveProfile(BusinessProfile p) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await LocalDatabase.instance.saveBusinessProfile(p);
      _profile = p;
      _isAuthenticated = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_profile == null) return false;
    _error = null;
    try {
      final updated = _profile!.copyWith(
        ownerName: data['name'] as String? ?? _profile!.ownerName,
        email: data['email'] as String? ?? _profile!.email,
        address: data['address'] as String? ?? _profile!.address,
      );
      await saveProfile(updated);
      return _error == null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBusiness(Map<String, dynamic> data) async {
    if (_profile == null) return false;
    _error = null;
    try {
      final updated = _profile!.copyWith(
        businessName: data['name'] as String? ?? _profile!.businessName,
        gstin: data['gstin'] as String? ?? _profile!.gstin,
        category: data['category'] as String? ?? _profile!.category,
      );
      await saveProfile(updated);
      return _error == null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // FIX #9: Logout now properly clears ALL state and calls notifyListeners
  // so the _RootRedirect widget rebuilds and shows AuthScreen.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      await prefs.remove(AppConstants.tokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
    } catch (_) {}

    // Clear all in-memory state
    _profile = null;
    _isAuthenticated = false;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
    _isLoading = false;

    // FIX #9: This notifyListeners triggers _RootRedirect to rebuild,
    // which will now see isAuthenticated=false and show AuthScreen.
    notifyListeners();
  }
}

// ── CustomerProvider ──────────────────────────────────────────────────────────
class CustomerProvider extends ChangeNotifier {
  final List<Customer> _customers = [];
  final Map<String, List<CustomerTransaction>> _txMap = {};
  bool _loading = false;
  String? _error;

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get loading => _loading;
  String? get error => _error;

  List<CustomerTransaction> transactionsFor(String customerId) =>
      List.unmodifiable(_txMap[customerId] ?? []);

  double get totalReceivable => _customers
      .where((c) => c.balance > 0)
      .fold(0.0, (sum, c) => sum + c.balance);

  double get totalPayable => _customers
      .where((c) => c.balance < 0)
      .fold(0.0, (sum, c) => sum + c.balance.abs());

  Future<void> loadCustomers() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getCustomers();
      _customers
        ..clear()
        ..addAll(list);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('loadCustomers error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<CustomerTransaction>> getTransactions(
      String customerId) async {
    try {
      final list = await LocalDatabase.instance
          .getCustomerTransactions(customerId);
      _txMap[customerId] = list;
      notifyListeners();
      return list;
    } catch (e) {
      debugPrint('getTransactions error: $e');
      return [];
    }
  }

  Future<void> addCustomer(Customer customer) async {
    await LocalDatabase.instance.insertCustomer(customer);
    _customers.add(customer);
    notifyListeners();
  }

  Future<void> updateCustomer(Customer customer) async {
    await LocalDatabase.instance.updateCustomer(customer);
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) _customers[idx] = customer;
    notifyListeners();
  }

  Future<void> deleteCustomer(String customerId) async {
    await LocalDatabase.instance.deleteCustomer(customerId);
    _customers.removeWhere((c) => c.id == customerId);
    _txMap.remove(customerId);
    notifyListeners();
  }

  // FIX #5: addTransaction checks for duplicate IDs before inserting
  Future<void> addTransaction(CustomerTransaction tx) async {
    // Idempotency check — if already in DB/list, skip
    final existingList = _txMap[tx.customerId] ?? [];
    if (existingList.any((t) => t.id == tx.id)) {
      debugPrint('addTransaction: duplicate detected, skipping ${tx.id}');
      return;
    }

    await LocalDatabase.instance.insertCustomerTransaction(tx);
    _txMap.putIfAbsent(tx.customerId, () => []).insert(0, tx);

    final idx = _customers.indexWhere((c) => c.id == tx.customerId);
    if (idx != -1) {
      final current = _customers[idx];
      final delta = tx.isGiven ? tx.amount : -tx.amount;
      _customers[idx] =
          current.copyWith(balance: current.balance + delta);
      await LocalDatabase.instance.updateCustomer(_customers[idx]);
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(
      String transactionId, String customerId) async {
    final txList = _txMap[customerId] ?? [];
    final tx = txList.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => CustomerTransaction(
        id: '',
        customerId: customerId,
        amount: 0,
        isGiven: false,
        date: DateTime.now(),
      ),
    );
    if (tx.id.isNotEmpty) {
      await LocalDatabase.instance
          .deleteCustomerTransaction(transactionId);
      _txMap[customerId]?.removeWhere((t) => t.id == transactionId);
      final idx = _customers.indexWhere((c) => c.id == customerId);
      if (idx != -1) {
        final current = _customers[idx];
        final delta = tx.isGiven ? -tx.amount : tx.amount;
        _customers[idx] =
            current.copyWith(balance: current.balance + delta);
        await LocalDatabase.instance.updateCustomer(_customers[idx]);
      }
      notifyListeners();
    }
  }
}

// Alias so any screen using CustomersProvider still works
typedef CustomersProvider = CustomerProvider;

// ── TransactionProvider (App-level cashbook ledger) ───────────────────────────
class TransactionProvider extends ChangeNotifier {
  final List<AppTransaction> _transactions = [];
  bool _loading = false;
  String? _error;

  List<AppTransaction> get transactions => List.unmodifiable(_transactions);
  bool get loading => _loading;
  String? get error => _error;

  double get totalIn => _transactions
      .where((t) => t.isIncome)
      .fold(0.0, (s, t) => s + t.amount);

  double get totalOut => _transactions
      .where((t) => !t.isIncome)
      .fold(0.0, (s, t) => s + t.amount);

  double get balance => totalIn - totalOut;

  double get totalGiven => totalOut;
  double get totalReceived => totalIn;

  Future<void> loadTransactions() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getTransactions();
      _transactions
        ..clear()
        ..addAll(list);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('loadTransactions error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<AppTransaction?> addTransaction(AppTransaction tx) async {
    _error = null;
    try {
      await LocalDatabase.instance.insertTransaction(tx);
      _transactions.insert(0, tx);
      notifyListeners();
      return tx;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteTransaction(String id) async {
    await LocalDatabase.instance.deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<MonthlyReport?> getMonthlyReport(int year, int month) async {
    try {
      final all = await LocalDatabase.instance.getTransactions(
        from: DateTime(year, month, 1),
        to: DateTime(year, month + 1, 0, 23, 59, 59),
      );
      double credit = 0, debit = 0;
      for (final t in all) {
        if (t.isIncome) {
          debit += t.amount;
        } else {
          credit += t.amount;
        }
      }
      return MonthlyReport(
        year: year,
        month: month,
        totalCredit: credit,
        totalDebit: debit,
        transactionCount: all.length,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
}

// ── SupplierProvider ──────────────────────────────────────────────────────────
class SupplierProvider extends ChangeNotifier {
  final List<Supplier> _suppliers = [];
  bool _loading = false;

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  bool get loading => _loading;

  double get totalPayable => _suppliers
      .where((s) => s.balance > 0)
      .fold(0.0, (sum, s) => sum + s.balance);

  Future<void> loadSuppliers() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getSuppliers();
      _suppliers
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('loadSuppliers error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    await LocalDatabase.instance.insertSupplier(supplier);
    _suppliers.add(supplier);
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await LocalDatabase.instance.updateSupplier(supplier);
    final idx = _suppliers.indexWhere((s) => s.id == supplier.id);
    if (idx != -1) _suppliers[idx] = supplier;
    notifyListeners();
  }

  Future<void> deleteSupplier(String supplierId) async {
    await LocalDatabase.instance.deleteSupplier(supplierId);
    _suppliers.removeWhere((s) => s.id == supplierId);
    notifyListeners();
  }
}

typedef SuppliersProvider = SupplierProvider;

// ── ItemProvider ──────────────────────────────────────────────────────────────
class ItemProvider extends ChangeNotifier {
  final List<Item> _items = [];
  bool _loading = false;

  List<Item> get items => List.unmodifiable(_items);
  bool get loading => _loading;

  Future<void> loadItems() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getItems();
      _items
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('loadItems error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addItem(Item item) async {
    await LocalDatabase.instance.insertItem(item);
    _items.add(item);
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await LocalDatabase.instance.updateItem(item);
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) _items[idx] = item;
    notifyListeners();
  }

  Future<void> deleteItem(String itemId) async {
    await LocalDatabase.instance.deleteItem(itemId);
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  Future<void> adjustStock(String itemId, double delta) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final item = _items[idx];
    final newStock = (item.stock ?? 0) + delta;
    final updated = item.copyWith(stock: newStock < 0 ? 0 : newStock);
    await updateItem(updated);
  }
}

typedef ItemsProvider = ItemProvider;

// ── BillProvider ──────────────────────────────────────────────────────────────
class BillProvider extends ChangeNotifier {
  final List<Bill> _bills = [];
  bool _loading = false;

  List<Bill> get bills => List.unmodifiable(_bills);
  bool get loading => _loading;

  List<Bill> get saleBills =>
      _bills.where((b) => b.billType == BillType.sale).toList();
  List<Bill> get purchaseBills =>
      _bills.where((b) => b.billType == BillType.purchase).toList();
  List<Bill> get expenseBills =>
      _bills.where((b) => b.billType == BillType.expense).toList();

  double get totalSales =>
      saleBills.fold(0.0, (s, b) => s + b.grandTotal);
  double get totalPurchases =>
      purchaseBills.fold(0.0, (s, b) => s + b.grandTotal);

  double get monthlySales {
    final now = DateTime.now();
    return saleBills
        .where(
            (b) => b.date.month == now.month && b.date.year == now.year)
        .fold(0.0, (s, b) => s + b.grandTotal);
  }

  double get monthlyPurchases {
    final now = DateTime.now();
    return purchaseBills
        .where(
            (b) => b.date.month == now.month && b.date.year == now.year)
        .fold(0.0, (s, b) => s + b.grandTotal);
  }

  Future<void> loadBills() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getBills();
      _bills
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('loadBills error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAll() => loadBills();

  Future<void> addBill(Bill bill) async {
    await LocalDatabase.instance.insertBill(bill);
    _bills.insert(0, bill);
    notifyListeners();
  }

  Future<void> add(Bill bill) => addBill(bill);

  Future<void> deleteBill(String billId) async {
    await LocalDatabase.instance.deleteBill(billId);
    _bills.removeWhere((b) => b.id == billId);
    notifyListeners();
  }

  Future<int> getNextBillNumber(BillType type) async {
    return LocalDatabase.instance.getNextBillNumber(type);
  }

  Future<int> nextBillNumber(BillType type) => getNextBillNumber(type);
}

typedef BillsProvider = BillProvider;

// ── BusinessProfileProvider alias ─────────────────────────────────────────────
typedef BusinessProfileProvider = AuthProvider;

// ── CashbookProvider ──────────────────────────────────────────────────────────
class CashbookProvider extends ChangeNotifier {
  final List<CashbookEntry> _entries = [];
  bool _loading = false;

  List<CashbookEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;

  double get totalIn => _entries
      .where((e) => e.isCashIn)
      .fold(0.0, (s, e) => s + e.amount);

  double get totalOut => _entries
      .where((e) => !e.isCashIn)
      .fold(0.0, (s, e) => s + e.amount);

  double get balance => totalIn - totalOut;

  Future<void> loadEntries() async {
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getCashbookEntries();
      _entries
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('loadEntries error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addEntry(CashbookEntry entry) async {
    await LocalDatabase.instance.insertCashbookEntry(entry);
    _entries.insert(0, entry);
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    await LocalDatabase.instance.deleteCashbookEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}