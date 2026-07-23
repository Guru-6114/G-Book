// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _bankAdded = false;
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  String get _profileId {
    final auth = context.read<AuthProvider>();
    return auth.profile?.id ?? '';
  }

  // Bank-account status still isn't a DB column (out of scope for this
  // migration), so it stays in SharedPreferences per-profile.
  Future<void> _loadExtras() async {
    final id = _profileId;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bankAdded = prefs.getBool('bank_account_$id') ?? false;
      _loadingExtras = false;
    });
  }

  Future<void> _saveBankAdded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bank_account_$_profileId', true);
    if (!mounted) return;
    setState(() => _bankAdded = true);
  }

  // ── Profile strength ────────────────────────────────────────────────────
  (double, String, Color) _strength(auth) {
    final profile = auth.profile;
    int filled = 0;
    const total = 9;

    if ((profile?.ownerName ?? '').isNotEmpty) filled++;
    if ((profile?.phone ?? '').isNotEmpty) filled++;
    if ((profile?.businessName ?? '').isNotEmpty) filled++;
    if ((profile?.email ?? '').isNotEmpty) filled++;
    if ((profile?.address ?? '').isNotEmpty) filled++;
    if ((profile?.category ?? '').isNotEmpty) filled++;
    if ((profile?.businessType ?? '').isNotEmpty) filled++;
    if ((profile?.gstin ?? '').isNotEmpty) filled++;
    if (_bankAdded) filled++;

    final pct = filled / total;
    if (pct >= 0.75) return (pct, 'Strong', const Color(0xFF2E7D32));
    if (pct >= 0.4) return (pct, 'Medium', const Color(0xFFF57C00));
    return (pct, 'Weak', const Color(0xFFD32F2F));
  }

  // ── Generic text-field edit dialog ──────────────────────────────────────
  Future<void> _editField({
    required String title,
    required String initialValue,
    required Future<bool> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter $title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    final ok = await onSave(result);
    if (!mounted) return;
    if (ok) {
      AppHelpers.showSuccessSnackBar(context, '$title updated');
      setState(() {});
    } else {
      AppHelpers.showErrorSnackBar(
        context,
        context.read<AuthProvider>().error ?? 'Update failed',
      );
    }
  }

  Future<void> _pickCategory() async {
    final auth = context.read<AuthProvider>();
    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _BusinessCategoryPickerScreen(current: auth.profile?.category),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await auth.updateBusiness({'category': picked});
    if (!mounted) return;
    if (ok) {
      AppHelpers.showSuccessSnackBar(context, 'Business category updated');
      setState(() {});
    } else {
      AppHelpers.showErrorSnackBar(context, auth.error ?? 'Update failed');
    }
  }

  Future<void> _pickBusinessType() async {
    final auth = context.read<AuthProvider>();
    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _BusinessTypePickerScreen(current: auth.profile?.businessType),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await auth.updateBusiness({'businessType': picked});
    if (!mounted) return;
    if (ok) {
      AppHelpers.showSuccessSnackBar(context, 'Business type updated');
      setState(() {});
    } else {
      AppHelpers.showErrorSnackBar(context, auth.error ?? 'Update failed');
    }
  }

  Future<void> _openBankAccount() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _BankAccountScreen()),
    );
    if (added == true) await _saveBankAdded();
  }

  Future<void> _pickStaffCount() async {
    final auth = context.read<AuthProvider>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StaffCountSheet(current: auth.profile?.staffCount),
    );
    if (picked == null || !mounted) return;
    final ok = await auth.updateBusiness({'staffCount': picked});
    if (!mounted) return;
    if (ok) {
      AppHelpers.showSuccessSnackBar(context, 'Staff count updated');
      setState(() {});
    } else {
      AppHelpers.showErrorSnackBar(context, auth.error ?? 'Update failed');
    }
  }

  void _confirmLogout() {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            child:
                const Text('Logout', style: TextStyle(color: AppTheme.debit)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    if (_loadingExtras) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final (pct, label, color) = _strength(auth);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: const Text('Book Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Avatar + Add photo ─────────────────────────────────────────
          const SizedBox(height: 24),
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Icon(Icons.person_outline,
                      size: 54, color: Colors.grey.shade400),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => AppHelpers.showSuccessSnackBar(
                        context, 'Photo upload coming soon'),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => AppHelpers.showSuccessSnackBar(
                  context, 'Photo upload coming soon'),
              child: const Text('Add photo'),
            ),
          ),

          // ── Profile strength bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Profile strength : ',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    const Spacer(),
                    Text('${(pct * 100).round()}%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.02, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Personal Info ────────────────────────────────────────────────
          _SectionHeader(title: 'Personal Info'),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Name',
            value: profile?.ownerName ?? '',
            onTap: () => _editField(
              title: 'Name',
              initialValue: profile?.ownerName ?? '',
              onSave: (v) => auth.updateProfile({'name': v}),
            ),
          ),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Registered number',
            value: profile?.phone ?? '',
          ),
          _InfoRow(
            icon: Icons.store_outlined,
            label: 'Business name',
            value: profile?.businessName ?? '',
            onTap: () => _editField(
              title: 'Business name',
              initialValue: profile?.businessName ?? '',
              onSave: (v) => auth.updateBusiness({'name': v}),
            ),
          ),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile?.email ?? '',
            emptyHint: 'Add Details',
            onTap: () => _editField(
              title: 'Email',
              initialValue: profile?.email ?? '',
              keyboardType: TextInputType.emailAddress,
              onSave: (v) => auth.updateProfile({'email': v}),
            ),
          ),

          const SizedBox(height: 10),

          // ── Business info ───────────────────────────────────────────────
          _SectionHeader(title: 'Business info'),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Business address',
            value: profile?.address ?? '',
            emptyHint: 'Add Details',
            onTap: () => _editField(
              title: 'Business address',
              initialValue: profile?.address ?? '',
              maxLines: 2,
              onSave: (v) => auth.updateProfile({'address': v}),
            ),
          ),
          _InfoRow(
            icon: Icons.category_outlined,
            label: 'Business Category',
            value: profile?.category ?? '',
            emptyHint: 'Add Details',
            onTap: _pickCategory,
          ),
          _InfoRow(
            icon: Icons.sell_outlined,
            label: 'Business Type',
            value: profile?.businessType ?? '',
            emptyHint: 'Add Details',
            onTap: _pickBusinessType,
          ),

          const SizedBox(height: 10),

          // ── Financial info ──────────────────────────────────────────────
          _SectionHeader(title: 'Financial info'),
          _InfoRow(
            icon: Icons.receipt_long_outlined,
            label: 'GSTIN',
            value: profile?.gstin ?? '',
            emptyHint: 'Add Details',
            onTap: () => _editField(
              title: 'GSTIN',
              initialValue: profile?.gstin ?? '',
              onSave: (v) => auth.updateBusiness({'gstin': v}),
            ),
          ),
          _InfoRow(
            icon: Icons.account_balance_outlined,
            label: 'Bank account',
            value: _bankAdded ? 'Added' : '',
            emptyHint: 'Add Details',
            onTap: _openBankAccount,
          ),

          const SizedBox(height: 10),

          // ── Staff info ───────────────────────────────────────────────────
          _SectionHeader(title: 'Staff info'),
          _InfoRow(
            icon: Icons.people_alt_outlined,
            label: 'Details',
            value: (profile?.staffCount != null)
                ? '${profile!.staffCount} staff'
                : '',
            emptyHint: 'Add Details',
            onTap: _pickStaffCount,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Info row (tap to edit / navigate) ────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? emptyHint;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emptyHint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim().isEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E))),
                  const SizedBox(height: 2),
                  Text(
                    isEmpty ? '' : value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF212121)),
                  ),
                ],
              ),
            ),
            if (isEmpty && emptyHint != null)
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(emptyHint!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.primaryColor)),
              )
            else if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 20, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}

// ── Business category picker ("What do you sell?") ──────────────────────
class _BusinessCategoryPickerScreen extends StatefulWidget {
  final String? current;
  const _BusinessCategoryPickerScreen({this.current});

  @override
  State<_BusinessCategoryPickerScreen> createState() =>
      _BusinessCategoryPickerScreenState();
}

class _BusinessCategoryPickerScreenState
    extends State<_BusinessCategoryPickerScreen> {
  String? _selected;

  static const _categories = [
    ('Kirana', Icons.shopping_basket, Color(0xFFD81B60)),
    ('Medical', Icons.medication_outlined, Color(0xFF2E7D32)),
    ('Apparel', Icons.checkroom_outlined, Color(0xFFF57C00)),
    ('Electronics', Icons.kitchen_outlined, Color(0xFF1565C0)),
    ('Mobile', Icons.phone_iphone, Color(0xFF212121)),
    ('Financial Services', Icons.account_balance_outlined, Color(0xFF1565C0)),
    ('Insurance', Icons.shield_outlined, Color(0xFF2E7D32)),
    ('Digital', Icons.laptop_mac, Color(0xFFF57C00)),
    ('Agriculture', Icons.eco_outlined, Color(0xFF2E7D32)),
    ('Education', Icons.school_outlined, Color(0xFFD81B60)),
    ('Computer', Icons.computer_outlined, Color(0xFF212121)),
    ('Tour & Travel', Icons.beach_access_outlined, Color(0xFFD81B60)),
    ('Other', Icons.storefront_outlined, Color(0xFF1565C0)),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What do you sell?')),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: _categories.map((c) {
                final isSelected = _selected == c.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selected = c.$1),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.06)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: c.$3,
                          child: Icon(c.$2, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c.$1,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                child: const Text('SAVE'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Business type picker ("What do you work as?") ───────────────────────
class _BusinessTypePickerScreen extends StatefulWidget {
  final String? current;
  const _BusinessTypePickerScreen({this.current});

  @override
  State<_BusinessTypePickerScreen> createState() =>
      _BusinessTypePickerScreenState();
}

class _BusinessTypePickerScreenState
    extends State<_BusinessTypePickerScreen> {
  String? _selected;

  static const _types = [
    ('Retailer / Shop', Icons.shopping_cart_outlined, Color(0xFFF57C00)),
    ('Wholesaler', Icons.inventory_2_outlined, Color(0xFF2E7D32)),
    ('Distributor', Icons.local_shipping_outlined, Color(0xFF1565C0)),
    ('Services', Icons.build_outlined, Color(0xFFD81B60)),
    ('Manufacturer', Icons.factory_outlined, Color(0xFF212121)),
    ('Other', Icons.storefront_outlined, Color(0xFF1565C0)),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What do you work as?')),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: _types.map((t) {
                final isSelected = _selected == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selected = t.$1),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.06)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: t.$3,
                          child: Icon(t.$2, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.$1,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                child: const Text('SAVE'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bank account screen ───────────────────────────────────────────────────
class _BankAccountScreen extends StatelessWidget {
  const _BankAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Account')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFEFEFEF),
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: const Icon(Icons.account_balance,
                size: 90, color: Color(0xFF2E7D32)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customers can now pay you online!',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const _BankStep(
                    icon: Icons.person_outline,
                    text: 'Select customer to receive payments from',
                  ),
                  const _BankStep(
                    icon: Icons.currency_rupee,
                    text: 'Enter the payment amount',
                  ),
                  const _BankStep(
                    icon: Icons.sms_outlined,
                    text: 'Send payment link for them to pay!',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        AppHelpers.showSuccessSnackBar(
                            context, 'Bank account added');
                        Navigator.pop(context, true);
                      },
                      child: const Text('ADD BANK ACCOUNT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BankStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

// ── Staff count bottom sheet ──────────────────────────────────────────────
class _StaffCountSheet extends StatefulWidget {
  final String? current;
  const _StaffCountSheet({this.current});

  @override
  State<_StaffCountSheet> createState() => _StaffCountSheetState();
}

class _StaffCountSheetState extends State<_StaffCountSheet> {
  String? _selected;

  static const _options = ['0', '1', '2', '3', '4', '5+'];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Number of staff working at your store?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _options.map((o) {
              final isSelected = _selected == o;
              return GestureDetector(
                onTap: () => setState(() => _selected = o),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey.shade400,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : Colors.white,
                  ),
                  child: Text(o,
                      style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : const Color(0xFF212121),
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: const Text('CONFIRM'),
            ),
          ),
        ],
      ),
    );
  }
}