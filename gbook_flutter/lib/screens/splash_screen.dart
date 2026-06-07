// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  final void Function(bool isLoggedIn) onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _animController, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
          parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();

    // Check login state after animation
    Future.delayed(const Duration(milliseconds: 1800), _checkLogin);
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    if (mounted) {
      widget.onComplete(token != null && token.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            // ── FIX: const added to inner Column (was missing) ─────────────
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [      // ← const FIXED
                _LogoIcon(),
                SizedBox(height: 24),
                _AppTitle(),
                SizedBox(height: 8),
                _TagLine(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets with const constructors ──────────────────────────────────────

class _LogoIcon extends StatelessWidget {
  const _LogoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.book_outlined,
        size: 52,
        color: AppTheme.primaryColor,
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G-Book',
      style: TextStyle(
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }
}

class _TagLine extends StatelessWidget {
  const _TagLine();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Digital Khata for Your Business',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}