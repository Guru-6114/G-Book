// lib/screens/staff_permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class StaffPermissionsScreen extends StatefulWidget {
  final Staff? existing;
  final String? prefillName;
  final String? prefillPhone;

  const StaffPermissionsScreen({
    super.key,
    this.existing,
    this.prefillName,
    this.prefillPhone,
  });

  @override
  State<StaffPermissionsScreen> createState() =>
      _StaffPermissionsScreenState();
}

class _StaffPermissionsScreenState extends State<StaffPermissionsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _salaryCtrl;

  bool _attendanceSalaryEnabled = true;
  DateTime _salaryStartDate = DateTime.now();
  SalaryType _salaryType = SalaryType.monthly;

  bool _permissionsEnabled = true;
  bool _fullPermission = false;
  PartyPermissionLevel _partyPermission = PartyPermissionLevel.none;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  static const List<({PartyPermissionLevel level, String label})>
      _permissionOptions = [
    (level: PartyPermissionLevel.viewAndRemind, label: 'View Entries & Send Reminders'),
    (level: PartyPermissionLevel.addAndView, label: 'Add & View: Entries/Parties'),
    (level: PartyPermissionLevel.fullAccess, label: 'Add, View, Edit, Delete: Entries/Parties'),
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    // FIX: fall back to prefillName/prefillPhone (passed in from the
    // contact picker) when there's no existing staff record being edited.
    _nameCtrl = TextEditingController(
        text: s?.name ?? widget.prefillName ?? '');
    _phoneCtrl = TextEditingController(
        text: s?.phone ?? widget.prefillPhone ?? '');
    _salaryCtrl = TextEditingController(
        text: s != null && s.salaryAmount > 0
            ? s.salaryAmount.toStringAsFixed(0)
            : '');
    if (s != null) {
      _salaryStartDate = s.salaryStartDate;
      _salaryType = s.salaryType;
      _permissionsEnabled = s.permissionsEnabled;
      _fullPermission = s.fullPermission;
      _partyPermission = s.partyPermission;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  String get _displayName =>
      _nameCtrl.text.trim().isEmpty ? 'Staff' : _nameCtrl.text.trim();

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _salaryStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _salaryStartDate = picked);
  }

  Future<void> _pickPartyPermission() async {
    final result = await showModalBottomSheet<PartyPermissionLevel>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        PartyPermissionLevel selected = _partyPermission;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined,
                          color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Parties',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('Select permissions for $_displayName',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ..._permissionOptions.map((opt) {
                    return RadioListTile<PartyPermissionLevel>(
                      value: opt.level,
                      groupValue: selected,
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text(opt.label, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => selected = v);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('GOT IT'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result != null) setState(() => _partyPermission = result);
  }

  String get _partyPermissionLabel {
    switch (_partyPermission) {
      case PartyPermissionLevel.none:
        return 'NONE';
      case PartyPermissionLevel.viewAndRemind:
        return 'VIEW & REMIND';
      case PartyPermissionLevel.addAndView:
        return 'ADD & VIEW';
      case PartyPermissionLevel.fullAccess:
        return 'FULL ACCESS';
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppHelpers.showErrorSnackBar(context, 'Staff name is required');
      return;
    }
    final salary = double.tryParse(_salaryCtrl.text.trim()) ?? 0;
    if (_attendanceSalaryEnabled && salary <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Enter a valid salary amount');
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final provider = context.read<StaffProvider>();

    final staff = Staff(
      id: widget.existing?.id ?? AppHelpers.generateId(),
      name: name,
      phone: _phoneCtrl.text.trim(),
      salaryType: _salaryType,
      salaryAmount: _attendanceSalaryEnabled ? salary : 0,
      salaryStartDate: _salaryStartDate,
      permissionsEnabled: _permissionsEnabled,
      fullPermission: _fullPermission,
      partyPermission:
          _fullPermission ? PartyPermissionLevel.fullAccess : _partyPermission,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      bookId: auth.activeBookId,
    );

    try {
      if (_isEditing) {
        await provider.updateStaff(staff);
        if (!mounted) return;
        AppHelpers.showSuccessSnackBar(context, 'Staff details updated');
        Navigator.pop(context, true);
      } else {
        await provider.addStaff(staff);
        if (!mounted) return;
        await _showSuccessDialog(staff);
      }
    } catch (e) {
      if (mounted) AppHelpers.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSuccessDialog(Staff staff) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 44),
              const SizedBox(height: 14),
              Text('${staff.name} added successfully!',
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                "Now you can manage ${staff.name}'s attendance and salary payments",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Next steps for ${staff.name}',
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 10),
              _NextStepRow(
                number: '1',
                text: 'Ask ${staff.name} to install the GBook app & Login',
              ),
              const SizedBox(height: 8),
              _NextStepRow(
                number: '2',
                text:
                    'They will be able to see your business and take actions as per the given permissions',
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('OKAY'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff and Permissions'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Staff Name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ToggleSection(
            icon: Icons.badge_outlined,
            title: 'Attendance & Salary',
            subtitle: 'Manage attendance & salary',
            value: _attendanceSalaryEnabled,
            onChanged: (v) => setState(() => _attendanceSalaryEnabled = v),
          ),
          if (_attendanceSalaryEnabled)
            Container(
              color: const Color(0xFFF6F7FB),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SALARY CALCULATION START DATE',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 10),
                            Text(AppHelpers.formatDate(_salaryStartDate)),
                          ]),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('SALARY TYPE',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SalaryTypeCard(
                          label: 'Monthly',
                          subtitle: '$_displayName gets monthly salary',
                          selected: _salaryType == SalaryType.monthly,
                          onTap: () =>
                              setState(() => _salaryType = SalaryType.monthly),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SalaryTypeCard(
                          label: 'Daily',
                          subtitle: '$_displayName gets daily salary',
                          selected: _salaryType == SalaryType.daily,
                          onTap: () =>
                              setState(() => _salaryType = SalaryType.daily),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _salaryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_rupee, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Enter amount',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _ToggleSection(
            icon: Icons.description_outlined,
            title: 'Permissions',
            subtitle:
                'Permissions for $_displayName to manage your business on GBook',
            value: _permissionsEnabled,
            onChanged: (v) => setState(() => _permissionsEnabled = v),
          ),
          if (_permissionsEnabled) ...[
            Container(
              color: const Color(0xFFF6F7FB),
              child: CheckboxListTile(
                value: _fullPermission,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Give full permission to $_displayName'),
                onChanged: (v) => setState(() => _fullPermission = v ?? false),
              ),
            ),
            if (!_fullPermission)
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Parties'),
                subtitle: const Text(
                    'Allow staff to manage entries and view reports'),
                trailing: OutlinedButton(
                  onPressed: _pickPartyPermission,
                  child: Text(_partyPermissionLabel),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('SAVE',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ToggleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        activeThumbColor: AppTheme.primaryColor,
        onChanged: onChanged,
      ),
    );
  }
}

class _SalaryTypeCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SalaryTypeCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(
                        color:
                            selected ? AppTheme.primaryColor : Colors.black87,
                        fontWeight: FontWeight.w600)),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? AppTheme.primaryColor : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _NextStepRow extends StatelessWidget {
  final String number;
  final String text;

  const _NextStepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Colors.green,
          child: Text(number,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}