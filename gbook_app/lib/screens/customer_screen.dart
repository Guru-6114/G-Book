// lib/screens/customer_screen.dart
import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import '../services/statement_pdf_service.dart';
import '../services/messaging_service.dart';
import 'add_customer_screen.dart';

class CustomerScreen extends StatefulWidget {
  final Customer customer;
  const CustomerScreen({super.key, required this.customer});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Customer _customer;
  List<CustomerTransaction> _transactions = [];
  bool _loading = true;

  // FIX (double-entry bug, part 1 — UI layer):
  // The old code had NO guard on the bottom "Given"/"Received" buttons, so a
  // fast double-tap could call _showAddTransaction() twice before the first
  // bottom sheet finished opening, eventually resulting in two separate
  // transactions being saved for what the user experienced as one tap.
  // `_openingSheet` blocks a second call while one is already in progress.
  // (providers.dart also has a provider-level guard as defense in depth.)
  bool _openingSheet = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final list = await context
        .read<CustomerProvider>()
        .getTransactions(_customer.id);
    if (!mounted) return;
    setState(() {
      _transactions = list;
      _loading = false;
    });
  }

  void _deleteTransaction(String txId) async {
    await context
        .read<CustomerProvider>()
        .deleteTransaction(txId, _customer.id);
    if (!mounted) return;
    final provider = context.read<CustomerProvider>();
    final updated = provider.customers
        .firstWhere((c) => c.id == _customer.id, orElse: () => _customer);
    setState(() {
      _customer = updated;
      _transactions.removeWhere((t) => t.id == txId);
    });
    if (!mounted) return;
    AppHelpers.showSuccessSnackBar(context, 'Entry deleted');
  }

  Future<void> _showAddTransaction(bool isGiven) async {
    // FIX (double-entry bug): guard against re-entrancy. If a sheet is
    // already open/being opened, ignore this call instead of opening a
    // second one.
    if (_openingSheet) return;
    _openingSheet = true;

    CustomerTransaction? newTx;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _AddTransactionSheet(
          customer: _customer,
          isGiven: isGiven,
          onAdded: (tx) {
            newTx = tx;
          },
        ),
      );

      if (newTx != null && mounted) {
        await context.read<CustomerProvider>().addTransaction(newTx!);
        if (!mounted) return;
        final updated = context
            .read<CustomerProvider>()
            .customers
            .firstWhere((c) => c.id == _customer.id, orElse: () => _customer);
        setState(() {
          _customer = updated;
          _transactions.insert(0, newTx!);
        });
        AppHelpers.showSuccessSnackBar(context, 'Entry added');

        if (mounted) _showSmsSentPrompt(newTx!);
      }
    } finally {
      _openingSheet = false;
    }
  }

  void _showSmsSentPrompt(CustomerTransaction tx) {
    if (_customer.phone == null || _customer.phone!.isEmpty) {
      AppHelpers.showErrorSnackBar(
          context, 'No phone number for this customer');
      return;
    }
    final message =
        'Hi ${_customer.name}, ${tx.isGiven ? "You have received" : "You have paid"} '
        '${AppHelpers.formatCurrency(tx.amount)}. '
        'Balance: ${AppHelpers.formatCurrency(_customer.balance.abs())}. '
        '- via GBook';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send transaction details to customer automatically?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendSmsAuto(_customer.phone!, message);
            },
            child: const Text('Send SMS'),
          ),
        ],
      ),
    );
  }

  /// FIX (SMS): sends the SMS automatically (no Messages app, no manual tap)
  /// using MessagingService, which talks to a native SmsManager channel.
  /// Falls back to opening the Messages app pre-filled if automatic sending
  /// isn't possible on this device/permission state, so the user is never
  /// left with nothing happening.
  Future<void> _sendSmsAuto(String phone, String message) async {
    final result = await MessagingService.sendSmsAutomatically(
      phone: phone,
      message: message,
    );
    if (!mounted) return;
    switch (result) {
      case SmsResult.sent:
        AppHelpers.showSuccessSnackBar(context, 'SMS sent');
        break;
      case SmsResult.permissionDenied:
        AppHelpers.showErrorSnackBar(
            context, 'SMS permission denied — opening Messages app instead');
        await MessagingService.sendSmsViaIntent(phone: phone, message: message);
        break;
      case SmsResult.unsupportedPlatform:
      case SmsResult.failed:
        AppHelpers.showErrorSnackBar(
            context, 'Could not send automatically — opening Messages app');
        await MessagingService.sendSmsViaIntent(phone: phone, message: message);
        break;
    }
  }

  /// FIX (WhatsApp): correctly detects whether WhatsApp is installed (via
  /// the `whatsapp://` scheme, not the unreliable `https://wa.me` link) and
  /// reports the real outcome instead of always saying "shared" then
  /// failing afterward.
  Future<void> _sendWhatsApp(String message) async {
    if (_customer.phone == null || _customer.phone!.isEmpty) {
      AppHelpers.showErrorSnackBar(
          context, 'No phone number for this customer');
      return;
    }
    final result = await MessagingService.sendWhatsApp(
      phone: _customer.phone!,
      message: message,
    );
    if (!mounted) return;
    switch (result) {
      case WhatsAppResult.sent:
        break; // WhatsApp itself opens; nothing more to show.
      case WhatsAppResult.notInstalled:
        AppHelpers.showErrorSnackBar(context, 'WhatsApp is not installed');
        break;
      case WhatsAppResult.failed:
        AppHelpers.showErrorSnackBar(context, 'Could not open WhatsApp');
        break;
    }
  }

  void _showReminderDialog() {
    final msgCtrl = TextEditingController(
      text: 'Hi ${_customer.name}, you have a pending balance of '
          '${AppHelpers.formatCurrency(_customer.balance.abs())}. '
          'Please clear it at the earliest. Thank you! - GBook',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reminder Message',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _sendWhatsApp(msgCtrl.text);
            },
            icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
            label: const Text('WhatsApp',
                style: TextStyle(color: Color(0xFF25D366))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF25D366)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final phone = _customer.phone ?? '';
              Navigator.pop(ctx);
              if (phone.isNotEmpty) {
                _sendSmsAuto(phone, msgCtrl.text);
              } else {
                AppHelpers.showErrorSnackBar(context, 'No phone number');
              }
            },
            icon: const Icon(Icons.sms, size: 16),
            label: const Text('Send SMS'),
          ),
        ],
      ),
    );
  }

  void _showReportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  const Text('Reports',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: Color(0xFF1565C0)),
              title: const Text('Download PDF Report'),
              subtitle: const Text('Get full transaction history as PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _openPartyReport();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_outlined, color: Color(0xFF25D366)),
              title: const Text('Share Report via WhatsApp'),
              subtitle: const Text('Send PDF to customer on WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _openPartyReportAndShare();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Statement of Account'),
              subtitle: const Text('View full ledger summary'),
              onTap: () {
                Navigator.pop(ctx);
                _showStatementDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openPartyReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CustomerPartyReportScreen(
          customer: _customer,
          transactions: _transactions,
        ),
      ),
    );
  }

  void _openPartyReportAndShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CustomerPartyReportScreen(
          customer: _customer,
          transactions: _transactions,
          autoShare: true,
        ),
      ),
    );
  }

  void _showStatementDialog() {
    double totalGiven =
        _transactions.where((t) => t.isGiven).fold(0.0, (s, t) => s + t.amount);
    double totalReceived = _transactions
        .where((t) => !t.isGiven)
        .fold(0.0, (s, t) => s + t.amount);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Statement — ${_customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatRow('Total Given', AppHelpers.formatCurrency(totalGiven),
                AppTheme.debitColor),
            _StatRow('Total Received',
                AppHelpers.formatCurrency(totalReceived), AppTheme.creditColor),
            const Divider(),
            _StatRow(
              'Balance',
              AppHelpers.formatCurrency(_customer.balance.abs()),
              _customer.balance >= 0
                  ? AppTheme.creditColor
                  : AppTheme.debitColor,
            ),
            const SizedBox(height: 8),
            Text(
              _customer.balance >= 0
                  ? 'Customer will give ↑'
                  : 'Customer will get ↓',
              style: TextStyle(
                fontSize: 13,
                color: _customer.balance >= 0
                    ? AppTheme.creditColor
                    : AppTheme.debitColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete ${_customer.name} and all their transactions?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CustomerProvider>().deleteCustomer(_customer.id);
      if (!mounted) return;
      AppHelpers.showSuccessSnackBar(context, 'Customer deleted');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _customer.balance;
    final isPositive = balance >= 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Send Reminder',
            onPressed: _showReminderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Reports',
            onPressed: _showReportOptions,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddCustomerScreen(customer: _customer)),
                );
                if (result == true && mounted) {
                  final updated = context
                      .read<CustomerProvider>()
                      .customers
                      .firstWhere((c) => c.id == _customer.id,
                          orElse: () => _customer);
                  setState(() => _customer = updated);
                }
              } else if (v == 'delete') {
                _deleteCustomer();
              } else if (v == 'sms') {
                final message =
                    'Hi ${_customer.name}, your balance is ${AppHelpers.formatCurrency(_customer.balance.abs())}. - GBook';
                if (_customer.phone != null && _customer.phone!.isNotEmpty) {
                  _sendSmsAuto(_customer.phone!, message);
                } else {
                  AppHelpers.showErrorSnackBar(context, 'No phone number');
                }
              } else if (v == 'whatsapp') {
                final message =
                    'Hi ${_customer.name}, your balance is ${AppHelpers.formatCurrency(_customer.balance.abs())}. - GBook';
                _sendWhatsApp(message);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit')
                  ])),
              PopupMenuItem(
                  value: 'sms',
                  child: Row(children: [
                    Icon(Icons.sms_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Send SMS')
                  ])),
              PopupMenuItem(
                  value: 'whatsapp',
                  child: Row(children: [
                    Icon(Icons.chat_outlined,
                        size: 18, color: Color(0xFF25D366)),
                    SizedBox(width: 8),
                    Text('WhatsApp')
                  ])),
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red))
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance banner
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    AppHelpers.initials(_customer.name),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customer.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      if (_customer.phone != null)
                        Text(_customer.phone!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isPositive ? 'Will Give' : 'Will Get',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      AppHelpers.formatCurrency(balance.abs()),
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF90EE90),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick action row: Report | Reminder | SMS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Report',
                  color: const Color(0xFF1565C0),
                  onTap: _showReportOptions,
                ),
                const SizedBox(width: 8),
                _QuickActionBtn(
                  icon: Icons.notifications_outlined,
                  label: 'Reminder',
                  color: const Color(0xFFE65100),
                  onTap: _showReminderDialog,
                ),
                const SizedBox(width: 8),
                _QuickActionBtn(
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  color: const Color(0xFF2E7D32),
                  onTap: () {
                    final msg =
                        'Hi ${_customer.name}, your balance is ${AppHelpers.formatCurrency(_customer.balance.abs())}. - GBook';
                    if (_customer.phone != null &&
                        _customer.phone!.isNotEmpty) {
                      _sendSmsAuto(_customer.phone!, msg);
                    } else {
                      AppHelpers.showErrorSnackBar(
                          context, 'No phone number for this customer');
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transactions list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? EmptyState(
                        title: 'No transactions yet',
                        subtitle:
                            'Add a payment or credit entry to get started',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: 'Add Entry',
                        onAction: () => _showAddTransaction(false),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 70),
                        itemBuilder: (_, i) {
                          final tx = _transactions[i];
                          return TransactionTile(
                            id: tx.id,
                            amount: tx.amount,
                            isGiven: tx.isGiven,
                            note: tx.note,
                            date: tx.date,
                            paymentMode: tx.paymentMode,
                            onDelete: () => _deleteTransaction(tx.id),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.debitColor),
                  // FIX (double-entry): _showAddTransaction now ignores a
                  // re-entrant call while a sheet is already opening, so a
                  // fast double-tap here can no longer open two sheets.
                  onPressed: () => _showAddTransaction(true),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Given'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditColor),
                  onPressed: () => _showAddTransaction(false),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: const Text('Received'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Customer Party Report Screen ──────────────────────────────────────────────
class _CustomerPartyReportScreen extends StatefulWidget {
  final Customer customer;
  final List<CustomerTransaction> transactions;
  final bool autoShare;

  const _CustomerPartyReportScreen({
    required this.customer,
    required this.transactions,
    this.autoShare = false,
  });

  @override
  State<_CustomerPartyReportScreen> createState() =>
      _CustomerPartyReportScreenState();
}

class _CustomerPartyReportScreenState
    extends State<_CustomerPartyReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDownloading = false;
  bool _isSharing = false;

  List<CustomerTransaction> get _filtered {
    return widget.transactions.where((t) {
      if (_startDate != null && t.date.isBefore(_startDate!)) return false;
      if (_endDate != null &&
          t.date.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get _totalGiven =>
      _filtered.where((t) => t.isGiven).fold(0.0, (s, t) => s + t.amount);
  double get _totalReceived =>
      _filtered.where((t) => !t.isGiven).fold(0.0, (s, t) => s + t.amount);

  @override
  void initState() {
    super.initState();
    if (widget.autoShare) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _share());
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  List<StatementRow> _buildRows() {
    return _filtered
        .map((t) => StatementRow(
              date: t.date,
              youGave: t.isGiven ? t.amount : 0,
              youGot: !t.isGiven ? t.amount : 0,
              paymentMode: t.paymentMode,
              note: t.note,
            ))
        .toList();
  }

  Future<List<int>> _generatePdfBytes() async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    return StatementPdfService.buildPdf(
      businessName: profile?.businessName ?? 'My Business',
      businessAddress: profile?.address,
      businessPhone: profile?.phone,
      partyName: widget.customer.name,
      partyPhone: widget.customer.phone,
      netBalance: widget.customer.balance,
      partyWillGive: widget.customer.balance < 0, // they will get -> we owe? keep consistent with UI label below
      rows: _buildRows(),
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  /// FIX: actually generates and opens a real PDF file (instead of just
  /// sending a wa.me text link and claiming success).
  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await _generatePdfBytes();
      final path = await StatementPdfService.downloadPdf(
        bytes: bytes,
        partyName: widget.customer.name,
      );
      if (mounted) {
        AppHelpers.showSuccessSnackBar(
            context, 'PDF saved: ${path.split('/').last}');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to generate PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// FIX: shares the real PDF via the OS share sheet (Share.shareXFiles),
  /// which always works and lets the user choose WhatsApp, email, etc. This
  /// replaces the old wa.me link approach that could falsely report success.
  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _generatePdfBytes();
      await StatementPdfService.sharePdf(
        bytes: bytes,
        partyName: widget.customer.name,
        captionText:
            'Account statement for ${widget.customer.name} — via GBook',
      );
      if (mounted) {
        AppHelpers.showSuccessSnackBar(context, 'Report shared!');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to share: $e');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Report of ${widget.customer.name}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
      ),
      body: Column(
        children: [
          // Date filter
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: _startDate != null
                        ? AppHelpers.formatDate(_startDate!)
                        : 'START DATE',
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateChip(
                    label: _endDate != null
                        ? AppHelpers.formatDate(_endDate!)
                        : 'END DATE',
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
          ),

          // Summary
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Balance',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'Rs. ${widget.customer.balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: widget.customer.balance >= 0
                          ? const Color(0xFF00796B)
                          : const Color(0xFFB71C1C)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('${rows.length} Entries',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('You Gave: Rs. ${_totalGiven.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB71C1C))),
                const SizedBox(width: 12),
                Text('You Got: Rs. ${_totalReceived.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF00796B))),
              ],
            ),
          ),
          const Divider(height: 1),

          // Column headers
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Date',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('You Gave',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('You Got',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text('No entries found',
                        style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = rows[i];
                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppHelpers.formatDate(t.date),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF212121))),
                                  if (t.note != null && t.note!.isNotEmpty)
                                    Text(t.note!,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9E9E9E))),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: const Color(0xFFE0E0E0)),
                                    ),
                                    child: Text(t.paymentMode.toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF757575))),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                t.isGiven
                                    ? 'Rs. ${t.amount.toStringAsFixed(2)}'
                                    : '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Color(0xFFB71C1C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                !t.isGiven
                                    ? 'Rs. ${t.amount.toStringAsFixed(2)}'
                                    : '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Color(0xFF00796B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom actions
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _download,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_outlined,
                            color: Color(0xFF1565C0)),
                    label: Text(_isDownloading ? 'PREPARING...' : 'DOWNLOAD',
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share, color: Colors.white),
                    label: Text(_isSharing ? 'SHARING...' : 'SHARE PDF',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF1565C0)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Add Transaction Bottom Sheet ──────────────────────────────────────────────
class _AddTransactionSheet extends StatefulWidget {
  final Customer customer;
  final bool isGiven;
  final void Function(CustomerTransaction) onAdded;

  const _AddTransactionSheet({
    required this.customer,
    required this.isGiven,
    required this.onAdded,
  });

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _paymentMode = 'cash';
  final _date = DateTime.now();
   // FIX (double-entry, sheet-level guard): prevents the Save button from
  // running its logic twice if it's tapped rapidly before the widget tree
  // rebuilds with the button disabled.
  bool _submitted = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Enter a valid amount');
      return;
    }
    setState(() => _submitted = true);
    final tx = CustomerTransaction(
      id: AppHelpers.generateId(),
      customerId: widget.customer.id,
      amount: amount,
      isGiven: widget.isGiven,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      paymentMode: _paymentMode,
      date: _date,
    );
    widget.onAdded(tx);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isGiven = widget.isGiven;
    final color = isGiven ? AppTheme.debitColor : AppTheme.creditColor;
    final label = isGiven ? 'Amount Given' : 'Amount Received';

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const Spacer(),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'Rs. ',
              prefixStyle: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color),
              hintText: '0.00',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.note_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          PaymentModeSelector(
            selected: _paymentMode,
            onChanged: (m) => setState(() => _paymentMode = m),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              // FIX (double-entry): button is now actually disabled (via
              // setState above) the instant Save is tapped, instead of only
              // setting a flag that nothing re-checked visually.
              onPressed: _submitted ? null : _submit,
              child: _submitted
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Entry',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}