// lib/screens/more_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/local_database.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'collection_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'cashbook_screen.dart';
import 'settings_screen.dart';
import 'sms_settings_screen.dart';
import 'payment_settings_screen.dart';
import 'language_screen.dart';
import 'app_lock_screen.dart';
import 'delete_khata_screen.dart';
import '../services/app_lock_service.dart';
import 'manage_staff_screen.dart';

class MoreScreen extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(int tabIndex, {int? billSubTab})? onNavigateToTabWithSubTab;

  const MoreScreen({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToTabWithSubTab,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.primaryColor,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 12,
                16,
                16,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      AppHelpers.initials(profile?.businessName ?? 'G'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.businessName ?? 'My Business',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profile?.phone.isNotEmpty == true)
                          Text(
                            '+91 ${profile!.phone}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline,
                              color: Colors.white, size: 15),
                          SizedBox(width: 4),
                          Text('Profile',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Profile strength banner ────────────────────────────────────
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Profile strength : ',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                              Text(
                                profile?.email != null &&
                                        profile?.address != null
                                    ? 'Strong'
                                    : 'Medium',
                                style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: profile?.email != null &&
                                      profile?.address != null
                                  ? 0.93
                                  : 0.6,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Colors.greenAccent),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fill missing details for a FREE Business Card',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PROCEED',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Feature grid ──────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.95,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.book_outlined,
                  iconColor: const Color(0xFF1565C0),
                  iconBg: const Color(0xFFE3F2FD),
                  label: 'Cashbook',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CashbookScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFFB71C1C),
                  iconBg: const Color(0xFFFFEBEE),
                  label: 'Bills',
                  onTap: () {
                    if (onNavigateToTab != null) onNavigateToTab!(1);
                  },
                ),
                _FeatureCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF7B1FA2),
                  iconBg: const Color(0xFFF3E5F5),
                  label: 'Items',
                  onTap: () {
                    if (onNavigateToTab != null) onNavigateToTab!(2);
                  },
                ),
                // FIX: this used to be a stray method declaration
                // (`_void _showStaffScreen(...) { ... },`) sitting inside
                // the widget list, which is invalid Dart syntax. It is now
                // a proper _FeatureCard that calls the existing
                // _showStaffScreen(context) method defined below.
                _FeatureCard(
                  icon: Icons.people_alt_outlined,
                  iconColor: const Color(0xFF2E7D32),
                  iconBg: const Color(0xFFE8F5E9),
                  label: 'Staff',
                  // FIX: was calling the old placeholder _showStaffScreen()
                  // bottom sheet ("Add Staff from Contacts" -> fake "coming
                  // soon!" snackbar). Now opens the real, fully working
                  // ManageStaffScreen (attendance, salary due, permissions).
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageStaffScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.calendar_month_outlined,
                  iconColor: const Color(0xFF1565C0),
                  iconBg: const Color(0xFFE8EAF6),
                  label: 'Collection',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CollectionScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.security_outlined,
                  iconColor: const Color(0xFFB71C1C),
                  iconBg: const Color(0xFFFFEBEE),
                  label: 'Shop\nInsurance',
                  onTap: () => _showShopInsurance(context),
                ),
              ]),
            ),
          ),

          // ── Accordion sections ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Column(
                children: [
                  _AccordionSection(
                    icon: Icons.settings_outlined,
                    iconColor: const Color(0xFF424242),
                    title: 'Settings',
                    children: [
                      // SMS Settings → dedicated SmsSettingsScreen
                      _AccordionRow(
                        label: 'SMS Settings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SmsSettingsScreen()),
                        ),
                      ),
                      // Payment Settings → dedicated PaymentSettingsScreen
                      _AccordionRow(
                        label: 'Payment Settings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PaymentSettingsScreen()),
                        ),
                      ),
                      _AccordionRow(
                        label: 'Recycle Bin',
                        onTap: () => _showRecycleBin(context),
                      ),
                      // App Lock → dedicated AppLockScreen (PIN create/change),
                      // never the full SettingsScreen.
                      const _AppLockToggleRow(),
                      // Language → dedicated LanguageScreen (non-onboarding)
                      _AccordionRow(
                        label: 'Language',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LanguageScreen(isOnboarding: false)),
                        ),
                      ),
                      _AccordionRow(
                        label: 'Backup Information',
                        onTap: () => _showBackupInfo(context),
                      ),
                      _AccordionRow(
                        // FIX: opens the real Delete Khata flow (type-to-
                        // confirm → soft delete → Recycle Bin) instead of a
                        // "contact support" dead end.
                        label: 'Delete Khata',
                        onTap: () => _confirmDeleteKhata(context),
                      ),
                      _AccordionRow(
                        label: 'App Update',
                        onTap: () => _showAppUpdate(context),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AccordionSection(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF1565C0),
                    title: 'Help & Support',
                    children: [
                      _AccordionRow(
                        label: 'FAQs',
                        onTap: () => _showFAQs(context),
                      ),
                      _AccordionRow(
                        label: 'Help on WhatsApp',
                        onTap: () => _openWhatsAppHelp(context),
                      ),
                      _AccordionRow(
                        label: 'Call Us',
                        onTap: () => _callSupport(context),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AccordionSection(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF1565C0),
                    title: 'About Us',
                    children: [
                      _AccordionRow(
                        label: 'About GBook',
                        onTap: () => _showAboutUs(context),
                      ),
                      _AccordionRow(
                        label: 'Privacy Policy',
                        onTap: () => _showPrivacyPolicy(context),
                      ),
                      _AccordionRow(
                        label: 'Terms & Conditions',
                        onTap: () => _showTerms(context),
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Invite Friends banner ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
              child: InkWell(
                onTap: () => _inviteFriends(context),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.groups_outlined,
                          color: Color(0xFF25D366), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invite your friends to use GBook',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF616161)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Invite Friends',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Version footer ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 24),
              child: Column(
                children: [
                  Text('V 1.0.0',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('GBook',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action helpers ────────────────────────────────────────────────────────

  void _showRecycleBin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _RecycleBinSheet(),
    );
  }

  void _showBackupInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup Information'),
        content: const Text(
          'Your data is automatically backed up when your phone is connected to the internet.\n\n'
          'In case you format this phone or mistakenly delete the app, just download the app again '
          'and login using your GBook-registered number. Your data will be automatically restored.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // FIX: navigates to the real DeleteKhataScreen (type-to-confirm) instead
  // of showing a static "contact support" dialog with no actual delete
  // logic behind it.
  void _confirmDeleteKhata(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeleteKhataScreen()),
    );
  }

  void _showAppUpdate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App Update'),
        content: const Text('You are using the latest version of GBook (v1.0.0).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // ── FIX: real WhatsApp launch instead of a no-op SnackBar ────────────────
  // Tries the native WhatsApp app first (whatsapp://), then falls back to
  // the wa.me web link if WhatsApp isn't installed / can't be resolved.
  Future<void> _openWhatsAppHelp(BuildContext context) async {
    const supportPhone = '911800000000'; // country code + number, digits only
    const message = 'Hi, I need help with GBook.';
    final encodedMsg = Uri.encodeComponent(message);

    final waAppUri =
        Uri.parse('whatsapp://send?phone=$supportPhone&text=$encodedMsg');
    final waWebUri =
        Uri.parse('https://wa.me/$supportPhone?text=$encodedMsg');

    try {
      final canOpenApp = await canLaunchUrl(waAppUri);
      if (canOpenApp) {
        final launched =
            await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {
      // fall through to web link
    }

    try {
      final launched =
          await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp is not installed')),
        );
      }
    }
  }

  void _callSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Call Us'),
        content: const Text('Support: +91 1800-000-000\n(Mon–Sat, 9 AM – 7 PM)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Privacy Policy...')),
    );
  }

  void _showTerms(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Terms & Conditions...')),
    );
  }

  void _showStaffScreen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined,
                      color: Color(0xFF2E7D32)),
                  const SizedBox(width: 10),
                  const Text('Staff Management',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Staff feature — add from contacts coming soon!')),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add Staff from Contacts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _StaffFeatureRow(
                    icon: Icons.currency_rupee,
                    title: 'Manage Salary',
                    subtitle: 'Set & track monthly salary for each staff',
                  ),
                  const Divider(),
                  const _StaffFeatureRow(
                    icon: Icons.check_circle_outline,
                    title: 'Mark Attendance',
                    subtitle: 'Daily attendance with present/absent/half-day',
                  ),
                  const Divider(),
                  const _StaffFeatureRow(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Permissions',
                    subtitle: 'Control what each staff can view or edit',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShopInsurance(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_outlined,
                  color: Color(0xFFB71C1C), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Shop Insurance',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Protect your business against fire, theft, natural disasters and more.\n\n'
              'Get customised insurance plans starting from ₹499/year.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Redirecting to insurance partner...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('EXPLORE PLANS',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
    );
  }

  void _inviteFriends(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_outlined,
                  color: Color(0xFF25D366), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Invite Friends',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Invite your friends and fellow business owners to GBook — the #1 digital khata app!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Opening WhatsApp to share...')),
                );
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('SHARE ON WHATSAPP',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Opening share sheet...')),
                );
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('SHARE VIA OTHER APPS'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FIX: full-page, categorized FAQ screen (matches Khatabook layout) ────
  void _showFAQs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _FaqCategoriesScreen()),
    );
  }

  void _showAboutUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('GBook',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.primaryColor)),
            const Text('Digital Khata for Your Business',
                style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
            const SizedBox(height: 12),
            const Text('Version 1.0.0',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'GBook helps small business owners manage their accounts, '
              'customers, bills and inventory — all in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF616161)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

// ── Recycle Bin sheet ─────────────────────────────────────────────────────────
// FIX: was a static "Recycle bin is empty" placeholder with no query behind
// it. Now actually loads soft-deleted khatas (business_profile.deletedAt)
// and soft-deleted bills (bills.deletedAt) and lets the user restore either.
class _RecycleBinSheet extends StatefulWidget {
  const _RecycleBinSheet();

  @override
  State<_RecycleBinSheet> createState() => _RecycleBinSheetState();
}

class _RecycleBinSheetState extends State<_RecycleBinSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _deletedBooks = [];
  List<Bill> _deletedBills = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final books = await LocalDatabase.instance.getDeletedBusinessProfiles();
    final bills = await LocalDatabase.instance.getDeletedBills();
    if (!mounted) return;
    setState(() {
      _deletedBooks = books;
      _deletedBills = bills;
      _loading = false;
    });
  }

  int _daysLeft(String? deletedAtIso) {
    if (deletedAtIso == null) return 30;
    final deletedAt = DateTime.tryParse(deletedAtIso);
    if (deletedAt == null) return 30;
    final elapsed = DateTime.now().difference(deletedAt).inDays;
    final left = 30 - elapsed;
    return left < 0 ? 0 : left;
  }

  Future<void> _restoreBook(String id) async {
    await LocalDatabase.instance.restoreBusinessProfile(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Khata restored')),
    );
    await context.read<AuthProvider>().checkAuth();
    _load();
  }

  Future<void> _restoreBill(String id) async {
    await LocalDatabase.instance.restoreBill(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill restored')),
    );
    context.read<BillProvider>().loadBills();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _deletedBooks.isEmpty && _deletedBills.isEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.delete_outline, color: Color(0xFF424242)),
                const SizedBox(width: 10),
                const Text('Recycle Bin',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : isEmpty
                    ? ListView(
                        controller: ctrl,
                        padding: const EdgeInsets.all(16),
                        children: [
                          Icon(Icons.delete_sweep_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Deleted khatas and bills will appear here for '
                            '30 days before being permanently removed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          const Center(child: Text('Recycle bin is empty')),
                        ],
                      )
                    : ListView(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          if (_deletedBooks.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Khatas',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF757575))),
                            ),
                            ..._deletedBooks.map((b) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.book_outlined,
                                            color: AppTheme.primaryColor,
                                            size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (b['businessName']
                                                      as String?) ??
                                                  'Untitled Khata',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 14),
                                            ),
                                            Text(
                                              '${_daysLeft(b['deletedAt'] as String?)} days left',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9E9E9E)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _restoreBook(b['id'] as String),
                                        child: const Text('RESTORE'),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                          if (_deletedBills.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Bills',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF757575))),
                            ),
                            ..._deletedBills.map((bill) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.debitColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.receipt_long_outlined,
                                            color: AppTheme.debitColor,
                                            size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bill.billNumber,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 14),
                                            ),
                                            Text(
                                              '${bill.daysLeftInRecycleBin} days left',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9E9E9E)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _restoreBill(bill.id),
                                        child: const Text('RESTORE'),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Feature card widget ───────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF212121),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accordion section ─────────────────────────────────────────────────────────
class _AccordionSection extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _AccordionSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<_AccordionSection> createState() => _AccordionSectionState();
}

class _AccordionSectionState extends State<_AccordionSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.iconColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(children: widget.children),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AccordionRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _AccordionRow({
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF212121)),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF9E9E9E), size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }
}

// ── App Lock row (Khatabook-style) ─────────────────────────────────────────
class _AppLockToggleRow extends StatefulWidget {
  const _AppLockToggleRow();

  @override
  State<_AppLockToggleRow> createState() => _AppLockToggleRowState();
}

class _AppLockToggleRowState extends State<_AppLockToggleRow> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await AppLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _openAppLockScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppLockScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: _openAppLockScreen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'App Lock',
                    style: TextStyle(fontSize: 14, color: Color(0xFF212121)),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _enabled,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (_) => _openAppLockScreen(),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }
}

class _StaffFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StaffFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FAQ — categorized, fully working (Khatabook-style)
// ══════════════════════════════════════════════════════════════════════════════

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

class _FaqCategory {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_FaqItem> items;

  const _FaqCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

final List<_FaqCategory> _kFaqCategories = [
  _FaqCategory(
    icon: Icons.person_add_alt_outlined,
    title: 'Managing Customers',
    subtitle: 'Add customers, transactions, send reminders etc',
    items: const [
      _FaqItem(
        'How do I add a new customer?',
        'Go to the Parties tab → Customers → tap ADD CUSTOMER, fill in the name, phone number, email and address, then tap SAVE.',
      ),
      _FaqItem(
        'How do I record a payment given or received?',
        'Open the customer from the Parties list, then tap GIVEN or RECEIVED at the bottom of the screen, enter the amount, note and payment mode, and save.',
      ),
      _FaqItem(
        'How do I edit or delete a customer?',
        'Open the customer, tap the edit (pencil) icon in the top bar to update details, or the delete icon to remove the customer along with their transactions.',
      ),
      _FaqItem(
        'How do I send a payment reminder?',
        'Open the customer\'s ledger, tap the reminder/SMS icon in the quick action bar to send a WhatsApp or SMS reminder with their current balance.',
      ),
      _FaqItem(
        'What do "You will give" and "You will get" mean?',
        '"You will get" is the amount owed to you by customers. "You will give" is the amount you owe suppliers or customers. Both are shown as running totals on the Parties screen.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.local_shipping_outlined,
    title: 'Managing Suppliers',
    subtitle: 'Add suppliers and track what you owe',
    items: const [
      _FaqItem(
        'How do I add a supplier?',
        'Go to Parties → Suppliers tab → tap ADD SUPPLIER and fill in their details.',
      ),
      _FaqItem(
        'How is supplier balance calculated?',
        'Every purchase bill or payment you record against a supplier updates their running balance automatically — no manual calculation needed.',
      ),
      _FaqItem(
        'Can I see total payable to all suppliers at once?',
        'Yes — the Suppliers tab shows a "Total Payable" summary card at the top, combining balances across all suppliers.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.receipt_long_outlined,
    title: 'Bills & Invoices',
    subtitle: 'Create sale, purchase and return bills',
    items: const [
      _FaqItem(
        'How do I create a sale or purchase bill?',
        'Go to the Bills tab, choose Sale or Purchase, tap ADD BILL, add items, set payment status, and save.',
      ),
      _FaqItem(
        'How do I create a sale or purchase return?',
        'Open the original bill from Bill Detail, tap "+ SALE RETURN" or "+ PURCHASE RETURN", adjust the quantities being returned, choose a refund mode, and generate the return.',
      ),
      _FaqItem(
        'How do I share or download an invoice PDF?',
        'Open any bill → tap VIEW PDF. You can pick Premium, Thermal or Basic invoice formats, then use Download or Share on WhatsApp.',
      ),
      _FaqItem(
        'What does "Fully Paid / Partial / Unpaid" mean on a bill?',
        'It reflects how much of the bill amount has been paid — Fully Paid means the full amount is settled, Partial means some amount is still due, Unpaid means nothing has been paid yet.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.inventory_2_outlined,
    title: 'Items & Inventory',
    subtitle: 'Add items, prices, stock and low-stock alerts',
    items: const [
      _FaqItem(
        'How do I add a new item?',
        'Go to the Items tab → tap ADD ITEM, enter the name, sale price, purchase price, stock quantity and unit, then save.',
      ),
      _FaqItem(
        'How does stock update automatically?',
        'Stock reduces automatically when you create a sale bill and increases when you create a purchase bill, so you don\'t need to update it manually.',
      ),
      _FaqItem(
        'What is the low-stock warning?',
        'Each item has a low-stock threshold. When available stock falls at or below that number, the item is flagged so you know to reorder.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Cashbook & Payments',
    subtitle: 'Track daily cash in / cash out',
    items: const [
      _FaqItem(
        'What is the Cashbook for?',
        'Cashbook records all your cash-in and cash-out entries separately from customer/supplier ledgers — useful for tracking day-to-day business cash flow.',
      ),
      _FaqItem(
        'How do I add a cashbook entry?',
        'Open Cashbook from the More menu or the Bills header, tap the add button, choose Cash In or Cash Out, enter the amount and description, and save.',
      ),
      _FaqItem(
        'Where can I set accepted payment modes?',
        'Go to More → Payment Settings to configure which payment modes (Cash, UPI, Bank Transfer, Cheque) appear when recording transactions.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.person_outline,
    title: 'My Profile & Business',
    subtitle: 'Manage your profile and business details',
    items: const [
      _FaqItem(
        'How do I update my business name or address?',
        'Go to More → Profile (or the edit icon next to your business name), update the fields, and tap Save.',
      ),
      _FaqItem(
        'How do I change the app language?',
        'Go to More → Language, pick your preferred language from the list — the whole app updates immediately.',
      ),
      _FaqItem(
        'How do I log out of GBook?',
        'Open Profile → scroll down and tap Logout, then confirm.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.bar_chart_outlined,
    title: 'Reports',
    subtitle: 'View monthly summaries and totals',
    items: const [
      _FaqItem(
        'How do I view my monthly report?',
        'Go to Reports (from the Parties screen or Bills header "VIEW REPORTS"), select the year and month to see total given, received and net balance.',
      ),
      _FaqItem(
        'What is shown in "Overall Summary"?',
        'It shows your all-time totals for amount given and amount received across every recorded transaction.',
      ),
      _FaqItem(
        'Can I see monthly sales and purchases separately?',
        'Yes — tap the Monthly Sales or Monthly Purchases card on the Bills screen header to open a detailed breakdown.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.lock_outline,
    title: 'App Lock & Security',
    subtitle: 'Protect your data with a PIN',
    items: const [
      _FaqItem(
        'How do I enable App Lock?',
        'Go to More → Settings → App Lock, turn it on and set a 4-digit PIN. The app will now ask for this PIN every time it\'s opened.',
      ),
      _FaqItem(
        'What if I forget my App Lock PIN?',
        'From the unlock screen, use the "Forgot PIN" option if available, or contact support via Call Us / WhatsApp for help resetting it.',
      ),
      _FaqItem(
        'How do I change or turn off my PIN?',
        'Go to More → Settings → App Lock, tap the row, and follow the prompts to change your PIN or turn the lock off.',
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.cloud_outlined,
    title: 'Data Backup',
    subtitle: 'Know how to backup or restore your data',
    items: const [
      _FaqItem(
        'Is my data backed up automatically?',
        'Yes, your data is automatically backed up whenever your phone has an internet connection.',
      ),
      _FaqItem(
        'I got a new phone — how do I get my data back?',
        'Install GBook on the new device and log in with the same registered phone number. Your customers, bills, items and reports will be restored automatically.',
      ),
      _FaqItem(
        'What happens if I delete the app by mistake?',
        'Simply reinstall GBook and log in again with your registered number — all your data is safely restored from backup.',
      ),
    ],
  ),
];

class _FaqCategoriesScreen extends StatelessWidget {
  const _FaqCategoriesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'FAQs',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _kFaqCategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final cat = _kFaqCategories[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FaqDetailScreen(category: cat),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(cat.icon,
                            color: AppTheme.primaryColor, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF212121))),
                              const SizedBox(height: 2),
                              Text(cat.subtitle,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9E9E9E))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF9E9E9E)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Column(
              children: [
                const Text("Didn't find your question?",
                    style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => MoreScreenSupportActions
                            .openWhatsAppFromContext(context),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('CHAT WITH US'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Call Us'),
                            content: const Text(
                                'Support: +91 1800-000-000\n(Mon–Sat, 9 AM – 7 PM)'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close')),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('CALL US'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side:
                              const BorderSide(color: AppTheme.primaryColor),
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqDetailScreen extends StatelessWidget {
  final _FaqCategory category;
  const _FaqDetailScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category.title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: category.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = category.items[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: Text(
                item.question,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF212121)),
              ),
              expandedAlignment: Alignment.centerLeft,
              children: [
                Text(
                  item.answer,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF616161), height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Shared helper so both the accordion row and the FAQ screen's
// "CHAT WITH US" button use the exact same WhatsApp-launch logic.
class MoreScreenSupportActions {
  MoreScreenSupportActions._();

  static Future<void> openWhatsAppFromContext(BuildContext context) async {
    const supportPhone = '911800000000';
    const message = 'Hi, I need help with GBook.';
    final encodedMsg = Uri.encodeComponent(message);

    final waAppUri =
        Uri.parse('whatsapp://send?phone=$supportPhone&text=$encodedMsg');
    final waWebUri =
        Uri.parse('https://wa.me/$supportPhone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(waAppUri)) {
        final launched =
            await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {}

    try {
      final launched =
          await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp is not installed')),
        );
      }
    }
  }
}