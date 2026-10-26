import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/account_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  runApp(const NexoFinApp());
}

class NexoFinApp extends StatelessWidget {
  const NexoFinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SessionCheckScreen(),
      ),
    );
  }
}

class SessionCheckScreen extends StatefulWidget {
  const SessionCheckScreen({super.key});

  @override
  State<SessionCheckScreen> createState() => _SessionCheckScreenState();
}

class _SessionCheckScreenState extends State<SessionCheckScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  void _checkSession() async {
    final authProvider = context.read<AuthProvider>();
    final hasSession = await authProvider.checkSession();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasSession ? const MainScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.emeraldLight,
              size: 56,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              color: AppTheme.emeraldLight,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
