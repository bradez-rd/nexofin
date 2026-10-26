import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../accounts/accounts_tab.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_tab.dart';
import '../simulator/simulator_tab.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de NexoFin AI?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    final tabs = [
      DashboardTab(
        onNavigateToAccounts: () => setState(() => _currentIndex = 1),
        onNavigateToTransactions: () => setState(() => _currentIndex = 2),
      ),
      const AccountsTab(),
      const TransactionsTab(),
      const SimulatorTab(),
    ];

    final titles = [
      AppConstants.appName,
      'Cuentas Financieras',
      'Historial de Transacciones',
      'Simulador & Asesor IA',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_currentIndex]),
            if (user != null)
              Text(
                'Hola, ${user.nombre.split(' ').first}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      floatingActionButton: _currentIndex != 3
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Movimiento', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            activeIcon: Icon(Icons.account_balance),
            label: 'Cuentas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Simulador IA',
          ),
        ],
      ),
    );
  }
}
