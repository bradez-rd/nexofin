import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/tx_style.dart';

/// Detalle y edición de una transacción (P6).
Future<void> showTransactionDetailSheet(BuildContext context, TransactionModel tx) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.nx.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
    builder: (_) => _DetailSheet(tx: tx),
  );
}

class _DetailSheet extends StatefulWidget {
  final TransactionModel tx;
  const _DetailSheet({required this.tx});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _editing = false;
  bool _saving = false;
  String? _error;

  late final TextEditingController _montoCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _notaCtrl;
  late DateTime _fecha;
  String? _categoriaId;

  TransactionModel get tx => widget.tx;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(text: tx.monto.toStringAsFixed(2));
    _descCtrl = TextEditingController(text: tx.descripcion ?? '');
    _notaCtrl = TextEditingController(text: tx.nota ?? '');
    _fecha = DateTime.tryParse(tx.fecha) ?? DateTime.now();
    _categoriaId = tx.categoriaId;
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshBalances() async {
    // Los saldos de las cuentas se derivan en el servidor: se vuelven a pedir.
    await context.read<AccountProvider>().fetchAccounts();
  }

  Future<void> _save() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      setState(() => _error = 'El monto debe ser mayor que cero.');
      return;
    }
    final today = DateTime.now();
    if (_fecha.isAfter(DateTime(today.year, today.month, today.day))) {
      setState(() => _error = 'La fecha no puede ser posterior a hoy.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = context.read<TransactionProvider>();
    final ok = await provider.updateTransaction(
      tx.id,
      monto: monto,
      fecha: DateFormatter.toApiDate(_fecha),
      descripcion: _descCtrl.text.trim(),
      nota: _notaCtrl.text.trim(),
      categoriaId: _categoriaId,
    );
    if (!mounted) return;
    if (ok) {
      await _refreshBalances();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados. El valor anterior queda en el historial.')));
    } else {
      setState(() {
        _saving = false;
        _error = provider.errorMessage ?? 'No se pudieron guardar los cambios.';
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nx.surface,
        title: const Text('Eliminar transacción'),
        content: const Text(
          'La transacción se dará de baja y los saldos se recalcularán. Esta acción queda registrada en la bitácora.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.nx.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context.read<TransactionProvider>().deleteTransaction(tx.id);
    if (!mounted) return;
    if (ok) {
      await _refreshBalances();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transacción eliminada.')));
    } else {
      setState(() => _error = context.read<TransactionProvider>().errorMessage ?? 'No se pudo eliminar.');
    }
  }

  Widget _modeTabs() {
    Widget tab(String label, IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
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
                Icon(icon, size: 18, color: selected ? context.nx.positive : context.nx.muted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: selected ? context.nx.positive : context.nx.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.nx.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.nx.border),
      ),
      child: Row(
        children: [
          tab('Ver detalle', Icons.visibility_outlined, !_editing, () => setState(() => _editing = false)),
          tab('Editar campos', Icons.edit_outlined, _editing, () => setState(() => _editing = true)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.nx.muted, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600, color: context.nx.text, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(TxStyle style, String title) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(style.icon, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.nx.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(style.label, style: TextStyle(color: style.color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(style.amountText,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: style.color)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule, size: 15, color: context.nx.muted),
              const SizedBox(width: 6),
              Text(DateFormatter.format(tx.fecha), style: TextStyle(fontSize: 13, color: context.nx.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewBody(TxStyle style, String title, String account, String? category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryCard(style, title),
        const SizedBox(height: 8),
        _row('Cuenta', account),
        Divider(height: 1, color: context.nx.border),
        _row('Categoría', category ?? 'Sin categoría'),
        if (tx.nota != null && tx.nota!.isNotEmpty) ...[
          Divider(height: 1, color: context.nx.border),
          _row('Nota', tx.nota!),
        ],
        if (tx.isTransfer) ...[
          Divider(height: 1, color: context.nx.border),
          _row('Efecto', 'No cuenta como gasto ni ingreso'),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar transacción'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.nx.negative,
            side: BorderSide(color: context.nx.negative),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _editBody(TxStyle style, List<CategoryModel> categories) {
    if (tx.isTransfer) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.nx.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.nx.border),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: context.nx.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Las transferencias no se pueden editar. Elimínala y regístrala de nuevo con los datos correctos.',
                style: TextStyle(color: context.nx.muted),
              ),
            ),
          ],
        ),
      );
    }
    final kindCategories = categories.where((c) => c.tipo == style.label.toLowerCase() || c.tipo == 'ambos').toList();
    final categoryValue = kindCategories.any((c) => c.id == _categoriaId) ? _categoriaId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(style.icon, color: style.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tipo: ${style.label} · Cuenta: ${context.read<AccountProvider>().nameOf(tx.cuentaId)}. '
                  'El tipo y la cuenta no se pueden cambiar.',
                  style: TextStyle(fontSize: 12, color: context.nx.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _montoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto (RD\$)', prefixIcon: Icon(Icons.payments_outlined)),
        ),
        const SizedBox(height: 4),
        Text('El monto se ingresa siempre positivo; el tipo define si resta o suma.',
            style: TextStyle(fontSize: 12, color: context.nx.muted)),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descCtrl,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Comercio o concepto', counterText: '', prefixIcon: Icon(Icons.storefront_outlined)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _fecha,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _fecha = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today_outlined)),
            child: Text(DateFormatter.format(_fecha), style: TextStyle(color: context.nx.text)),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: categoryValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.category_outlined)),
          items: [
            for (final c in kindCategories)
              DropdownMenuItem<String?>(value: c.id, child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _categoriaId = v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _notaCtrl,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Nota', counterText: '', prefixIcon: Icon(Icons.notes_outlined)),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final style = TxStyle.of(context, tx);
    final category = txProvider.categoryNameOf(tx.categoriaId);
    final account = context.read<AccountProvider>().nameOf(tx.cuentaId);
    final title = tx.descripcion?.isNotEmpty == true ? tx.descripcion! : (category ?? 'Transacción');

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Detalle de transacción',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nx.text)),
                ),
                IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _modeTabs(),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.nx.negative.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.nx.negative.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: context.nx.negative),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: context.nx.text))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_editing) _editBody(style, txProvider.categories) else _viewBody(style, title, account, category),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
