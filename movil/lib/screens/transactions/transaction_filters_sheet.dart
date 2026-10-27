import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/history_filter.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

/// Hoja de filtros avanzados (P6). Devuelve el filtro elegido o `null` si se cierra sin aplicar.
Future<HistoryFilter?> showTransactionFiltersSheet(BuildContext context, HistoryFilter current) {
  return showModalBottomSheet<HistoryFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.nx.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
    builder: (_) => _FiltersSheet(initial: current),
  );
}

class _FiltersSheet extends StatefulWidget {
  final HistoryFilter initial;
  const _FiltersSheet({required this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late HistoryFilter _f;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _setPreset(String preset) {
    final t = _today;
    DateTime? desde;
    DateTime? hasta = t;
    switch (preset) {
      case 'mes':
        desde = DateTime(t.year, t.month, 1);
        break;
      case '30d':
        desde = t.subtract(const Duration(days: 30));
        break;
      case 'quincena':
        desde = DateTime(t.year, t.month, t.day <= 15 ? 1 : 16);
        break;
      default: // custom: conserva las fechas actuales para editarlas
        desde = _f.desde;
        hasta = _f.hasta;
    }
    setState(() => _f = _f.copyWith(datePreset: preset, desde: desde, hasta: hasta));
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _f.desde : _f.hasta) ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(_today.year + 1),
      helpText: isFrom ? 'Desde' : 'Hasta',
    );
    if (picked == null) return;
    setState(() {
      _f = isFrom
          ? _f.copyWith(desde: picked, datePreset: 'custom')
          : _f.copyWith(hasta: picked, datePreset: 'custom');
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return ChoiceChip(
      avatar: icon != null ? Icon(icon, size: 16, color: selected ? Colors.white : context.nx.muted) : null,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
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

  Widget _sectionTitle(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text)),
          if (trailing != null) Text(trailing, style: TextStyle(fontSize: 12, color: context.nx.muted)),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: context.nx.muted),
          ),
          child: Text(
            value == null ? 'dd/mm/aaaa' : DateFormatter.format(value),
            style: TextStyle(color: value == null ? context.nx.muted : context.nx.text),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().accounts.where((a) => !a.archivada).toList();
    final categories = context.watch<TransactionProvider>().categories;
    final active = _f.activeCount + (_f.tipo != null ? 1 : 0);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filtros avanzados',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nx.text)),
                ),
                if (active > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldPrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$active activos',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                TextButton(
                  onPressed: () => setState(() => _f = HistoryFilter(busqueda: _f.busqueda)),
                  child: Text('Limpiar todo', style: TextStyle(color: context.nx.positive)),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.nx.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                _sectionTitle('Rango de fechas', trailing: 'Zona horaria: Santo Domingo (AST)'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Este mes', _f.datePreset == 'mes', () => _setPreset('mes')),
                    _chip('Últimos 30 días', _f.datePreset == '30d', () => _setPreset('30d')),
                    _chip('Esta quincena', _f.datePreset == 'quincena', () => _setPreset('quincena')),
                    _chip('Personalizado', _f.datePreset == 'custom', () => _setPreset('custom')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _dateField('Desde', _f.desde, () => _pickDate(isFrom: true)),
                    const SizedBox(width: 12),
                    _dateField('Hasta', _f.hasta, () => _pickDate(isFrom: false)),
                  ],
                ),
                if (_f.desde != null || _f.hasta != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _f = _f.copyWith(desde: null, hasta: null, datePreset: null)),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Quitar fechas'),
                    ),
                  ),

                _sectionTitle('Tipo de movimiento'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Todos', _f.tipo == null, () => setState(() => _f = _f.copyWith(tipo: null))),
                    _chip('Gastos (-)', _f.tipo == 'gasto', () => setState(() => _f = _f.copyWith(tipo: 'gasto')),
                        icon: Icons.north_east),
                    _chip('Ingresos (+)', _f.tipo == 'ingreso', () => setState(() => _f = _f.copyWith(tipo: 'ingreso')),
                        icon: Icons.south_west),
                    _chip('Transferencias', _f.tipo == 'transferencia',
                        () => setState(() => _f = _f.copyWith(tipo: 'transferencia')),
                        icon: Icons.swap_horiz),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.nx.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.nx.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: context.nx.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Las transferencias entre tus cuentas no cuentan como gasto ni ingreso.',
                          style: TextStyle(fontSize: 12, color: context.nx.muted),
                        ),
                      ),
                    ],
                  ),
                ),

                _sectionTitle('Cuenta'),
                _accountTile('Todas las cuentas', null, null),
                for (final a in accounts) _accountTile(a.nombre, a.id, CurrencyFormatter.format(a.saldoActual)),

                _sectionTitle('Categoría'),
                DropdownButtonFormField<String?>(
                  initialValue: _f.categoriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todas las categorías')),
                    for (final c in categories)
                      DropdownMenuItem<String?>(value: c.id, child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _f = _f.copyWith(categoriaId: v)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.nx.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _f = HistoryFilter(busqueda: _f.busqueda)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.nx.text,
                      side: BorderSide(color: context.nx.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Restablecer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(_f),
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: const Text('Aplicar filtros'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountTile(String name, String? id, String? balance) {
    final selected = _f.cuentaId == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _f = _f.copyWith(cuentaId: id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.emeraldPrimary.withValues(alpha: 0.10) : context.nx.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.emeraldPrimary : context.nx.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? context.nx.positive : context.nx.muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: context.nx.text))),
              if (balance != null) Text(balance, style: TextStyle(fontSize: 13, color: context.nx.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
