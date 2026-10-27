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
import '../profile/profile_tab.dart';
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
      context.read<TransactionProvider>().fetchCategories();
    });
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nx.surface,
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de NexoFin AI?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.nx.negative),
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
    // Orden del diseño: Inicio · Movimientos · Simular · Cuentas · Perfil
    final tabs = [
      DashboardTab(
        onNavigateToAccounts: () => setState(() => _currentIndex = 3),
        onNavigateToTransactions: () => setState(() => _currentIndex = 1),
        onNavigateToSimulator: () => setState(() => _currentIndex = 2),
      ),
      const TransactionsTab(),
      const SimulatorTab(),
      const AccountsTab(),
      ProfileTab(onLogout: _logout),
    ];

    final titles = [
      AppConstants.appName,
      'Movimientos',
      'Simulador & Asesor IA',
      'Cuentas y deudas',
      'Perfil',
    ];

    return Scaffold(
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              title: Text(titles[_currentIndex]),
              actions: [
                if (_currentIndex != 4)
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: _logout,
                  ),
              ],
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      floatingActionButton: _currentIndex == 1
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
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Simular',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            activeIcon: Icon(Icons.account_balance),
            label: 'Cuentas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
