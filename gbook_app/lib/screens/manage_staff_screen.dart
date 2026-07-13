// lib/screens/manage_staff_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'staff_permissions_screen.dart';
import 'staff_contact_picker_screen.dart'; // NEW — contacts-synced staff picker

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

enum _StaffFilter { all, salaryAndAttendance, permissionGiven }

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _StaffFilter _filter = _StaffFilter.all;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      context.read<StaffProvider>().loadStaff(bookId: auth.activeBookId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Staff> _applyFilter(List<Staff> staff) {
    var list = staff.where((s) =>
        _query.isEmpty || s.name.toLowerCase().contains(_query.toLowerCase()));
    switch (_filter) {
      case _StaffFilter.all:
        break;
      case _StaffFilter.salaryAndAttendance:
        list = list.where((s) => s.salaryAmount > 0);
        break;
      case _StaffFilter.permissionGiven:
        list = list.where((s) =>
            s.permissionsEnabled &&
            (s.fullPermission || s.partyPermission != PartyPermissionLevel.none));
        break;
    }
    return list.toList();
  }

  // FIX: This is now the single entry point for "ADD STAFF" — it opens the
  // Khatabook-style contacts picker (StaffContactPickerScreen) instead of
  // jumping straight into the manual StaffPermissionsScreen form. The
  // picker itself still lets the user tap "Add New Staff" to reach the
  // manual form if they don't want to pick from contacts.
  Future<void> _openAddStaffFlow() async {
    final auth = context.read<AuthProvider>();
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StaffContactPickerScreen()),
    );
    if (added == true && mounted) {
      context.read<StaffProvider>().loadStaff(bookId: auth.activeBookId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaffProvider>();
    final staffList = _applyFilter(provider.staff);
    final totalDue =
        provider.staff.fold(0.0, (sum, s) => sum + provider.dueFor(s));
    final counts = provider.attendanceSummaryFor(_today);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Manage Staff'),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Due',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              AppHelpers.formatCurrency(totalDue),
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text('for ${provider.staff.length} staff',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Attendance - ${AppHelpers.formatDate(_today)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Row(children: [
                            _CountChip(
                                label: 'P',
                                count: counts[AttendanceStatus.present] ?? 0,
                                color: Colors.green),
                            const SizedBox(width: 8),
                            _CountChip(
                                label: 'A',
                                count: counts[AttendanceStatus.absent] ?? 0,
                                color: Colors.red),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            _CountChip(
                                label: 'H',
                                count: counts[AttendanceStatus.halfDay] ?? 0,
                                color: Colors.orange),
                            const SizedBox(width: 8),
                            _CountChip(
                                label: 'PL',
                                count: counts[AttendanceStatus.paidLeave] ?? 0,
                                color: Colors.grey),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search Staff',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.filter_list, size: 18),
                        label: const Text('Filters'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == _StaffFilter.all,
                          onTap: () =>
                              setState(() => _filter = _StaffFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Salary & Attendance Added',
                          selected:
                              _filter == _StaffFilter.salaryAndAttendance,
                          onTap: () => setState(() =>
                              _filter = _StaffFilter.salaryAndAttendance),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Permission Given',
                          selected: _filter == _StaffFilter.permissionGiven,
                          onTap: () => setState(
                              () => _filter = _StaffFilter.permissionGiven),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: staffList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_alt_outlined,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                provider.staff.isEmpty
                                    ? 'No staff added yet'
                                    : 'No staff match this filter',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: staffList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _StaffTile(staff: staffList[i], date: _today),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF9C1B45),
        onPressed: _openAddStaffFlow, // FIX: now opens the contact picker
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('ADD STAFF'),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: count > 0 ? color : Colors.black87)),
        const SizedBox(width: 3),
        CircleAvatar(
          radius: 9,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.primaryColor : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final Staff staff;
  final DateTime date;

  const _StaffTile({required this.staff, required this.date});

  String _permissionLabel(Staff s) {
    if (!s.permissionsEnabled) return 'No Permission';
    if (s.fullPermission) return 'Full Permission';
    switch (s.partyPermission) {
      case PartyPermissionLevel.none:
        return 'No Permission';
      case PartyPermissionLevel.viewAndRemind:
        return 'Party (View)';
      case PartyPermissionLevel.addAndView:
        return 'Party (Add & View)';
      case PartyPermissionLevel.fullAccess:
        return 'Party (Full)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, _) {
        final due = provider.dueFor(staff);
        final current = provider.attendanceOn(staff.id, date)?.status;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppHelpers.getAvatarColor(staff.name),
                    child: Text(
                      AppHelpers.initials(staff.name),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            // Editing an existing staff member always goes
                            // straight to the manual form — you're editing
                            // details, not picking a new contact.
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      StaffPermissionsScreen(existing: staff)),
                            );
                            if (result == true) {
                              final auth = context.read<AuthProvider>();
                              provider.loadStaff(bookId: auth.activeBookId);
                            }
                          },
                          child: Text(staff.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        Text(staff.salaryTypeLabel,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(
                    AppHelpers.formatCurrency(due),
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PERMISSIONS',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_permissionLabel(staff),
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("TODAY'S ATTENDANCE",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 6),
                      _AttendanceDropdown(
                        value: current,
                        onChanged: (status) {
                          final auth = context.read<AuthProvider>();
                          provider.markAttendance(staff.id, date, status,
                              bookId: auth.activeBookId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendanceDropdown extends StatelessWidget {
  final AttendanceStatus? value;
  final ValueChanged<AttendanceStatus> onChanged;

  const _AttendanceDropdown({required this.value, required this.onChanged});

  Color _colorFor(AttendanceStatus? s) {
    switch (s) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.halfDay:
        return Colors.orange;
      case AttendanceStatus.paidLeave:
        return Colors.grey;
      case null:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AttendanceStatus>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          hint: const Text('Mark', style: TextStyle(fontSize: 13)),
          items: AttendanceStatus.values.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration:
                        BoxDecoration(color: _colorFor(s), shape: BoxShape.circle),
                  ),
                  Text(s.label, style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (s) {
            if (s != null) onChanged(s);
          },
        ),
      ),
    );
  }
}