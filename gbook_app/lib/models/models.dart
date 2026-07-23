// lib/models/models.dart
// ─────────────────────────────────────────────────────────────────────────────
// All data models for GBook app — multi-book support
// ─────────────────────────────────────────────────────────────────────────────

class PaymentStatus {
  static const String paid = 'paid';
  static const String unpaid = 'unpaid';
  static const String partial = 'partial';
  static const String fullyPaid = 'paid';
  static const String partiallyPaid = 'partial';
}

class TransactionType {
  static const String credit = 'credit';
  static const String debit = 'debit';
  static const String income = 'income';
  static const String expense = 'expense';
}

// ── BusinessProfile ───────────────────────────────────────────────────────────
class BusinessProfile {
  final String id;
  final String businessName;
  final String ownerName;
  final String phone;
  final String? email;
  final String? address;
  final String? gstin;
  final String? category;
  final DateTime createdAt;
  final bool isActive;
  final String? businessType;
  final String? staffCount;

  const BusinessProfile({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.phone,
    this.email,
    this.address,
    this.gstin,
    this.category,
    required this.createdAt,
    this.isActive = false,
    this.businessType,
    this.staffCount,
  });

  String get name => ownerName;

  BusinessProfile copyWith({
    String? id,
    String? businessName,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    String? category,
    DateTime? createdAt,
    bool? isActive,
    String? businessType,
    String? staffCount,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      businessType: businessType ?? this.businessType,
      staffCount: staffCount ?? this.staffCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'businessName': businessName,
        'ownerName': ownerName,
        'phone': phone,
        'email': email,
        'address': address,
        'gstin': gstin,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive ? 1 : 0,
        'businessType': businessType,
        'staffCount': staffCount,
      };

  Map<String, dynamic> toJson() => toMap();

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id'] as String,
      businessName: map['businessName'] as String,
      ownerName: (map['ownerName'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: map['email'] as String?,
      address: map['address'] as String?,
      gstin: map['gstin'] as String?,
      category: map['category'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isActive: ((map['isActive'] as int?) ?? 0) == 1,
      businessType: map['businessType'] as String?,
      staffCount: map['staffCount'] as String?,
    );
  }

  factory BusinessProfile.fromJson(Map<String, dynamic> json) =>
      BusinessProfile.fromMap(json);
}
// ── Customer ──────────────────────────────────────────────────────────────────
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double balance;
  final DateTime createdAt;
  final String bookId;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.balance = 0.0,
    required this.createdAt,
    this.bookId = '',
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? balance,
    DateTime? createdAt,
    String? bookId,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'balance': balance,
        'createdAt': createdAt.toIso8601String(),
        'bookId': bookId,
      };

  Map<String, dynamic> toJson() => toMap();

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(map['createdAt'] as String),
        bookId: (map['bookId'] as String?) ?? '',
      );

  factory Customer.fromJson(Map<String, dynamic> json) =>
      Customer.fromMap(json);
}

// ── CustomerTransaction ───────────────────────────────────────────────────────
class CustomerTransaction {
  final String id;
  final String customerId;
  final double amount;
  final bool isGiven;
  final String? note;
  final String paymentMode;
  final DateTime date;
  final String bookId;

  const CustomerTransaction({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.isGiven,
    this.note,
    this.paymentMode = 'cash',
    required this.date,
    this.bookId = '',
  });

  CustomerTransaction copyWith({
    String? id,
    String? customerId,
    double? amount,
    bool? isGiven,
    String? note,
    String? paymentMode,
    DateTime? date,
    String? bookId,
  }) {
    return CustomerTransaction(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      isGiven: isGiven ?? this.isGiven,
      note: note ?? this.note,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'amount': amount,
        'isGiven': isGiven ? 1 : 0,
        'note': note,
        'paymentMode': paymentMode,
        'date': date.toIso8601String(),
        'bookId': bookId,
      };

  Map<String, dynamic> toJson() => toMap();

  factory CustomerTransaction.fromMap(Map<String, dynamic> map) =>
      CustomerTransaction(
        id: map['id'] as String,
        customerId: map['customerId'] as String,
        amount: (map['amount'] as num).toDouble(),
        isGiven: (map['isGiven'] as int) == 1,
        note: map['note'] as String?,
        paymentMode: (map['paymentMode'] as String?) ?? 'cash',
        date: DateTime.parse(map['date'] as String),
        bookId: (map['bookId'] as String?) ?? '',
      );

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) =>
      CustomerTransaction.fromMap(json);
}

// ── AppTransaction ────────────────────────────────────────────────────────────
class AppTransaction {
  final String id;
  final double amount;
  final bool isIncome;
  final String? category;
  final String? note;
  final String paymentMode;
  final DateTime date;
  final String? customerId;
  final String? description;
  final String? referenceNumber;
  final String type;
  final String bookId;

  const AppTransaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    this.category,
    this.note,
    this.paymentMode = 'cash',
    required this.date,
    this.customerId,
    this.description,
    this.referenceNumber,
    String? type,
    this.bookId = '',
  }) : type =
            type ?? (isIncome ? TransactionType.credit : TransactionType.debit);

  AppTransaction copyWith({
    String? id,
    double? amount,
    bool? isIncome,
    String? category,
    String? note,
    String? paymentMode,
    DateTime? date,
    String? customerId,
    String? description,
    String? referenceNumber,
    String? type,
    String? bookId,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      note: note ?? this.note,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      customerId: customerId ?? this.customerId,
      description: description ?? this.description,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      type: type ?? this.type,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'isIncome': isIncome ? 1 : 0,
        'category': category,
        'note': note,
        'paymentMode': paymentMode,
        'date': date.toIso8601String(),
        'bookId': bookId,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'isIncome': isIncome,
        'category': category,
        'note': note,
        'paymentMode': paymentMode,
        'date': date.toIso8601String(),
        'customerId': customerId,
        'description': description,
        'referenceNumber': referenceNumber,
        'type': type,
        'bookId': bookId,
      };

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    final isIncome = map['isIncome'] is int
        ? (map['isIncome'] as int) == 1
        : (map['isIncome'] as bool?) ?? true;
    return AppTransaction(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      isIncome: isIncome,
      category: map['category'] as String?,
      note: map['note'] as String?,
      paymentMode: (map['paymentMode'] as String?) ?? 'cash',
      date: DateTime.parse(map['date'] as String),
      customerId: map['customerId'] as String?,
      description: map['description'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      type: (map['type'] as String?) ??
          (isIncome ? TransactionType.credit : TransactionType.debit),
      bookId: (map['bookId'] as String?) ?? '',
    );
  }

  factory AppTransaction.fromJson(Map<String, dynamic> json) =>
      AppTransaction.fromMap(json);
}

// ── CashbookEntry ─────────────────────────────────────────────────────────────
class CashbookEntry {
  final String id;
  final double amount;
  final bool isCashIn;
  final String? description;
  final String paymentMode;
  final DateTime date;
  final String bookId;

  const CashbookEntry({
    required this.id,
    required this.amount,
    required this.isCashIn,
    this.description,
    this.paymentMode = 'cash',
    required this.date,
    this.bookId = '',
  });

  CashbookEntry copyWith({
    String? id,
    double? amount,
    bool? isCashIn,
    String? description,
    String? paymentMode,
    DateTime? date,
    String? bookId,
  }) {
    return CashbookEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isCashIn: isCashIn ?? this.isCashIn,
      description: description ?? this.description,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'isCashIn': isCashIn ? 1 : 0,
        'description': description,
        'paymentMode': paymentMode,
        'date': date.toIso8601String(),
        'bookId': bookId,
      };

  factory CashbookEntry.fromMap(Map<String, dynamic> map) => CashbookEntry(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        isCashIn: (map['isCashIn'] as int) == 1,
        description: map['description'] as String?,
        paymentMode: (map['paymentMode'] as String?) ?? 'cash',
        date: DateTime.parse(map['date'] as String),
        bookId: (map['bookId'] as String?) ?? '',
      );
}

// ── Supplier ──────────────────────────────────────────────────────────────────
class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstin;
  final double balance;
  final DateTime createdAt;
  final String bookId;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.balance = 0.0,
    required this.createdAt,
    this.bookId = '',
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    double? balance,
    DateTime? createdAt,
    String? bookId,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'gstin': gstin,
        'balance': balance,
        'createdAt': createdAt.toIso8601String(),
        'bookId': bookId,
      };

  Map<String, dynamic> toJson() => toMap();

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        gstin: map['gstin'] as String?,
        balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(map['createdAt'] as String),
        bookId: (map['bookId'] as String?) ?? '',
      );

  factory Supplier.fromJson(Map<String, dynamic> json) =>
      Supplier.fromMap(json);
}

// ── Item ──────────────────────────────────────────────────────────────────────
enum ItemUnit { piece, kg, gram, litre, ml, metre, box, pack, dozen }

class Item {
  final String id;
  final String name;
  final double salePrice;
  final double? purchasePrice;
  final double? stock;
  final ItemUnit unit;
  final String? category;
  final String? description;
  final DateTime createdAt;
  final String bookId;

  final bool isService;
  final String? hsnCode;
  final double gstRate;
  final double lowStockThreshold;
  final String? imagePath;

  const Item({
    required this.id,
    required this.name,
    required this.salePrice,
    this.purchasePrice,
    this.stock,
    this.unit = ItemUnit.piece,
    this.category,
    this.description,
    required this.createdAt,
    this.bookId = '',
    this.isService = false,
    this.hsnCode,
    this.gstRate = 0,
    this.lowStockThreshold = 5,
    this.imagePath,
  });

  bool get isLowStock =>
      !isService && stock != null && stock! <= lowStockThreshold;

  Item copyWith({
    String? id,
    String? name,
    double? salePrice,
    double? purchasePrice,
    double? stock,
    ItemUnit? unit,
    String? category,
    String? description,
    DateTime? createdAt,
    String? bookId,
    bool? isService,
    String? hsnCode,
    double? gstRate,
    double? lowStockThreshold,
    String? imagePath,
    bool clearImage = false,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      bookId: bookId ?? this.bookId,
      isService: isService ?? this.isService,
      hsnCode: hsnCode ?? this.hsnCode,
      gstRate: gstRate ?? this.gstRate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'salePrice': salePrice,
        'purchasePrice': purchasePrice,
        'stock': stock,
        'unit': unit.name,
        'category': category,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'bookId': bookId,
        'isService': isService ? 1 : 0,
        'hsnCode': hsnCode,
        'gstRate': gstRate,
        'lowStockThreshold': lowStockThreshold,
        'imagePath': imagePath,
      };

  Map<String, dynamic> toJson() => toMap();

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id: map['id'] as String,
        name: map['name'] as String,
        salePrice: (map['salePrice'] as num).toDouble(),
        purchasePrice: (map['purchasePrice'] as num?)?.toDouble(),
        stock: (map['stock'] as num?)?.toDouble(),
        unit: ItemUnit.values.firstWhere(
          (e) => e.name == map['unit'],
          orElse: () => ItemUnit.piece,
        ),
        category: map['category'] as String?,
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        bookId: (map['bookId'] as String?) ?? '',
        isService: ((map['isService'] as int?) ?? 0) == 1,
        hsnCode: map['hsnCode'] as String?,
        gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0,
        lowStockThreshold:
            (map['lowStockThreshold'] as num?)?.toDouble() ?? 5,
        imagePath: map['imagePath'] as String?,
      );

  factory Item.fromJson(Map<String, dynamic> json) => Item.fromMap(json);
}

// ── Bill ──────────────────────────────────────────────────────────────────────
enum BillType { sale, purchase, saleReturn, purchaseReturn, expense }

enum BillStatus { draft, sent, paid, cancelled }

class BillItem {
  final String id;
  final String billId;
  final String itemId;
  final String itemName;
  final double quantity;
  final double rate;
  final double discount;
  final double taxPercent;
  final double total;

  const BillItem({
    required this.id,
    required this.billId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.rate,
    this.discount = 0,
    this.taxPercent = 0,
    required this.total,
  });

  BillItem copyWith({
    String? id,
    String? billId,
    String? itemId,
    String? itemName,
    double? quantity,
    double? rate,
    double? discount,
    double? taxPercent,
    double? total,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      discount: discount ?? this.discount,
      taxPercent: taxPercent ?? this.taxPercent,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'billId': billId,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'rate': rate,
        'discount': discount,
        'taxPercent': taxPercent,
        'total': total,
      };

  Map<String, dynamic> toJson() => toMap();

  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem(
        id: map['id'] as String,
        billId: map['billId'] as String,
        itemId: map['itemId'] as String,
        itemName: map['itemName'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        rate: (map['rate'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        taxPercent: (map['taxPercent'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num).toDouble(),
      );

  factory BillItem.fromJson(Map<String, dynamic> json) =>
      BillItem.fromMap(json);
}

class Bill {
  final String id;
  final String billNumber;
  final BillType billType;
  final BillStatus status;
  final String? partyId;
  final String? partyName;
  final List<BillItem> items;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final double paidAmount;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;
  final String bookId;

  // ── Recycle Bin support ──────────────────────────────────────────────────
  // null = active bill. Non-null = soft-deleted at this timestamp; the bill
  // stays queryable via LocalDatabase.getDeletedBills() for 30 days before
  // being purged, matching Khatabook's Recycle Bin behavior.
  final DateTime? deletedAt;

  const Bill({
    required this.id,
    required this.billNumber,
    required this.billType,
    this.status = BillStatus.draft,
    this.partyId,
    this.partyName,
    required this.items,
    required this.subtotal,
    this.discountTotal = 0,
    this.taxTotal = 0,
    required this.grandTotal,
    this.paidAmount = 0,
    this.notes,
    required this.date,
    required this.createdAt,
    this.bookId = '',
    this.deletedAt,
  });

  double get balanceDue => grandTotal - paidAmount;
  bool get isPaid => balanceDue <= 0;
  double get totalAmount => grandTotal;

  /// True when this bill is sitting in the Recycle Bin.
  bool get isDeleted => deletedAt != null;

  /// Days remaining before this bill is permanently purged from the
  /// Recycle Bin (30-day retention window, same as Khatabook).
  int get daysLeftInRecycleBin {
    if (deletedAt == null) return 30;
    final elapsed = DateTime.now().difference(deletedAt!).inDays;
    final left = 30 - elapsed;
    return left < 0 ? 0 : left;
  }

  String get paymentStatus {
    if (isPaid) return PaymentStatus.paid;
    if (paidAmount > 0) return PaymentStatus.partial;
    return PaymentStatus.unpaid;
  }

  Bill copyWith({
    String? id,
    String? billNumber,
    BillType? billType,
    BillStatus? status,
    String? partyId,
    String? partyName,
    List<BillItem>? items,
    double? subtotal,
    double? discountTotal,
    double? taxTotal,
    double? grandTotal,
    double? paidAmount,
    String? notes,
    DateTime? date,
    DateTime? createdAt,
    String? bookId,
    DateTime? deletedAt,
    // Pass clearDeletedAt: true to explicitly restore (set deletedAt → null)
    bool clearDeletedAt = false,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      billType: billType ?? this.billType,
      status: status ?? this.status,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountTotal: discountTotal ?? this.discountTotal,
      taxTotal: taxTotal ?? this.taxTotal,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      bookId: bookId ?? this.bookId,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'billNumber': billNumber,
        'billType': billType.name,
        'status': status.name,
        'partyId': partyId,
        'partyName': partyName,
        'subtotal': subtotal,
        'discountTotal': discountTotal,
        'taxTotal': taxTotal,
        'grandTotal': grandTotal,
        'paidAmount': paidAmount,
        'notes': notes,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'bookId': bookId,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  Map<String, dynamic> toJson() => toMap();

  factory Bill.fromMap(Map<String, dynamic> map, List<BillItem> items) {
    return Bill(
      id: map['id'] as String,
      billNumber: map['billNumber'] as String,
      billType: BillType.values.firstWhere(
        (e) => e.name == map['billType'],
        orElse: () => BillType.sale,
      ),
      status: BillStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BillStatus.draft,
      ),
      partyId: map['partyId'] as String?,
      partyName: map['partyName'] as String?,
      items: items,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountTotal: (map['discountTotal'] as num?)?.toDouble() ?? 0,
      taxTotal: (map['taxTotal'] as num?)?.toDouble() ?? 0,
      grandTotal: (map['grandTotal'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      bookId: (map['bookId'] as String?) ?? '',
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
    );
  }

  factory Bill.fromJson(Map<String, dynamic> json) => Bill.fromMap(json, []);
}

// ── MonthlyReport ─────────────────────────────────────────────────────────────
class MonthlyReport {
  final int year;
  final int month;
  final double totalCredit;
  final double totalDebit;
  final int transactionCount;

  const MonthlyReport({
    required this.year,
    required this.month,
    required this.totalCredit,
    required this.totalDebit,
    required this.transactionCount,
  });

  double get netBalance => totalDebit - totalCredit;
}
// ── Staff ─────────────────────────────────────────────────────────────────────
enum SalaryType { monthly, daily }

enum PartyPermissionLevel { none, viewAndRemind, addAndView, fullAccess }

enum AttendanceStatus { present, absent, halfDay, paidLeave }

extension AttendanceStatusX on AttendanceStatus {
  String get shortCode {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.halfDay:
        return 'H';
      case AttendanceStatus.paidLeave:
        return 'PL';
    }
  }

  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.paidLeave:
        return 'Paid Leave';
    }
  }

  /// Fraction of a day's pay this status earns.
  double get payMultiplier {
    switch (this) {
      case AttendanceStatus.present:
        return 1.0;
      case AttendanceStatus.paidLeave:
        return 1.0;
      case AttendanceStatus.halfDay:
        return 0.5;
      case AttendanceStatus.absent:
        return 0.0;
    }
  }
}

class Staff {
  final String id;
  final String name;
  final String phone;
  final SalaryType salaryType;
  final double salaryAmount;
  final DateTime salaryStartDate;
  final bool permissionsEnabled;
  final bool fullPermission;
  final PartyPermissionLevel partyPermission;
  final DateTime createdAt;
  final String bookId;

  const Staff({
    required this.id,
    required this.name,
    this.phone = '',
    this.salaryType = SalaryType.monthly,
    required this.salaryAmount,
    required this.salaryStartDate,
    this.permissionsEnabled = false,
    this.fullPermission = false,
    this.partyPermission = PartyPermissionLevel.none,
    required this.createdAt,
    this.bookId = '',
  });

  String get salaryTypeLabel =>
      salaryType == SalaryType.monthly ? 'Monthly Salary' : 'Daily Salary';

  Staff copyWith({
    String? id,
    String? name,
    String? phone,
    SalaryType? salaryType,
    double? salaryAmount,
    DateTime? salaryStartDate,
    bool? permissionsEnabled,
    bool? fullPermission,
    PartyPermissionLevel? partyPermission,
    DateTime? createdAt,
    String? bookId,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      salaryType: salaryType ?? this.salaryType,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      salaryStartDate: salaryStartDate ?? this.salaryStartDate,
      permissionsEnabled: permissionsEnabled ?? this.permissionsEnabled,
      fullPermission: fullPermission ?? this.fullPermission,
      partyPermission: partyPermission ?? this.partyPermission,
      createdAt: createdAt ?? this.createdAt,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'salaryType': salaryType.name,
        'salaryAmount': salaryAmount,
        'salaryStartDate': salaryStartDate.toIso8601String(),
        'permissionsEnabled': permissionsEnabled ? 1 : 0,
        'fullPermission': fullPermission ? 1 : 0,
        'partyPermission': partyPermission.name,
        'createdAt': createdAt.toIso8601String(),
        'bookId': bookId,
      };

  Map<String, dynamic> toJson() => toMap();

  factory Staff.fromMap(Map<String, dynamic> map) => Staff(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: (map['phone'] as String?) ?? '',
        salaryType: SalaryType.values.firstWhere(
          (e) => e.name == map['salaryType'],
          orElse: () => SalaryType.monthly,
        ),
        salaryAmount: (map['salaryAmount'] as num?)?.toDouble() ?? 0,
        salaryStartDate: DateTime.parse(map['salaryStartDate'] as String),
        permissionsEnabled: ((map['permissionsEnabled'] as int?) ?? 0) == 1,
        fullPermission: ((map['fullPermission'] as int?) ?? 0) == 1,
        partyPermission: PartyPermissionLevel.values.firstWhere(
          (e) => e.name == map['partyPermission'],
          orElse: () => PartyPermissionLevel.none,
        ),
        createdAt: DateTime.parse(map['createdAt'] as String),
        bookId: (map['bookId'] as String?) ?? '',
      );
}

class StaffAttendance {
  final String id;
  final String staffId;
  final DateTime date; // always stored normalized (time stripped)
  final AttendanceStatus status;
  final String bookId;

  const StaffAttendance({
    required this.id,
    required this.staffId,
    required this.date,
    required this.status,
    this.bookId = '',
  });

  static DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  StaffAttendance copyWith({
    String? id,
    String? staffId,
    DateTime? date,
    AttendanceStatus? status,
    String? bookId,
  }) {
    return StaffAttendance(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      status: status ?? this.status,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'staffId': staffId,
        'date': normalize(date).toIso8601String(),
        'status': status.name,
        'bookId': bookId,
      };

  factory StaffAttendance.fromMap(Map<String, dynamic> map) =>
      StaffAttendance(
        id: map['id'] as String,
        staffId: map['staffId'] as String,
        date: DateTime.parse(map['date'] as String),
        status: AttendanceStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => AttendanceStatus.present,
        ),
        bookId: (map['bookId'] as String?) ?? '',
      );
}