import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/history_filter.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/tx_style.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_filters_sheet.dart';

const _monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// Historial de movimientos (P6): búsqueda, filtros, agrupación por día y paginación.
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TransactionProvider>().fetchHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final provider = context.read<TransactionProvider>();
    final text = _searchController.text.trim();
    provider.fetchHistory(filter: provider.historyFilter.copyWith(busqueda: text.isEmpty ? null : text));
  }

  Future<void> _openFilters() async {
    final provider = context.read<TransactionProvider>();
    final result = await showTransactionFiltersSheet(context, provider.historyFilter);
    if (result != null && mounted) provider.fetchHistory(filter: result);
  }

  String _dayLabel(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final formatted = DateFormatter.format(day);
    if (day == today) return 'Hoy, $formatted';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer, $formatted';
    return formatted;
  }

  Widget _chip(String value, String label, HistoryFilter filter, int total) {
    final selected = (filter.tipo ?? 'todos') == value;
    final provider = context.read<TransactionProvider>();
    return ChoiceChip(
      label: Text(selected ? '$label  $total' : label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => provider.fetchHistory(filter: filter.copyWith(tipo: value == 'todos' ? null : value)),
      selectedColor: AppTheme.emeraldPrimary,
      backgroundColor: context.nx.card,
      side: BorderSide(color: selected ? AppTheme.emeraldPrimary : context.nx.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : context.nx.text,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  Widget _summaryCard(TransactionProvider provider) {
    final now = DateTime.now();
    final s = provider.monthlySummary;
    Widget cell(String label, double? value, Color color, IconData icon, {bool signed = false}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: context.nx.muted))),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value == null ? '—' : (signed ? CurrencyFormatter.formatSigned(value) : CurrencyFormatter.format(value)),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.nx.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.nx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de ${_monthNames[now.month - 1]}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.nx.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              cell('Ingresos', s?.ingresos, context.nx.positive, Icons.south_west),
              const SizedBox(width: 12),
              cell('Gastos', s?.gastos, context.nx.negative, Icons.north_east),
              const SizedBox(width: 12),
              cell('Balance neto', s?.balanceNeto, (s?.balanceNeto ?? 0) < 0 ? context.nx.negative : context.nx.positive,
                  Icons.balance, signed: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(TransactionModel t) {
    final style = TxStyle.of(context, t);
    final provider = context.read<TransactionProvider>();
    final category = provider.categoryNameOf(t.categoriaId);
    final account = context.read<AccountProvider>().nameOf(t.cuentaId);
    final title = (t.descripcion != null && t.descripcion!.isNotEmpty) ? t.descripcion! : (category ?? 'Movimiento');

    return Semantics(
      button: true,
      label: '$title, ${style.label}, ${style.amountText}',
      child: InkWell(
        onTap: () => showTransactionDetailSheet(context, t),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.nx.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.nx.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(style.icon, color: style.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                    const SizedBox(height: 2),
                    Text(
                      category == null ? account : '$account · $category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.nx.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(style.amountText, style: TextStyle(fontWeight: FontWeight.w800, color: style.color)),
                  Text(style.label, style: TextStyle(fontSize: 11, color: context.nx.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _groupedRows(List<TransactionModel> items) {
    final groups = <String, List<TransactionModel>>{};
    for (final t in items) {
      groups.putIfAbsent(t.fecha, () => []).add(t);
    }
    final widgets = <Widget>[];
    groups.forEach((date, list) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: context.nx.muted),
                const SizedBox(width: 6),
                Text(_dayLabel(date), style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
              ],
            ),
            Text('${list.length} ${list.length == 1 ? 'transacción' : 'transacciones'}',
                style: TextStyle(fontSize: 12, color: context.nx.muted)),
          ],
        ),
      ));
      for (final t in list) {
        widgets.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: _row(t)));
      }
    });
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final filter = provider.historyFilter;
    final items = provider.history;
    final now = DateTime.now();
    final hasActiveFilters = filter.activeCount > 0 || filter.tipo != null || (filter.busqueda ?? '').isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchHistory();
          await provider.fetchMonthlySummary();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '${_monthNames[now.month - 1]} ${now.year} · ${provider.historyTotal} '
              '${provider.historyTotal == 1 ? 'registro' : 'registros'}${hasActiveFilters ? ' (filtrados)' : ''}',
              style: TextStyle(fontSize: 13, color: context.nx.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applySearch(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar por comercio o concepto…',
                      prefixIcon: Icon(Icons.search, color: context.nx.muted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Borrar búsqueda',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _applySearch();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Filtros avanzados',
                  child: InkWell(
                    onTap: _openFilters,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: filter.activeCount > 0 ? AppTheme.emeraldPrimary : context.nx.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: filter.activeCount > 0 ? AppTheme.emeraldPrimary : context.nx.border),
                      ),
                      child: Badge(
                        isLabelVisible: filter.activeCount > 0,
                        label: Text('${filter.activeCount}'),
                        child: Icon(Icons.tune, color: filter.activeCount > 0 ? Colors.white : context.nx.text),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('todos', 'Todas', filter, provider.historyTotal),
                  const SizedBox(width: 8),
                  _chip('gasto', 'Gastos', filter, provider.historyTotal),
                  const SizedBox(width: 8),
                  _chip('ingreso', 'Ingresos', filter, provider.historyTotal),
                  const SizedBox(width: 8),
                  _chip('transferencia', 'Transferencias', filter, provider.historyTotal),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _summaryCard(provider),
            if (provider.historyLoading && items.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 54, color: context.nx.muted),
                    const SizedBox(height: 12),
                    Text('Sin movimientos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
                    const SizedBox(height: 6),
                    Text(
                      hasActiveFilters
                          ? 'No se encontraron transacciones con los filtros actuales.'
                          : 'Aún no tienes transacciones registradas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.nx.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (hasActiveFilters)
                      OutlinedButton.icon(
                        onPressed: () => provider.fetchHistory(filter: const HistoryFilter()),
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Quitar filtros'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar movimiento'),
                      ),
                  ],
                ),
              )
            else ...[
              ..._groupedRows(items),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Mostrando ${items.length} de ${provider.historyTotal}',
                  style: TextStyle(fontSize: 12, color: context.nx.muted),
                ),
              ),
              if (provider.historyHasMore) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: provider.historyLoading ? null : provider.loadMoreHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.nx.positive,
                    side: BorderSide(color: context.nx.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: provider.historyLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cargar más'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
