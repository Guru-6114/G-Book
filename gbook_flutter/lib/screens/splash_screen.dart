// lib/screens/splash_screen.dart
// PASTE TO: gbook_flutter/lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'language_screen.dart';

class SplashScreen extends StatefulWidget {
  final void Function(bool isLoggedIn) onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = await auth.checkAuth();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Check if language has been selected before
    widget.onComplete(isLoggedIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const _SplashContent(),
          ),
        ),
      ),
    );
  }
}

// Extracted to a const widget to fix prefer_const_constructors lint
class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'GBook',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Digital Khata',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Standalone Language Splash — used when app first launches ─────────────────
// Shows language screen first time, auth screen subsequently
class FirstLaunchRouter extends StatefulWidget {
  const FirstLaunchRouter({super.key});

  @override
  State<FirstLaunchRouter> createState() => _FirstLaunchRouterState();
}

class _FirstLaunchRouterState extends State<FirstLaunchRouter> {
  bool _splashDone = false;
  bool _isLoggedIn = false;

  void _onSplashComplete(bool isLoggedIn) {
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    if (auth.isAuthenticated || _isLoggedIn) {
      // Import HomeScreen where needed
      return const _HomeNavigator();
    }

    return const LanguageScreen();
  }
}

// Placeholder to avoid circular import — replace with actual HomeScreen import
class _HomeNavigator extends StatelessWidget {
  const _HomeNavigator();

  @override
  Widget build(BuildContext context) {
    // This triggers the route to HomeScreen from main.dart
    // The actual navigation is handled in main.dart's _RootRedirect
    return const SizedBox.shrink();
  }
}