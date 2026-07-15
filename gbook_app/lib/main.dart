import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'providers/locale_provider.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/app_lock_screen.dart';
import 'services/app_lock_service.dart';
import 'models/models.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // NEW: wrap the whole app in RestartWidget so that a language change can
  // force a genuine full-app rebuild (all providers recreated, navigation
  // stack cleared, splash → home flow re-run) — matching how Khatabook
  // "restarts" back to the Parties page when you change language.
  runApp(const RestartWidget(child: GBookApp()));
}

// ── RestartWidget (NEW) ────────────────────────────────────────────────────
// Standard Flutter pattern for faking a full app restart without killing the
// process: giving the subtree a brand-new Key forces Flutter to throw away
// every element/state below it (including all providers in MultiProvider,
// since their `create` callbacks run again) and build a fresh tree.
class RestartWidget extends StatefulWidget {
  final Widget child;
  const RestartWidget({super.key, required this.child});

  /// Call this from anywhere below RestartWidget (e.g. after changing the
  /// language) to fully restart the app.
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

class GBookApp extends StatelessWidget {
  const GBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()..init()),
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
        // NEW: powers the Staff feature (add/edit staff, attendance, salary due)
        ChangeNotifierProvider(create: (_) => StaffProvider()..loadStaff()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'GBook',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('mr'),
              Locale('gu'),
              Locale('pa'),
              Locale('ta'),
              Locale('te'),
              Locale('kn'),
              Locale('bn'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
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
          );
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
  bool _isLoggedIn = false;
  bool _needsUnlock = false;

  Future<void> onSplashComplete(bool isLoggedIn) async {
    bool needsUnlock = false;
    if (isLoggedIn) {
      needsUnlock = await AppLockService.instance.isEnabled();
    }
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _isLoggedIn = isLoggedIn;
      _needsUnlock = needsUnlock;
    });
  }

  void _onUnlocked() {
    if (!mounted) return;
    setState(() => _needsUnlock = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_splashDone && (auth.isAuthenticated || _isLoggedIn)) {
      if (_needsUnlock) {
        return UnlockScreen(onUnlocked: _onUnlocked);
      }
      return const HomeScreen();
    }
    if (_splashDone) {
      return const AuthScreen();
    }
    return SplashScreen(onComplete: onSplashComplete);
  }
}