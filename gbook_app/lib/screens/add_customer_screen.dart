// lib/screens/add_customer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/helpers.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;
  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;
  bool _loadingContacts = false;

  // Native method channel for contacts
  static const _contactsChannel = MethodChannel('gbook/contacts');

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.customer?.email ?? '');
    _addressCtrl =
        TextEditingController(text: widget.customer?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  /// Opens the native Android contacts picker. Falls back to a snackbar
  /// message if the platform channel is not yet implemented.
  Future<void> _pickFromContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final Map? result =
          await _contactsChannel.invokeMethod('pickContact');
      if (result != null && mounted) {
        setState(() {
          if ((result['name'] as String?)?.isNotEmpty == true) {
            _nameCtrl.text = result['name'] as String;
          }
          if ((result['phone'] as String?)?.isNotEmpty == true) {
            // Strip non-digits, keep last 10 digits for Indian numbers
            final raw =
                (result['phone'] as String).replaceAll(RegExp(r'\D'), '');
            _phoneCtrl.text =
                raw.length > 10 ? raw.substring(raw.length - 10) : raw;
          }
          if ((result['email'] as String?)?.isNotEmpty == true) {
            _emailCtrl.text = result['email'] as String;
          }
          if ((result['address'] as String?)?.isNotEmpty == true) {
            _addressCtrl.text = result['address'] as String;
          }
        });
      }
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        if (mounted) {
          AppHelpers.showErrorSnackBar(
              context, 'Contacts permission denied. Please allow in Settings.');
        }
      } else if (e.code == 'NOT_IMPLEMENTED') {
        // Channel not wired yet — show search sheet fallback
        if (mounted) _showContactSearchSheet();
      } else {
        // Any other error → open search fallback
        if (mounted) _showContactSearchSheet();
      }
    } catch (_) {
      if (mounted) _showContactSearchSheet();
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  /// Fallback: manual search sheet when native channel is unavailable
  void _showContactSearchSheet() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Enter Contact Details',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Native contacts picker not available on this device. '
                'Please enter details manually below.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: searchCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (searchCtrl.text.trim().isNotEmpty) {
                      _nameCtrl.text = searchCtrl.text.trim();
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Use This Name'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<CustomerProvider>();
    // ── BOOK SCOPING FIX: every customer must belong to the khatabook that
    // is active right now. Without this, customers were saved with an
    // empty bookId and ended up visible in every khatabook regardless of
    // which one was selected when they were created.
    final activeBookId = context.read<AuthProvider>().activeBookId;

    try {
      if (_isEdit) {
        final updated = widget.customer!.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          // Self-heal: if this customer predates book-scoping (bookId ==
          // ''), stamp it with the book it's currently being edited from.
          // If it already belongs to a book, leave it alone.
          bookId: widget.customer!.bookId.isNotEmpty
              ? widget.customer!.bookId
              : activeBookId,
        );
        await provider.updateCustomer(updated);
      } else {
        final customer = Customer(
          id: AppHelpers.generateId(),
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          createdAt: DateTime.now(),
          bookId: activeBookId,
        );
        await provider.addCustomer(customer);
      }

      if (!mounted) return;
      AppHelpers.showSuccessSnackBar(
          context, _isEdit ? 'Customer updated' : 'Customer added');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Customer' : 'Add Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Import from Contacts banner ───────────────────────────────
            if (!_isEdit)
              InkWell(
                onTap: _loadingContacts ? null : _pickFromContacts,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          shape: BoxShape.circle,
                        ),
                        child: _loadingContacts
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.contacts_outlined,
                                color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Import from Contacts',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1565C0)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Quickly add customer from your phone contacts',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF555555)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF1565C0), size: 22),
                    ],
                  ),
                ),
              ),
            if (!_isEdit) const SizedBox(height: 16),

            // ── OR divider ───────────────────────────────────────────────
            if (!_isEdit)
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR ADD MANUALLY',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            if (!_isEdit) const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        prefixIcon:
                            Icon(Icons.person_outline, size: 18),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon:
                            Icon(Icons.phone_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon:
                            Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address (optional)',
                        prefixIcon:
                            Icon(Icons.location_on_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEdit ? 'Update Customer' : 'Add Customer',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}