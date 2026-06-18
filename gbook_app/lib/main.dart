// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/customer_screen.dart';
import 'models/models.dart';
import 'theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService().initialize();

  runApp(const GBookApp());
}

class GBookApp extends StatelessWidget {
  const GBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
            create: (_) => CustomerProvider()..loadCustomers()),
        ChangeNotifierProvider(
            create: (_) => TransactionProvider()..loadTransactions()),
        ChangeNotifierProvider(
            create: (_) => SupplierProvider()..loadSuppliers()),
        ChangeNotifierProvider(create: (_) => ItemProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => BillProvider()..loadBills()),
        ChangeNotifierProvider(
            create: (_) => CashbookProvider()..loadEntries()),
      ],
      child: MaterialApp(
        title: 'GBook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _RootRedirect(),
        onGenerateRoute: (settings) {
          if (settings.name == '/customer') {
            final customer = settings.arguments as Customer;
            return MaterialPageRoute(
              builder: (_) => CustomerScreen(customer: customer),
            );
          }
          return null;
        },
      ),
    );
  }
}

class _RootRedirect extends StatefulWidget {
  const _RootRedirect();

  @override
  State<_RootRedirect> createState() => _RootRedirectState();
}

class _RootRedirectState extends State<_RootRedirect> {
  bool _splashDone = false;

  // FIX (logout bug): the old code also kept a local `_isLoggedIn` bool
  // that was set to `true` by the splash screen's onComplete callback and
  // NEVER reset afterwards. AuthProvider.logout() correctly clears
  // auth.isAuthenticated, but the redirect logic used to check
  // `auth.isAuthenticated || _isLoggedIn` — so even after a real logout,
  // the stale `_isLoggedIn == true` kept sending the user straight back to
  // HomeScreen instead of AuthScreen. That's why tapping Logout looked
  // like it did nothing.
  //
  // Fix: drop the redundant local flag entirely and trust AuthProvider as
  // the single source of truth for auth state. We still use
  // onSplashComplete to know the splash animation/timer has finished and
  // checkAuth() has had a chance to run, but it no longer overrides
  // AuthProvider's verdict.
  Future<void> onSplashComplete(bool isLoggedIn) async {
    // Make sure AuthProvider has actually loaded any persisted session
    // before we decide where to navigate. checkAuth() reads the saved
    // token/profile from storage and sets isAuthenticated accordingly.
    if (!mounted) return;
    await context.read<AuthProvider>().checkAuth();
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_splashDone) {
      return SplashScreen(onComplete: onSplashComplete);
    }

    // FIX: this now purely reflects AuthProvider's real state. When
    // logout() runs, it sets isAuthenticated = false and calls
    // notifyListeners(), which rebuilds this widget and correctly routes
    // to AuthScreen — requiring OTP again, exactly like Khatabook.
    if (auth.isAuthenticated) {
      return const HomeScreen();
    }

    return const AuthScreen();
  }
}