import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameCtrl.text = auth.user?.name ?? '';
    _emailCtrl.text = auth.user?.email ?? '';
    _businessNameCtrl.text = auth.business?.name ?? '';
    _addressCtrl.text = auth.user?.address ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _businessNameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();

    final profileOk = await auth.updateProfile({
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
    });

    final businessOk = await auth.updateBusiness({
      'name': _businessNameCtrl.text.trim(),
    });

    if (!mounted) return;

    if (profileOk && businessOk) {
      AppHelpers.showSuccessSnackBar(context, 'Profile updated!');
      setState(() => _isEditing = false);
    } else {
      AppHelpers.showErrorSnackBar(context, auth.error ?? 'Update failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final business = auth.business;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Profile',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
            child: Text(
              _isEditing ? 'Save' : 'Edit',
              style: const TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      AppHelpers.getAvatarColor(user?.name ?? ''),
                  child: Text(
                    AppHelpers.getInitials(user?.name ?? '?'),
                    style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              user?.name ?? '',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Center(
            child: Text(
              user?.phone ?? '',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 28),

          // Business section
          _SectionCard(
            title: 'Business Info',
            children: [
              _ProfileField(
                label: 'Business Name',
                controller: _businessNameCtrl,
                icon: Icons.store_outlined,
                enabled: _isEditing,
                value: business?.name ?? 'Not set',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Personal section
          _SectionCard(
            title: 'Personal Info',
            children: [
              _ProfileField(
                label: 'Full Name',
                controller: _nameCtrl,
                icon: Icons.person_outline,
                enabled: _isEditing,
                value: user?.name ?? '',
              ),
              _ProfileField(
                label: 'Email',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                enabled: _isEditing,
                value: user?.email ?? 'Not set',
                keyboardType: TextInputType.emailAddress,
              ),
              _ProfileField(
                label: 'Address',
                controller: _addressCtrl,
                icon: Icons.location_on_outlined,
                enabled: _isEditing,
                value: user?.address ?? 'Not set',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Logout
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        auth.logout();
                      },
                      child: const Text('Logout',
                          style: TextStyle(color: AppTheme.debit)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout, color: AppTheme.debit),
            label: const Text('Logout', style: TextStyle(color: AppTheme.debit)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.debit),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final String value;
  final TextInputType keyboardType;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.enabled,
    required this.value,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: enabled
          ? TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
              ),
            )
          : Row(
              children: [
                Icon(icon, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      Text(value,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}