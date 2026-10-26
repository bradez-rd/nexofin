import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transactions/add_transaction_screen.dart';

class DashboardTab extends StatelessWidget {
  final VoidCallback onNavigateToAccounts;
  final VoidCallback onNavigateToTransactions;

  const DashboardTab({
    super.key,
    required this.onNavigateToAccounts,
    required this.onNavigateToTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final summary = transactionProvider.monthlySummary;

    return RefreshIndicator(
      onRefresh: () async {
        await accountProvider.fetchAccounts();
        await transactionProvider.fetchTransactions();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Net Worth Hero Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.emeraldPrimary, Color(0xFF0F3B30), AppTheme.darkSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emeraldPrimary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: AppTheme.emeraldLight.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Patrimonio Neto Total',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.emeraldLight),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 14, color: AppTheme.emeraldLight),
                            SizedBox(width: 4),
                            Text(
                              'Determinístico',
                              style: TextStyle(
                                color: AppTheme.emeraldLight,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    CurrencyFormatter.format(accountProvider.totalNetWorthDOP),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.account_balance, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        '${accountProvider.accounts.length} Cuentas Activas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Monthly Flow Summary (Ingresos vs Gastos)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldLight.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_downward, color: AppTheme.emeraldLight, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Ingresos (Mes)',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          CurrencyFormatter.format(summary?.ingresos ?? 0),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emeraldLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_upward, color: AppTheme.errorRed, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Gastos (Mes)',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          CurrencyFormatter.format(summary?.gastos ?? 0),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(
                  context: context,
                  icon: Icons.add,
                  label: 'Ingreso',
                  color: AppTheme.emeraldLight,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddTransactionScreen(initialType: 'ingreso'),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context: context,
                  icon: Icons.remove,
                  label: 'Gasto',
                  color: AppTheme.errorRed,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddTransactionScreen(initialType: 'gasto'),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context: context,
                  icon: Icons.swap_horiz,
                  label: 'Transferir',
                  color: AppTheme.indigoAI,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddTransactionScreen(initialType: 'transferencia'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Accounts Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis Cuentas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: onNavigateToAccounts,
                  child: const Text('Ver todas', style: TextStyle(color: AppTheme.emeraldLight)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Accounts horizontal list
            if (accountProvider.accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Center(
                  child: Text(
                    'No tienes cuentas registradas. Pulsa en Cuentas para agregar una.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SizedBox(
                height: 125,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accountProvider.accounts.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final acc = accountProvider.accounts[idx];
                    return Container(
                      width: 170,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                acc.tipo == 'efectivo'
                                    ? Icons.money
                                    : (acc.tipo == 'tarjeta'
                                        ? Icons.credit_card
                                        : Icons.account_balance),
                                color: AppTheme.emeraldLight,
                                size: 20,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkSurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  acc.tipo.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(acc.saldoActual, currency: acc.moneda),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.emeraldLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Últimos Movimientos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: onNavigateToTransactions,
                  child: const Text('Ver historial', style: TextStyle(color: AppTheme.emeraldLight)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Recent Transactions List
            if (transactionProvider.transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Center(
                  child: Text(
                    'No hay transacciones registradas aún.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactionProvider.transactions.take(5).length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final trx = transactionProvider.transactions[idx];
                  final isIncome = trx.isIncome;
                  final isTransfer = trx.isTransfer;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isTransfer
                                ? AppTheme.indigoAI.withValues(alpha: 0.15)
                                : (isIncome
                                    ? AppTheme.emeraldLight.withValues(alpha: 0.15)
                                    : AppTheme.errorRed.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isTransfer
                                ? Icons.swap_horiz
                                : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                            color: isTransfer
                                ? AppTheme.indigoAI
                                : (isIncome ? AppTheme.emeraldLight : AppTheme.errorRed),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trx.descripcion ?? trx.categoriaNombre ?? 'Transacción',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormatter.format(trx.fecha)} • ${trx.cuentaNombre ?? "Cuenta"}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          isTransfer
                              ? CurrencyFormatter.format(trx.monto)
                              : CurrencyFormatter.formatSigned(
                                  isIncome ? trx.monto : -trx.monto,
                                ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isTransfer
                                ? AppTheme.indigoAI
                                : (isIncome ? AppTheme.emeraldLight : AppTheme.errorRed),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
