import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/account_model.dart';
import '../../providers/account_provider.dart';

class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key});

  void _showCreateAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    final creditLimitController = TextEditingController();
    String selectedType = 'bancaria';
    String selectedCurrency = 'DOP';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Nueva Cuenta Financiera'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Cuenta',
                    hintText: 'Ej. Cuenta Nómina Banreservas',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo de Cuenta'),
                  items: const [
                    DropdownMenuItem(value: 'bancaria', child: Text('Cuenta Bancaria')),
                    DropdownMenuItem(value: 'efectivo', child: Text('Efectivo / Billetera')),
                    DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta de Crédito')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  decoration: const InputDecoration(labelText: 'Moneda'),
                  items: const [
                    DropdownMenuItem(value: 'DOP', child: Text('Peso Dominicano (RD\$ DOP)')),
                    DropdownMenuItem(value: 'USD', child: Text('Dólar Estadounidense (US\$ USD)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedCurrency = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Saldo Inicial (RD\$)',
                    prefixText: 'RD\$ ',
                  ),
                ),
                if (selectedType == 'tarjeta') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: creditLimitController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Límite de Crédito (opcional)',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final saldo = double.tryParse(balanceController.text) ?? 0.0;
                final limit = double.tryParse(creditLimitController.text);

                final provider = context.read<AccountProvider>();
                final ok = await provider.createAccount(
                  nombre: name,
                  tipo: selectedType,
                  moneda: selectedCurrency,
                  saldoInicial: saldo,
                  limiteCredito: limit,
                );

                if (ctx.mounted) Navigator.of(ctx).pop();

                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'Error al crear cuenta'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              },
              child: const Text('Crear Cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => accountProvider.fetchAccounts(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Summary Box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cuentas y Depósitos',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${accountProvider.accounts.length} activas registradas',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => _showCreateAccountDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Currency Summaries
              if (accountProvider.summaries.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: accountProvider.summaries.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: s.moneda == 'DOP' ? AppTheme.emeraldLight : Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${s.moneda}: ${CurrencyFormatter.format(s.patrimonioNeto, currency: s.moneda)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // Accounts List
              if (accountProvider.isLoading && accountProvider.accounts.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (accountProvider.accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_outlined, size: 48, color: Color(0xFF64748B)),
                      const SizedBox(height: 12),
                      const Text(
                        'No tienes cuentas registradas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Agrega tu cuenta bancaria o billetera para comenzar el cálculo determinístico de saldos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showCreateAccountDialog(context),
                        child: const Text('Crear Primera Cuenta'),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accountProvider.accounts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final acc = accountProvider.accounts[idx];
                    return _buildAccountTile(context, acc, accountProvider);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, AccountModel acc, AccountProvider provider) {
    IconData icon;
    switch (acc.tipo) {
      case 'efectivo':
        icon = Icons.payments_outlined;
        break;
      case 'tarjeta':
        icon = Icons.credit_card_outlined;
        break;
      default:
        icon = Icons.account_balance_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.emeraldPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.emeraldLight, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acc.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      acc.tipo.toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• Inicial: ${CurrencyFormatter.format(acc.saldoInicial, currency: acc.moneda)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(acc.saldoActual, currency: acc.moneda),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emeraldLight,
                ),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                color: AppTheme.darkSurface,
                onSelected: (val) {
                  if (val == 'archive') {
                    provider.archiveAccount(acc.id);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18, color: AppTheme.warningAmber),
                        SizedBox(width: 8),
                        Text('Archivar Cuenta'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
