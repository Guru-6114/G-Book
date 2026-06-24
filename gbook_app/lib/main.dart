import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/customer_screen.dart';
import 'models/models.dart';
import 'theme/app_theme.dart';

// ── BLOCK A: No Firebase yet (use this until flutterfire configure is done) ───
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GBookApp());
}

// ── BLOCK B: With Firebase — uncomment AFTER running:
//   flutter pub get
//   flutterfire configure
// Then delete Block A above and uncomment everything below.
//
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'services/fcm_service.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   await FcmService().initialize();
//   runApp(const GBookApp());
// }

class GBookApp extends StatelessWidget {
  const GBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => CashbookProvider()),
      ],
      child: const _AppBootstrap(),
    );
  }
}

/// Wires up the active-khatabook-change listeners once, then shows the root
/// of the app. This is what makes "Create New Khatabook" actually isolate
/// data per book instead of sharing customers/suppliers/bills across books.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _wired = false;

  void _wireBookChangeListeners(BuildContext context) {
    if (_wired) return;
    _wired = true;
    final auth = context.read<AuthProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final supplierProvider = context.read<SupplierProvider>();
    final itemProvider = context.read<ItemProvider>();
    final billProvider = context.read<BillProvider>();
    final cashbookProvider = context.read<CashbookProvider>();

    auth.addBookChangeListener((bookId) async {
      await Future.wait([
        customerProvider.reloadForActiveBook(bookId),
        transactionProvider.reloadForActiveBook(bookId),
        supplierProvider.reloadForActiveBook(bookId),
        itemProvider.reloadForActiveBook(bookId),
        billProvider.reloadForActiveBook(bookId),
        cashbookProvider.reloadForActiveBook(bookId),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    _wireBookChangeListeners(context);
    return MaterialApp(
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
  bool _dataLoadedForActiveBook = false;

  void onSplashComplete(bool isLoggedIn) {
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _isLoggedIn = isLoggedIn;
    });
  }

  Future<void> _loadDataForActiveBook(String bookId) async {
    if (_dataLoadedForActiveBook || bookId.isEmpty) return;
    _dataLoadedForActiveBook = true;
    await Future.wait([
      context.read<CustomerProvider>().loadCustomers(bookId: bookId),
      context.read<TransactionProvider>().loadTransactions(bookId: bookId),
      context.read<SupplierProvider>().loadSuppliers(bookId: bookId),
      context.read<ItemProvider>().loadItems(bookId: bookId),
      context.read<BillProvider>().loadBills(bookId: bookId),
      context.read<CashbookProvider>().loadEntries(bookId: bookId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_splashDone && (auth.isAuthenticated || _isLoggedIn) &&
        auth.activeBookId.isNotEmpty) {
      // Kick off data load for whichever book is active, scoped correctly.
      _loadDataForActiveBook(auth.activeBookId);
      return const HomeScreen();
    }
    if (_splashDone) {
      return const AuthScreen();
    }
    return SplashScreen(onComplete: onSplashComplete);
  }
}