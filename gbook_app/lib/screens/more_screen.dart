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

class MoreScreen extends StatelessWidget {
  // Called with tab index: 0=Parties, 1=Bills, 2=Items
  final void Function(int tabIndex)? onNavigateToTab;

  const MoreScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.primaryColor,
            expandedHeight: 120,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.primaryColor,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
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
                        mainAxisAlignment: MainAxisAlignment.center,
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
                                color: Colors.white70,
                                fontSize: 13,
                              ),
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
            title: const Text('More',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
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
                              const Text(
                                'Profile strength : ',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
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
                childAspectRatio: 1.0,
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
                // 2. Bills — switch to Bills tab (index 1)
                _FeatureCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFFB71C1C),
                  iconBg: const Color(0xFFFFEBEE),
                  label: 'Bills',
                  onTap: () {
                    if (onNavigateToTab != null) {
                      onNavigateToTab!(1);
                    }
                  },
                ),
                // 3. Items — switch to Items tab (index 2)
                _FeatureCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF7B1FA2),
                  iconBg: const Color(0xFFF3E5F5),
                  label: 'Items',
                  onTap: () {
                    if (onNavigateToTab != null) {
                      onNavigateToTab!(2);
                    }
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
                // 6. Shop Insurance (placeholder)
                _FeatureCard(
                  icon: Icons.security_outlined,
                  iconColor: const Color(0xFFB71C1C),
                  iconBg: const Color(0xFFFFEBEE),
                  label: 'Shop\nInsurance',
                  onTap: () => _showComingSoon(context, 'Shop Insurance'),
                ),
                // 7. Expenses
                _FeatureCard(
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFFE65100),
                  iconBg: const Color(0xFFFFF3E0),
                  label: 'Expenses',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReportsScreen()),
                  ),
                ),
                // 8. Suppliers — switch to Parties tab (index 0)
                _FeatureCard(
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF424242),
                  iconBg: const Color(0xFFF5F5F5),
                  label: 'Suppliers',
                  onTap: () {
                    if (onNavigateToTab != null) {
                      onNavigateToTab!(0);
                    }
                  },
                ),
                // 9. Settings
                _FeatureCard(
                  icon: Icons.settings_outlined,
                  iconColor: const Color(0xFF424242),
                  iconBg: const Color(0xFFF5F5F5),
                  label: 'Settings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  ),
                ),
              ]),
            ),
          ),

          // ── Settings row ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
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
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_outlined,
                        color: Color(0xFF424242)),
                  ),
                  title: const Text('Settings',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('App preferences, notifications',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF9E9E9E)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
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