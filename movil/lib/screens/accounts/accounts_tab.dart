import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/account_model.dart';
import '../../providers/account_provider.dart';
import '../transactions/add_transaction_screen.dart';
import 'account_sheets.dart';

/// Cuentas y tarjetas (P4). Las deudas tipo préstamo llegarán con su endpoint.
class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  int _tab = 0; // 0 = cuentas disponibles, 1 = tarjetas

  Future<void> _archive(AccountModel acc) async {
    final provider = context.read<AccountProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nx.surface,
        title: const Text('Archivar cuenta'),
        content: Text(
          '“${acc.nombre}” dejará de aceptar movimientos nuevos y de aparecer en tus listados. '
          'Su historial se conserva en los reportes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.nx.warning),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await provider.archiveAccount(acc.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Cuenta archivada.' : (provider.errorMessage ?? 'No se pudo archivar.'))),
    );
  }

  void _transferFrom(AccountModel acc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: 'transferencia', initialAccountId: acc.id),
      ),
    );
  }

  Widget _summaryCard(double available, double debt, int liquidCount, int cardCount) {
    Widget tile(String label, double value, Color color, IconData icon, String foot) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 5),
                  Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: context.nx.muted))),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(CurrencyFormatter.format(value),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.nx.text)),
              ),
              const SizedBox(height: 4),
              Text(foot, style: TextStyle(fontSize: 11, color: context.nx.muted)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.nx.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.nx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 16, color: context.nx.muted),
              const SizedBox(width: 6),
              Text('Posición neta consolidada',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.nx.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('Disponible real', available, context.nx.positive, Icons.savings_outlined,
                  '$liquidCount ${liquidCount == 1 ? 'cuenta' : 'cuentas'}'),
              const SizedBox(width: 10),
              tile('Deuda en tarjetas', debt, context.nx.negative, Icons.credit_card,
                  '$cardCount ${cardCount == 1 ? 'tarjeta' : 'tarjetas'}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.indigoAI.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.indigoAI),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Regla de liquidez: las tarjetas de crédito no suman a tus fondos disponibles. '
                    'Su saldo representa deuda corriente activa.',
                    style: TextStyle(fontSize: 12, color: context.nx.text, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(int liquidCount, int cardCount) {
    Widget tab(int index, String label, IconData icon) {
      final selected = _tab == index;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _tab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: selected ? context.nx.card : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: selected ? context.nx.positive : context.nx.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? context.nx.positive : context.nx.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.nx.border),
      ),
      child: Row(
        children: [
          tab(0, 'Cuentas ($liquidCount)', Icons.account_balance_outlined),
          tab(1, 'Tarjetas ($cardCount)', Icons.credit_card_outlined),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, VoidCallback onNew, String newLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: context.nx.muted)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 18),
          label: Text(newLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.nx.positive,
            side: BorderSide(color: context.nx.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color ?? context.nx.muted),
      label: Text(label, style: TextStyle(fontSize: 12, color: color ?? context.nx.muted)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 36)),
    );
  }

  Widget _accountCard(AccountModel acc) {
    final isCash = acc.tipo == 'efectivo';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.nx.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.nx.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isCash ? Icons.payments_outlined : Icons.account_balance_outlined,
                    color: context.nx.positive),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.nx.text)),
                    Text(isCash ? 'Efectivo en mano' : 'Cuenta bancaria',
                        style: TextStyle(fontSize: 12, color: context.nx.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Saldo actual', style: TextStyle(fontSize: 11, color: context.nx.muted)),
                  Text(
                    CurrencyFormatter.format(acc.saldoActual, currency: acc.moneda),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: acc.saldoActual < 0 ? context.nx.negative : context.nx.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 18, color: context.nx.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionButton('Transferir', Icons.swap_horiz, () => _transferFrom(acc), color: context.nx.positive),
              _actionButton('Editar', Icons.edit_outlined, () => showAccountFormSheet(context, existing: acc)),
              _actionButton('Archivar', Icons.archive_outlined, () => _archive(acc)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardAccount(AccountModel acc) {
    final debt = acc.saldoActual < 0 ? -acc.saldoActual : 0.0;
    final limit = acc.limiteCredito;
    final used = (limit != null && limit > 0) ? debt / limit : null;
    final Color barColor = used == null
        ? context.nx.muted
        : used >= 1
            ? context.nx.negative
            : used >= 0.8
                ? context.nx.warning
                : context.nx.positive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.nx.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: debt > 0 ? context.nx.negative.withValues(alpha: 0.5) : context.nx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.nx.negative.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.credit_card, color: context.nx.negative),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.nx.text)),
                    Text('Tarjeta de crédito', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Deuda utilizada', style: TextStyle(fontSize: 11, color: context.nx.muted)),
                  Text(
                    CurrencyFormatter.format(debt, currency: acc.moneda),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: debt > 0 ? context.nx.negative : context.nx.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (limit != null && limit > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Límite aprobado: ${CurrencyFormatter.format(limit)}',
                    style: TextStyle(fontSize: 12, color: context.nx.muted)),
                Row(
                  children: [
                    if (used! >= 0.8) Icon(Icons.warning_amber_rounded, size: 14, color: barColor),
                    const SizedBox(width: 2),
                    Text('${(used * 100).toStringAsFixed(1)}% consumido',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: barColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: used.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: context.nx.border,
                color: barColor,
              ),
            ),
            const SizedBox(height: 6),
            Text('Crédito disponible: ${CurrencyFormatter.format((limit - debt).clamp(0, double.infinity))}',
                style: TextStyle(fontSize: 12, color: context.nx.muted)),
          ],
          if (acc.diaCorte != null || acc.diaPago != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.nx.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.nx.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 16, color: context.nx.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (acc.diaCorte != null) 'Corte: día ${acc.diaCorte}',
                        if (acc.diaPago != null) 'Pago: día ${acc.diaPago}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: context.nx.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: debt > 0 ? () => showCardPaymentSheet(context, acc) : null,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Abonar a tarjeta'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Editar tarjeta',
                icon: Icon(Icons.edit_outlined, color: context.nx.muted),
                onPressed: () => showAccountFormSheet(context, existing: acc),
              ),
              IconButton(
                tooltip: 'Archivar tarjeta',
                icon: Icon(Icons.archive_outlined, color: context.nx.muted),
                onPressed: () => _archive(acc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(String title, String body, String button, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.nx.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.nx.border),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_outlined, size: 46, color: context.nx.muted),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: context.nx.muted)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onTap, child: Text(button)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountProvider>();
    final active = provider.accounts.where((a) => !a.archivada).toList();
    final liquid = active.where((a) => a.tipo != 'tarjeta').toList();
    final cards = active.where((a) => a.tipo == 'tarjeta').toList();
    final available = liquid.fold<double>(0, (s, a) => s + a.saldoActual);
    final debt = cards.fold<double>(0, (s, a) => s + (a.saldoActual < 0 ? -a.saldoActual : 0));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAccounts(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _summaryCard(available, debt, liquid.length, cards.length),
            const SizedBox(height: 14),
            _tabs(liquid.length, cards.length),
            const SizedBox(height: 16),
            if (provider.isLoading && active.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_tab == 0) ...[
              _sectionHeader('Cuentas bancarias y efectivo', '${liquid.length} activas',
                  () => showAccountFormSheet(context), 'Nueva'),
              const SizedBox(height: 12),
              if (liquid.isEmpty)
                _empty('Aún no tienes cuentas', 'Agrega tu cuenta bancaria o tu efectivo para empezar a registrar movimientos.',
                    'Crear primera cuenta', () => showAccountFormSheet(context))
              else
                for (final a in liquid) Padding(padding: const EdgeInsets.only(bottom: 12), child: _accountCard(a)),
            ] else ...[
              _sectionHeader('Tarjetas de crédito', '${cards.length} activas',
                  () => showAccountFormSheet(context, defaultType: 'tarjeta'), 'Nueva'),
              const SizedBox(height: 12),
              if (cards.isEmpty)
                _empty('Sin tarjetas registradas', 'Registra una tarjeta para ver tu deuda, tu límite y las fechas de corte y pago.',
                    'Agregar tarjeta', () => showAccountFormSheet(context, defaultType: 'tarjeta'))
              else
                for (final a in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: _cardAccount(a)),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.nx.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.nx.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hourglass_empty, size: 18, color: context.nx.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los préstamos con calendario de cuotas estarán disponibles próximamente.',
                        style: TextStyle(fontSize: 12, color: context.nx.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
