// lib/providers/providers.dart
// ─────────────────────────────────────────────────────────────────────────────
// All providers for GBook app — MULTI-KHATABOOK support.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/local_database.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

// ── AuthProvider ──────────────────────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  BusinessProfile? _profile;
  List<BusinessProfile> _books = [];
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;

  BusinessProfile? get profile => _profile;
  List<BusinessProfile> get books => List.unmodifiable(_books);
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BusinessProfile? get user => _profile;
  BusinessProfile? get business => _profile;
  String get activeBookId => _profile?.id ?? '';

  final List<Future<void> Function(String bookId)> _bookChangeListeners = [];

  void addBookChangeListener(Future<void> Function(String bookId) listener) {
    _bookChangeListeners.add(listener);
  }

  Future<void> _notifyBookChangeListeners() async {
    for (final listener in _bookChangeListeners) {
      await listener(activeBookId);
    }
  }

  Future<void> _loadAllBooks() async {
    _books = await LocalDatabase.instance.getAllBusinessProfiles();
  }

  Future<bool> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      await _loadAllBooks();
      final p = await LocalDatabase.instance.getBusinessProfile();
      if (token != null && token.isNotEmpty && p != null) {
        _profile = p;
        _isAuthenticated = true;
        _accessToken = token;
      } else {
        _isAuthenticated = false;
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
      debugPrint('📱 sendOtp → URL: $url, phone: $phone');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      debugPrint('📱 sendOtp ← status: ${response.statusCode}, body: ${response.body}');

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) return true;

      try {
        final body = jsonDecode(response.body);
        _error = body['error'] ?? body['detail'] ?? 'Failed to send OTP';
      } catch (_) {
        _error = 'Failed to send OTP (${response.statusCode})';
      }
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('📱 sendOtp ✗ exception: $e\n$stack');
      _isLoading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Verifies OTP with the backend.
  /// Returns true on success. On success, `profile` will be non-null ONLY
  /// if the user already completed business setup previously.
  /// Callers should check `auth.profile == null` to decide whether to push
  /// `ProfileSetupScreen` or `HomeScreen`.
  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final url = '${AppConstants.baseUrl}/auth/verify-otp/';
      debugPrint('📱 verifyOtp → URL: $url, phone: $phone');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );

      debugPrint('📱 verifyOtp ← status: ${response.statusCode}, body: ${response.body}');

      _isLoading = false;

      if (response.statusCode == 200) {
        Map<String, dynamic> body;
        try {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          _error = 'Invalid server response';
          notifyListeners();
          return false;
        }

        // Save tokens
        _accessToken = body['access'] as String?;
        _refreshToken = body['refresh'] as String?;

        if (_accessToken == null || _accessToken!.isEmpty) {
          _error = 'No access token in response';
          notifyListeners();
          return false;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _accessToken!);
        if (_refreshToken != null) {
          await prefs.setString('refresh_token', _refreshToken!);
        }

        // Check if the user has a saved business profile locally
        await _loadAllBooks();
        final existing = await LocalDatabase.instance.getBusinessProfile();
        if (existing != null) {
          _profile = existing;
          _isAuthenticated = true;
        }
        // If no local profile, _profile stays null → caller routes to setup

        notifyListeners();
        return true;
      }

      // Non-200 response
      try {
        final body = jsonDecode(response.body);
        _error = body['error'] ?? body['detail'] ?? body['message'] ??
            'Invalid OTP (${response.statusCode})';
      } catch (_) {
        _error = 'Invalid OTP (${response.statusCode})';
      }
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('📱 verifyOtp ✗ exception: $e\n$stack');
      _isLoading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> saveProfile(BusinessProfile p) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await LocalDatabase.instance.saveBusinessProfile(p, makeActive: true);
      await _loadAllBooks();
      _profile = p;
      _isAuthenticated = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BusinessProfile> createNewKhatabook({
    required String businessName,
    String? category,
  }) async {
    final newProfile = BusinessProfile(
      id: AppHelpers.generateId(),
      businessName: businessName,
      ownerName: _profile?.ownerName ?? '',
      phone: _profile?.phone ?? '',
      email: _profile?.email,
      address: null,
      gstin: null,
      category: category ?? _profile?.category,
      createdAt: DateTime.now(),
    );

    await LocalDatabase.instance.createBusinessProfile(newProfile);
    await _loadAllBooks();
    _profile = newProfile;
    _isAuthenticated = true;
    notifyListeners();
    await _notifyBookChangeListeners();
    return newProfile;
  }

  Future<void> switchToBook(String bookId) async {
    if (bookId == activeBookId) return;
    await LocalDatabase.instance.setActiveBusinessProfile(bookId);
    final updated = _books.firstWhere(
      (b) => b.id == bookId,
      orElse: () => _profile!,
    );
    _profile = updated;
    notifyListeners();
    await _notifyBookChangeListeners();
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
      await LocalDatabase.instance.saveBusinessProfile(updated);
      await _loadAllBooks();
      _profile = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    _profile = null;
    _books = [];
    _isAuthenticated = false;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
    notifyListeners();
  }
}

// ── CustomerProvider ──────────────────────────────────────────────────────────
class CustomerProvider extends ChangeNotifier {
  final List<Customer> _customers = [];
  final Map<String, List<CustomerTransaction>> _txMap = {};
  bool _loading = false;
  String? _error;
  String _bookId = '';

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

  Future<void> loadCustomers({String? bookId}) async {
    if (bookId != null) _bookId = bookId;
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getCustomers(_bookId);
      _customers
        ..clear()
        ..addAll(list);
      _txMap.clear();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('loadCustomers error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reloadForActiveBook(String bookId) async {
    _customers.clear();
    _txMap.clear();
    notifyListeners();
    await loadCustomers(bookId: bookId);
  }

  Future<List<CustomerTransaction>> getTransactions(String customerId) async {
    try {
      final list =
          await LocalDatabase.instance.getCustomerTransactions(customerId);
      _txMap[customerId] = list;
      notifyListeners();
      return list;
    } catch (e) {
      debugPrint('getTransactions error: $e');
      return [];
    }
  }

  Future<void> addCustomer(Customer customer) async {
    final withBook =
        customer.bookId.isEmpty ? customer.copyWith(bookId: _bookId) : customer;
    await LocalDatabase.instance.insertCustomer(withBook);
    _customers.add(withBook);
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

  Future<void> addTransaction(CustomerTransaction tx) async {
    final withBook = tx.bookId.isEmpty ? tx.copyWith(bookId: _bookId) : tx;
    await LocalDatabase.instance.insertCustomerTransaction(withBook);
    _txMap.putIfAbsent(withBook.customerId, () => []).insert(0, withBook);
    final idx = _customers.indexWhere((c) => c.id == withBook.customerId);
    if (idx != -1) {
      final current = _customers[idx];
      final delta = withBook.isGiven ? withBook.amount : -withBook.amount;
      _customers[idx] = current.copyWith(balance: current.balance + delta);
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
      await LocalDatabase.instance.deleteCustomerTransaction(transactionId);
      _txMap[customerId]?.removeWhere((t) => t.id == transactionId);
      final idx = _customers.indexWhere((c) => c.id == customerId);
      if (idx != -1) {
        final current = _customers[idx];
        final delta = tx.isGiven ? -tx.amount : tx.amount;
        _customers[idx] = current.copyWith(balance: current.balance + delta);
        await LocalDatabase.instance.updateCustomer(_customers[idx]);
      }
      notifyListeners();
    }
  }
}

typedef CustomersProvider = CustomerProvider;

// ── TransactionProvider ───────────────────────────────────────────────────────
class TransactionProvider extends ChangeNotifier {
  final List<AppTransaction> _transactions = [];
  bool _loading = false;
  String? _error;
  String _bookId = '';

  List<AppTransaction> get transactions => List.unmodifiable(_transactions);
  bool get loading => _loading;
  String? get error => _error;

  double get totalIn =>
      _transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
  double get totalOut =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
  double get balance => totalIn - totalOut;
  double get totalGiven => totalOut;
  double get totalReceived => totalIn;

  Future<void> loadTransactions({String? bookId}) async {
    if (bookId != null) _bookId = bookId;
    _loading = true;
    notifyListeners();
    try {
      final list =
          await LocalDatabase.instance.getTransactions(bookId: _bookId);
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

  Future<void> reloadForActiveBook(String bookId) async {
    _transactions.clear();
    notifyListeners();
    await loadTransactions(bookId: bookId);
  }

  Future<AppTransaction?> addTransaction(AppTransaction tx) async {
    _error = null;
    try {
      final withBook = tx.bookId.isEmpty ? tx.copyWith(bookId: _bookId) : tx;
      await LocalDatabase.instance.insertTransaction(withBook);
      _transactions.insert(0, withBook);
      notifyListeners();
      return withBook;
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
        bookId: _bookId,
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
  String _bookId = '';

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  bool get loading => _loading;

  double get totalPayable => _suppliers
      .where((s) => s.balance > 0)
      .fold(0.0, (sum, s) => sum + s.balance);

  Future<void> loadSuppliers({String? bookId}) async {
    if (bookId != null) _bookId = bookId;
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getSuppliers(_bookId);
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

  Future<void> reloadForActiveBook(String bookId) async {
    _suppliers.clear();
    notifyListeners();
    await loadSuppliers(bookId: bookId);
  }

  Future<void> addSupplier(Supplier supplier) async {
    final withBook = supplier.bookId.isEmpty
        ? supplier.copyWith(bookId: _bookId)
        : supplier;
    await LocalDatabase.instance.insertSupplier(withBook);
    _suppliers.add(withBook);
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
  String _bookId = '';

  List<Item> get items => List.unmodifiable(_items);
  bool get loading => _loading;

  Future<void> loadItems({String? bookId}) async {
    if (bookId != null) _bookId = bookId;
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getItems(_bookId);
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

  Future<void> reloadForActiveBook(String bookId) async {
    _items.clear();
    notifyListeners();
    await loadItems(bookId: bookId);
  }

  Future<void> addItem(Item item) async {
    final withBook =
        item.bookId.isEmpty ? item.copyWith(bookId: _bookId) : item;
    await LocalDatabase.instance.insertItem(withBook);
    _items.add(withBook);
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
  String _bookId = '';

  List<Bill> get bills => List.unmodifiable(_bills);
  bool get loading => _loading;

  List<Bill> get saleBills =>
      _bills.where((b) => b.billType == BillType.sale).toList();
  List<Bill> get purchaseBills =>
      _bills.where((b) => b.billType == BillType.purchase).toList();
  List<Bill> get expenseBills =>
      _bills.where((b) => b.billType == BillType.expense).toList();

  double get totalSales => saleBills.fold(0.0, (s, b) => s + b.grandTotal);
  double get totalPurchases =>
      purchaseBills.fold(0.0, (s, b) => s + b.grandTotal);

  double get monthlySales {
    final now = DateTime.now();
    return saleBills
        .where((b) => b.date.month == now.month && b.date.year == now.year)
        .fold(0.0, (s, b) => s + b.grandTotal);
  }

  double get monthlyPurchases {
    final now = DateTime.now();
    return purchaseBills
        .where((b) => b.date.month == now.month && b.date.year == now.year)
        .fold(0.0, (s, b) => s + b.grandTotal);
  }

  Future<void> loadBills({String? bookId}) async {
    if (bookId != null) _bookId = bookId;
    _loading = true;
    notifyListeners();
    try {
      final list = await LocalDatabase.instance.getBills(bookId: _bookId);
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

  Future<void> reloadForActiveBook(String bookId) async {
    _bills.clear();
    notifyListeners();
    await loadBills(bookId: bookId);
  }

  Future<void> addBill(Bill bill) async {
    final withBook =
        bill.bookId.isEmpty ? bill.copyWith(bookId: _bookId) : bill;
    await LocalDatabase.instance.insertBill(withBook);
    _bills.insert(0, withBook);
    notifyListeners();
  }

  Future<void> add(Bill bill) => addBill(bill);

  Future<void> deleteBill(String billId) async {
    await LocalDatabase.instance.deleteBill(billId);
    _bills.removeWhere((b) => b.id == billId);
    notifyListeners();
  }

  Future<int> getNextBillNumber(BillType type) async {
    return LocalDatabase.instance.getNextBillNumber(_bookId, type);
  }

  Future<int> nextBillNumber(BillType type) => getNextBillNumber(type);
}

typedef BillsProvider = BillProvider;
typedef BusinessProfileProvider = AuthProvider;

// ── CashbookProvider ──────────────────────────────────────────────────────────
class CashbookProvider extends ChangeNotifier {
  final List<CashbookEntry> _entries = [];
  bool _loading = false;
  String _bookId = '';

  List<CashbookEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;

  double get totalIn =>
      _entries.where((e) => e.isCashIn).fold(0.0, (s, e) => s + e.amount);
  double get totalOut =>
      _entries.where((e) => !e.isCashIn).fold(0.0, (s, e) => s + e.amount);
  double get balance => totalIn - totalOut;

  Future<void> loadEntries({String? bookId}) async {
    if (bookId != null) _bookId = bookId;
    _loading = true;
    notifyListeners();
    try {
      final list =
          await LocalDatabase.instance.getCashbookEntries(bookId: _bookId);
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

  Future<void> reloadForActiveBook(String bookId) async {
    _entries.clear();
    notifyListeners();
    await loadEntries(bookId: bookId);
  }

  Future<void> addEntry(CashbookEntry entry) async {
    final withBook =
        entry.bookId.isEmpty ? entry.copyWith(bookId: _bookId) : entry;
    await LocalDatabase.instance.insertCashbookEntry(withBook);
    _entries.insert(0, withBook);
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    await LocalDatabase.instance.deleteCashbookEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}