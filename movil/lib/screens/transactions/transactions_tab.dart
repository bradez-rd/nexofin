import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _selectedFilter = 'todos'; // 'todos', 'ingreso', 'gasto', 'transferencia'
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final provider = context.read<TransactionProvider>();
    provider.fetchTransactions(
      tipo: _selectedFilter == 'todos' ? null : _selectedFilter,
      busqueda: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
  }

  void _showTransactionDetails(TransactionModel trx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trx.tipo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: trx.isTransfer
                        ? AppTheme.indigoAI
                        : (trx.isIncome ? AppTheme.emeraldLight : AppTheme.errorRed),
                  ),
                ),
                Text(
                  DateFormatter.format(trx.fecha),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(trx.monto),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: trx.isTransfer
                    ? AppTheme.indigoAI
                    : (trx.isIncome ? AppTheme.emeraldLight : AppTheme.errorRed),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow('Descripción', trx.descripcion ?? 'Sin descripción'),
            _buildDetailRow('Cuenta', trx.cuentaNombre ?? trx.cuentaId),
            if (trx.categoriaNombre != null)
              _buildDetailRow('Categoría', trx.categoriaNombre!),
            if (trx.nota != null && trx.nota!.isNotEmpty)
              _buildDetailRow('Nota', trx.nota!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final ok = await context.read<TransactionProvider>().deleteTransaction(trx.id);
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transacción eliminada (baja lógica)')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar Transacción'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final trxs = transactionProvider.transactions;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => transactionProvider.fetchTransactions(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar transacción...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _applyFilters(),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('todos', 'Todos'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ingreso', 'Ingresos'),
                    const SizedBox(width: 8),
                    _buildFilterChip('gasto', 'Gastos'),
                    const SizedBox(width: 8),
                    _buildFilterChip('transferencia', 'Transferencias'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // List of transactions
              Expanded(
                child: transactionProvider.isLoading && trxs.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : trxs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 54, color: Color(0xFF64748B)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Sin movimientos',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'No se encontraron transacciones con los filtros actuales.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const AddTransactionScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Registrar Movimiento'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: trxs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final trx = trxs[idx];
                              final isIncome = trx.isIncome;
                              final isTransfer = trx.isTransfer;

                              return InkWell(
                                onTap: () => _showTransactionDetails(trx),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkCard,
                                    borderRadius: BorderRadius.circular(14),
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
                                              trx.descripcion ?? trx.categoriaNombre ?? 'Movimiento',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
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
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = value);
          _applyFilters();
        }
      },
      selectedColor: AppTheme.emeraldPrimary,
      backgroundColor: AppTheme.darkSurface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}
