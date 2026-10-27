import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transactions/add_transaction_screen.dart';

const _monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// Dashboard (P1). Solo muestra lo que la API ya calcula; saldo libre proyectado,
/// presupuestos y metas se agregan cuando existan sus endpoints.
class DashboardTab extends StatelessWidget {
  final VoidCallback onNavigateToAccounts;
  final VoidCallback onNavigateToTransactions;
  final VoidCallback onNavigateToSimulator;

  const DashboardTab({
    super.key,
    required this.onNavigateToAccounts,
    required this.onNavigateToTransactions,
    required this.onNavigateToSimulator,
  });

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final summary = transactionProvider.monthlySummary;

    final accounts = accountProvider.accounts.where((a) => !a.archivada).toList();
    final liquid = accounts.where((a) => a.tipo != 'tarjeta').toList();
    final cards = accounts.where((a) => a.tipo == 'tarjeta').toList();
    final available = liquid.fold<double>(0, (s, a) => s + a.saldoActual);
    final cashTotal = liquid.where((a) => a.tipo == 'efectivo').fold<double>(0, (s, a) => s + a.saldoActual);
    final bankTotal = liquid.where((a) => a.tipo == 'bancaria').fold<double>(0, (s, a) => s + a.saldoActual);
    // RN-CTA-02: la tarjeta es una cuenta cuyo saldo negativo es lo adeudado.
    final cardDebt = cards.fold<double>(0, (s, a) => s + (a.saldoActual < 0 ? -a.saldoActual : 0));

    final now = DateTime.now();
    final periodLabel = '${_monthNames[now.month - 1]} ${now.year}';
    final firstName = (user?.nombre ?? '').trim().split(' ').first;

    return RefreshIndicator(
      onRefresh: () async {
        await accountProvider.fetchAccounts();
        await transactionProvider.fetchTransactions();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(name: firstName, period: periodLabel),
                const SizedBox(height: 16),
                _QuickActions(onSimulate: onNavigateToSimulator),
                const SizedBox(height: 16),
                _AvailableCard(
                  available: available,
                  cash: cashTotal,
                  bank: bankTotal,
                  liquidAccounts: liquid,
                  loading: accountProvider.isLoading && accounts.isEmpty,
                ),
                const SizedBox(height: 12),
                _DebtCard(debt: cardDebt, cardCount: cards.length),
                const SizedBox(height: 12),
                _BalanceCard(
                  income: summary?.ingresos,
                  expenses: summary?.gastos,
                  net: summary?.balanceNeto,
                  period: periodLabel,
                ),
                const SizedBox(height: 12),
                _SpendingDistribution(
                  transactions: transactionProvider.transactions,
                  categoryName: transactionProvider.categoryNameOf,
                  categoryColor: transactionProvider.categoryColorOf,
                  year: now.year,
                  month: now.month,
                ),
                const SizedBox(height: 12),
                _RecentTransactions(
                  transactions: transactionProvider.transactions.take(5).toList(),
                  onSeeAll: onNavigateToTransactions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final String period;
  const _Header({required this.name, required this.period});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.emeraldPrimary,
          child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? '¡Hola!' : '¡Hola, $name!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nx.text),
              ),
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 14, color: context.nx.muted),
                  const SizedBox(width: 4),
                  Text(period, style: TextStyle(fontSize: 13, color: context.nx.muted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Acciones rápidas ─────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onSimulate;
  const _QuickActions({required this.onSimulate});

  @override
  Widget build(BuildContext context) {
    Widget action({
      required IconData icon,
      required String label,
      required Color bg,
      required Color fg,
      Color? border,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: border != null ? Border.all(color: border) : null,
              ),
              child: Column(
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(
          icon: Icons.add_circle_outline,
          label: '+ Transacción',
          bg: AppTheme.emeraldPrimary,
          fg: Colors.white,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          ),
        ),
        const SizedBox(width: 10),
        action(
          icon: Icons.query_stats,
          label: 'Simular',
          bg: context.nx.card,
          fg: context.nx.text,
          border: context.nx.border,
          onTap: onSimulate,
        ),
        const SizedBox(width: 10),
        action(
          icon: Icons.auto_awesome,
          label: 'Preguntar a IA',
          bg: AppTheme.indigoAI.withValues(alpha: 0.14),
          fg: context.nx.text,
          border: AppTheme.indigoAI.withValues(alpha: 0.4),
          onTap: onSimulate,
        ),
      ],
    );
  }
}

// ───────────────────────── Tarjetas ─────────────────────────

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.nx.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: context.nx.border),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
  );
}

class _AvailableCard extends StatelessWidget {
  final double available;
  final double cash;
  final double bank;
  final List<AccountModel> liquidAccounts;
  final bool loading;

  const _AvailableCard({
    required this.available,
    required this.cash,
    required this.bank,
    required this.liquidAccounts,
    required this.loading,
  });

  void _explain(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nx.surface,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cómo se calculó?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ctx.nx.text)),
            const SizedBox(height: 8),
            Text(
              'El saldo disponible es la suma de tus cuentas de efectivo y bancarias activas. '
              'No incluye tarjetas de crédito ni cuentas archivadas.',
              style: TextStyle(color: ctx.nx.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (liquidAccounts.isEmpty)
              Text('Aún no tienes cuentas de efectivo o bancarias.', style: TextStyle(color: ctx.nx.muted))
            else
              ...liquidAccounts.map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(a.nombre, style: TextStyle(color: ctx.nx.text)),
                      Text(CurrencyFormatter.format(a.saldoActual),
                          style: TextStyle(fontWeight: FontWeight.w600, color: ctx.nx.text)),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: ctx.nx.text)),
                Text(CurrencyFormatter.format(available),
                    style: TextStyle(fontWeight: FontWeight.bold, color: ctx.nx.text)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 18, color: context.nx.muted),
              const SizedBox(width: 8),
              Text('SALDO DISPONIBLE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.nx.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(available),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: context.nx.text),
          ),
          const SizedBox(height: 8),
          Text(
            loading
                ? 'Cargando cuentas…'
                : 'Efectivo: ${CurrencyFormatter.format(cash)} · Banco: ${CurrencyFormatter.format(bank)}',
            style: TextStyle(fontSize: 13, color: context.nx.muted),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _explain(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: context.nx.positive),
                  const SizedBox(width: 6),
                  Text('¿Cómo se calculó?',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.nx.positive)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final double debt;
  final int cardCount;
  const _DebtCard({required this.debt, required this.cardCount});

  @override
  Widget build(BuildContext context) {
    final hasDebt = debt > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card, size: 18, color: context.nx.negative),
                    const SizedBox(width: 8),
                    Text('Deuda en tarjetas',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.nx.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(debt),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: hasDebt ? context.nx.negative : context.nx.text,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      hasDebt ? Icons.info_outline : Icons.check_circle_outline,
                      size: 15,
                      color: hasDebt ? context.nx.warning : context.nx.positive,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        cardCount == 0
                            ? 'Sin tarjetas registradas'
                            : hasDebt
                                ? 'Saldo utilizado de tus tarjetas'
                                : 'Tarjetas al día',
                        style: TextStyle(fontSize: 12, color: context.nx.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double? income;
  final double? expenses;
  final double? net;
  final String period;
  const _BalanceCard({required this.income, required this.expenses, required this.net, required this.period});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 12, color: context.nx.muted)),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ),
      );
    }

    final netValue = net ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance del periodo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('Ingresos', income == null ? '—' : CurrencyFormatter.format(income), context.nx.positive, Icons.south_west),
              const SizedBox(width: 8),
              tile('Gastos', expenses == null ? '—' : CurrencyFormatter.format(expenses), context.nx.negative, Icons.north_east),
              const SizedBox(width: 8),
              tile('Neto', net == null ? '—' : CurrencyFormatter.formatSigned(netValue),
                  netValue < 0 ? context.nx.negative : context.nx.positive, Icons.balance),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.swap_horiz, size: 16, color: context.nx.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Las transferencias entre tus cuentas no cuentan como gasto ni ingreso.',
                  style: TextStyle(fontSize: 12, color: context.nx.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Distribución del gasto ─────────────────────────

class _SpendingDistribution extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String? Function(String?) categoryName;
  final Color Function(String?) categoryColor;
  final int year;
  final int month;

  const _SpendingDistribution({
    required this.transactions,
    required this.categoryName,
    required this.categoryColor,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    // Se calcula con las transacciones ya cargadas (las 50 más recientes).
    final totals = <String?, double>{};
    for (final t in transactions) {
      if (t.tipo == 'gasto' && t.fecha.startsWith(prefix)) {
        totals[t.categoriaId] = (totals[t.categoriaId] ?? 0) + t.monto;
      }
    }
    final grand = totals.values.fold<double>(0, (s, v) => s + v);
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribución de gastos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
          const SizedBox(height: 12),
          if (grand <= 0)
            Text('Aún no hay gastos registrados este mes.', style: TextStyle(color: context.nx.muted))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        flex: (e.value * 1000).round().clamp(1, 1 << 30),
                        child: Container(color: categoryColor(e.key)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final e in entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: categoryColor(e.key), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${categoryName(e.key) ?? 'Sin categoría'}  ${(e.value / grand * 100).round()}%',
                        style: TextStyle(fontSize: 12, color: context.nx.text),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Últimas transacciones ─────────────────────────

class _RecentTransactions extends StatelessWidget {
  final List<TransactionModel> transactions;
  final VoidCallback onSeeAll;
  const _RecentTransactions({required this.transactions, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final accounts = context.read<AccountProvider>();
    final txProvider = context.read<TransactionProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Últimas transacciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
              TextButton(
                onPressed: onSeeAll,
                child: Text('Ver historial', style: TextStyle(color: context.nx.positive)),
              ),
            ],
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Aún no tienes transacciones. Registra la primera con “+ Transacción”.',
                  style: TextStyle(color: context.nx.muted)),
            )
          else
            for (final t in transactions) ...[
              _TransactionRow(
                title: t.descripcion ?? txProvider.categoryNameOf(t.categoriaId) ?? 'Transacción',
                subtitle: '${accounts.nameOf(t.cuentaId)} · ${DateFormatter.format(t.fecha)}',
                tx: t,
              ),
            ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final TransactionModel tx;
  const _TransactionRow({required this.title, required this.subtitle, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isTransfer = tx.isTransfer;
    final isIncome = tx.isIncome && !isTransfer;
    final color = isTransfer ? AppTheme.indigoAI : (isIncome ? context.nx.positive : context.nx.negative);
    final icon = isTransfer ? Icons.swap_horiz : (isIncome ? Icons.south_west : Icons.north_east);
    final kind = isTransfer ? 'Transferencia' : (isIncome ? 'Ingreso' : 'Gasto');
    final amount = isTransfer
        ? CurrencyFormatter.format(tx.monto)
        : CurrencyFormatter.formatSigned(isIncome ? tx.monto : -tx.monto);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.nx.text)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.nx.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              Text(kind, style: TextStyle(fontSize: 11, color: context.nx.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
