import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/customer_screen.dart';
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()..loadCustomers()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()..loadTransactions()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()..loadSuppliers()),
        ChangeNotifierProvider(create: (_) => ItemProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => BillProvider()..loadBills()),
        ChangeNotifierProvider(create: (_) => CashbookProvider()..loadEntries()),
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
  bool _isLoggedIn = false;

  void onSplashComplete(bool isLoggedIn) {
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_splashDone && (auth.isAuthenticated || _isLoggedIn)) {
      return const HomeScreen();
    }
    if (_splashDone) {
      return const AuthScreen();
    }
    return SplashScreen(onComplete: onSplashComplete);
  }
}