// lib/screens/more_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'collection_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'cashbook_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  // Called with tab index: 0=Parties, 1=Bills, 2=Items
  final void Function(int tabIndex)? onNavigateToTab;
  // Called to switch to Bills tab AND select a specific sub-tab (0=Sale,1=Purchase,2=Expense)
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
                // 1. Cashbook
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
                // 2. Bills
                _FeatureCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFFB71C1C),
                  iconBg: const Color(0xFFFFEBEE),
                  label: 'Bills',
                  onTap: () {
                    if (onNavigateToTab != null) onNavigateToTab!(1);
                  },
                ),
                // 3. Items
                _FeatureCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF7B1FA2),
                  iconBg: const Color(0xFFF3E5F5),
                  label: 'Items',
                  onTap: () {
                    if (onNavigateToTab != null) onNavigateToTab!(2);
                  },
                ),
                // 4. Reports
                _FeatureCard(
                  icon: Icons.bar_chart_outlined,
                  iconColor: const Color(0xFF00695C),
                  iconBg: const Color(0xFFE0F2F1),
                  label: 'Reports',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReportsScreen()),
                  ),
                ),
                // 5. Collection
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
                // 6. Staff
                _FeatureCard(
                  icon: Icons.people_alt_outlined,
                  iconColor: const Color(0xFF2E7D32),
                  iconBg: const Color(0xFFE8F5E9),
                  label: 'Staff',
                  onTap: () => _showStaffScreen(context),
                ),
                // 7. Expenses
                _FeatureCard(
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFFE65100),
                  iconBg: const Color(0xFFFFF3E0),
                  label: 'Expenses',
                  onTap: () {
                    if (onNavigateToTabWithSubTab != null) {
                      onNavigateToTabWithSubTab!(1, billSubTab: 2);
                    } else if (onNavigateToTab != null) {
                      onNavigateToTab!(1);
                    }
                  },
                ),
                // 8. Suppliers
                _FeatureCard(
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF424242),
                  iconBg: const Color(0xFFF5F5F5),
                  label: 'Suppliers',
                  onTap: () {
                    if (onNavigateToTab != null) onNavigateToTab!(0);
                  },
                ),
                // 9. Shop Insurance
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

          // ── Settings & Other Options ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Settings — now a real navigable screen (was the broken
                  // import/placeholder causing the build failure)
                  _OptionCard(
                    icon: Icons.settings_outlined,
                    iconColor: const Color(0xFF424242),
                    iconBg: const Color(0xFFF5F5F5),
                    title: 'Settings',
                    subtitle: 'SMS, Payment, Language, Backup & more',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Invite Friends
                  _OptionCard(
                    icon: Icons.share_outlined,
                    iconColor: const Color(0xFF25D366),
                    iconBg: const Color(0xFFE8F5E9),
                    title: 'Invite Friends',
                    subtitle: 'Share GBook with your friends via WhatsApp',
                    onTap: () => _inviteFriends(context),
                  ),
                  const SizedBox(height: 8),
                  // Help & Support
                  _OptionCard(
                    icon: Icons.help_outline_outlined,
                    iconColor: const Color(0xFF1565C0),
                    iconBg: const Color(0xFFE3F2FD),
                    title: 'Help & Support',
                    subtitle: 'FAQs, chat support & user guide',
                    onTap: () => _showHelpSupport(context),
                  ),
                  const SizedBox(height: 8),
                  // About Us
                  _OptionCard(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF7B1FA2),
                    iconBg: const Color(0xFFF3E5F5),
                    title: 'About GBook',
                    subtitle: 'Version 1.0.0 • Terms & Privacy Policy',
                    onTap: () => _showAboutUs(context),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_outlined,
                      color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  const Text('Help & Support',
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
                  _HelpTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Chat with Support',
                    subtitle: 'Get instant help from our team',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Opening chat support...')),
                      );
                    },
                  ),
                  const Divider(),
                  _HelpTile(
                    icon: Icons.question_answer_outlined,
                    title: 'Frequently Asked Questions',
                    subtitle: 'Find answers to common questions',
                    onTap: () {
                      Navigator.pop(context);
                      _showFAQs(context);
                    },
                  ),
                  const Divider(),
                  _HelpTile(
                    icon: Icons.video_library_outlined,
                    title: 'Video Tutorials',
                    subtitle: 'Learn how to use GBook step by step',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening tutorials...')),
                      );
                    },
                  ),
                  const Divider(),
                  _HelpTile(
                    icon: Icons.email_outlined,
                    title: 'Email Us',
                    subtitle: 'support@gbook.app',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Opening email client...')),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFAQs(BuildContext context) {
    const faqs = [
      ('How do I add a customer?', 'Go to Parties tab → tap the + button or ADD CUSTOMER at the bottom.'),
      ('How do I generate a bill?', 'Go to Bills tab → tap ADD BILL → fill in items and party details.'),
      ('How do I record a payment received?', 'Open the customer → tap RECEIVED → enter the amount.'),
      ('Can I send SMS to customers?', 'Yes! After recording a transaction, tap SMS in the quick action bar on the customer page.'),
      ('How to track expenses?', 'Go to Bills → Expense tab → ADD BILL. Or use Cashbook for quick cash entries.'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('FAQs'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: faqs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) => ExpansionTile(
              title: Text(faqs[i].$1,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(faqs[i].$2,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF616161))),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
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
                style:
                    TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'GBook helps small business owners manage their accounts, '
              'customers, bills and inventory — all in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF616161)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Opening Terms of Service...')),
                    );
                  },
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Opening Privacy Policy...')),
                    );
                  },
                  child: const Text('Privacy Policy'),
                ),
              ],
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

// ── Option card (for settings/help/about) ────────────────────────────────────
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
        onTap: onTap,
      ),
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
            child:
                Icon(icon, color: const Color(0xFF2E7D32), size: 22),
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

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1565C0), size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
      onTap: onTap,
    );
  }
}