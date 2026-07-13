// lib/screens/staff_contact_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../theme/app_theme.dart';
import 'staff_permissions_screen.dart';

class StaffContactPickerScreen extends StatefulWidget {
  const StaffContactPickerScreen({super.key});

  @override
  State<StaffContactPickerScreen> createState() =>
      _StaffContactPickerScreenState();
}

class _StaffContactPickerScreenState extends State<StaffContactPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _permissionDenied = false;
  String _query = '';

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];

  static const double _rowHeight = 78;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final withPhones = contacts
          .where((c) => c.phones.isNotEmpty && c.displayName.trim().isNotEmpty)
          .toList();

      withPhones.sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _allContacts = withPhones;
        _filteredContacts = withPhones;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      if (value.trim().isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        final q = value.trim().toLowerCase();
        _filteredContacts = _allContacts
            .where((c) =>
                c.displayName.toLowerCase().contains(q) ||
                c.phones.any((p) => p.number.contains(q)))
            .toList();
      }
    });
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _avatarColorFor(String name) {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF0D47A1),
      Color(0xFF283593),
      Color(0xFF00695C),
      Color(0xFF1A6B3C),
      Color(0xFF37474F),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.hashCode.abs() % colors.length];
  }

  List<String> get _availableLetters {
    final seen = <String>{};
    final letters = <String>[];
    for (final c in _filteredContacts) {
      final letter = c.displayName.trim().isEmpty
          ? '#'
          : c.displayName.trim()[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
      if (seen.add(key)) letters.add(key);
    }
    return letters;
  }

  void _jumpToLetter(String letter) {
    final index = _filteredContacts.indexWhere((c) {
      final l = c.displayName.trim().isEmpty
          ? '#'
          : c.displayName.trim()[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(l) ? l : '#';
      return key == letter;
    });
    if (index == -1 || !_scrollCtrl.hasClients) return;
    final offset = (index + 1) * _rowHeight;
    final max = _scrollCtrl.position.maxScrollExtent;
    _scrollCtrl.animateTo(
      offset.clamp(0, max),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToAddNewStaff() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StaffPermissionsScreen()),
    );
    if (!mounted) return;
    if (result == true) Navigator.pop(context, true);
  }

  Future<void> _goToAddFromContact(Contact contact) async {
    final phone =
        contact.phones.isNotEmpty ? contact.phones.first.number : '';
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StaffPermissionsScreen(
          prefillName: contact.displayName.trim(),
          prefillPhone: cleanedPhone,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search Staff Name from your Contacts',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                prefixIcon:
                    Icon(Icons.search, size: 20, color: Color(0xFF9E9E9E)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? _PermissionDeniedView(
                  onRetry: _loadContacts,
                  onAddManually: _goToAddNewStaff,
                )
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: _filteredContacts.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _AddNewStaffRow(onTap: _goToAddNewStaff);
                        }
                        final contact = _filteredContacts[index - 1];
                        final phone = contact.phones.isNotEmpty
                            ? contact.phones.first.number
                            : '';
                        return SizedBox(
                          height: _rowHeight,
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  _avatarColorFor(contact.displayName),
                              child: Text(
                                _initialsFor(contact.displayName),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(
                              contact.displayName,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              phone,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF757575)),
                            ),
                            onTap: () => _goToAddFromContact(contact),
                          ),
                        );
                      },
                    ),
                    if (_query.isEmpty && _availableLetters.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 8,
                        bottom: 8,
                        child: _AlphabetIndex(
                          letters: _availableLetters,
                          onLetterTap: _jumpToLetter,
                        ),
                      ),
                    if (!_loading &&
                        _filteredContacts.isEmpty &&
                        _query.isNotEmpty)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: Center(
                            child: Text(
                              'No contacts found for "$_query"',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _AddNewStaffRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddNewStaffRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor, width: 1.4),
              ),
              child: const Icon(Icons.add, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Add New Staff',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  final List<String> letters;
  final ValueChanged<String> onLetterTap;

  const _AlphabetIndex({required this.letters, required this.onLetterTap});

  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (details) {
            final itemHeight = constraints.maxHeight / _alphabet.length;
            final index = (details.localPosition.dy / itemHeight)
                .floor()
                .clamp(0, _alphabet.length - 1);
            final letter = _alphabet[index];
            if (letters.contains(letter)) onLetterTap(letter);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _alphabet.map((letter) {
              final active = letters.contains(letter);
              return GestureDetector(
                onTap: active ? () => onLetterTap(letter) : null,
                child: SizedBox(
                  width: 18,
                  child: Text(
                    letter,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onAddManually;

  const _PermissionDeniedView({
    required this.onRetry,
    required this.onAddManually,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Contacts permission is needed to pick staff from your contacts. '
            'Please allow it in your phone settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onAddManually,
            child: const Text('Add Staff Manually'),
          ),
        ],
      ),
    );
  }
}