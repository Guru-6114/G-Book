// lib/screens/add_party_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/helpers.dart';

class AddPartyScreen extends StatefulWidget {
  final bool isSupplier;
  final Customer? existing;
  final Supplier? existingSupplier;

  const AddPartyScreen({
    super.key,
    required this.isSupplier,
    this.existing,
    this.existingSupplier,
  });

  @override
  State<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;
  bool _loadingContacts = false;

  static const _contactsChannel = MethodChannel('gbook/contacts');

  bool get isEditing =>
      widget.existing != null || widget.existingSupplier != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.existing?.name ??
            widget.existingSupplier?.name ??
            '');
    _phoneCtrl = TextEditingController(
        text: widget.existing?.phone ??
            widget.existingSupplier?.phone ??
            '');
    _emailCtrl = TextEditingController(
        text: widget.existing?.email ??
            widget.existingSupplier?.email ??
            '');
    _addressCtrl = TextEditingController(
        text: widget.existing?.address ??
            widget.existingSupplier?.address ??
            '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

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
      } else {
        if (mounted) _showFallbackSheet();
      }
    } catch (_) {
      if (mounted) _showFallbackSheet();
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _showFallbackSheet() {
    final searchCtrl = TextEditingController();
    final label = widget.isSupplier ? 'Supplier' : 'Customer';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Enter $label Name',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Native contacts not available. Enter details manually.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: '$label Name',
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
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      // ── BOOK SCOPING FIX: stamp every new/edited party with the khatabook
      // that is currently active. Without this, parties saved with an
      // empty bookId leaked into every khatabook instead of staying scoped
      // to the one they were created in.
      final activeBookId = context.read<AuthProvider>().activeBookId;

      if (widget.isSupplier) {
        final provider = context.read<SupplierProvider>();
        if (isEditing && widget.existingSupplier != null) {
          await provider.updateSupplier(widget.existingSupplier!.copyWith(
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
            // Self-heal: keep existing bookId if already set, otherwise
            // stamp with the active book.
            bookId: widget.existingSupplier!.bookId.isNotEmpty
                ? widget.existingSupplier!.bookId
                : activeBookId,
          ));
        } else {
          await provider.addSupplier(Supplier(
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
            createdAt: now,
            bookId: activeBookId,
          ));
        }
      } else {
        final provider = context.read<CustomerProvider>();
        if (isEditing && widget.existing != null) {
          await provider.updateCustomer(widget.existing!.copyWith(
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
            bookId: widget.existing!.bookId.isNotEmpty
                ? widget.existing!.bookId
                : activeBookId,
          ));
        } else {
          await provider.addCustomer(Customer(
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
            createdAt: now,
            bookId: activeBookId,
          ));
        }
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEditing
        ? 'Edit ${widget.isSupplier ? "Supplier" : "Customer"}'
        : 'Add ${widget.isSupplier ? "Supplier" : "Customer"}';
    final accentColor =
        widget.isSupplier ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Import from Contacts ──────────────────────────────────────
            if (!isEditing)
              InkWell(
                onTap: _loadingContacts ? null : _pickFromContacts,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accentColor,
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
                          children: [
                            Text(
                              'Import from Contacts',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: accentColor),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Quickly add from your phone contacts',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF555555)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: accentColor, size: 22),
                    ],
                  ),
                ),
              ),
            if (!isEditing) const SizedBox(height: 16),

            if (!isEditing)
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
            if (!isEditing) const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Details',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText:
                            '${widget.isSupplier ? "Supplier" : "Customer"} Name *',
                        prefixIcon:
                            const Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
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
                        labelText: 'Email',
                        prefixIcon:
                            Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Address',
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
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'UPDATE' : 'SAVE',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}