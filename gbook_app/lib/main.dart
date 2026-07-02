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
  runApp(const GBookApp());
}

class GBookApp extends StatelessWidget {
  const GBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // FIX: LocaleProvider is now registered and initialized. Without
        // this, the app never knew which language to show and
        // AppLocalizations.of(context) always fell back to English no
        // matter what the user picked in LanguageScreen.
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
      ],
      child: Consumer<LocaleProvider>(
        // FIX: Consumer here means the *entire* MaterialApp (and therefore
        // every screen below it) rebuilds whenever LocaleProvider calls
        // notifyListeners() — i.e. the instant the user taps a language
        // tile in LanguageScreen. This is what actually makes "tap a
        // language → whole app changes" work, instead of just changing
        // one screen's local state.
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
  // FIX: When the user is logged in and App Lock is enabled, we hold the
  // app on the PIN unlock screen right after splash, before showing
  // HomeScreen — matching the Khatabook-style "Unlock" flow.
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

// FIX: Make sure pubspec.yaml has this under dependencies:
//   flutter_localizations:
//     sdk: flutter
// This gives correct built-in "OK"/"Cancel" text, date pickers, etc. in
// each supported language automatically.