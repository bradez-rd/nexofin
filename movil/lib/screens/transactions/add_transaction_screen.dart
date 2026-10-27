import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/account_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

/// Nueva transacción (P2): ingreso, gasto, transferencia o ajuste.
class AddTransactionScreen extends StatefulWidget {
  final String initialType; // ingreso | gasto | transferencia | ajuste
  final String? initialAccountId;

  const AddTransactionScreen({super.key, this.initialType = 'gasto', this.initialAccountId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late String _type;
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _notaController = TextEditingController();

  // Solo fecha (sin hora): RN-TRX-02 compara por día.
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String? _originId;
  String? _destinationId;
  String? _categoryId;
  String _sentido = 'entrada'; // solo ajustes
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _originId = widget.initialAccountId;
    _montoController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final accounts = context.read<AccountProvider>();
      if (accounts.accounts.isEmpty) await accounts.fetchAccounts();
      if (!mounted) return;
      context.read<TransactionProvider>().fetchCategories();
      final active = accounts.accounts.where((a) => !a.archivada).toList();
      setState(() {
        _originId ??= active.isNotEmpty ? active.first.id : null;
      });
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  double? get _monto => double.tryParse(_montoController.text.trim().replaceAll(',', '.'));
  bool get _amountValid => (_monto ?? 0) > 0;
  bool get _isTransfer => _type == 'transferencia';

  String get _kindLabel => switch (_type) {
        'ingreso' => 'ingreso',
        'transferencia' => 'traslado',
        'ajuste' => 'ajuste',
        _ => 'gasto',
      };

  void _addQuick(double v) {
    final current = _monto ?? 0;
    final next = current + v;
    _montoController.text = next == next.roundToDouble() ? next.toStringAsFixed(0) : next.toStringAsFixed(2);
    _montoController.selection = TextSelection.collapsed(offset: _montoController.text.length);
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      _categoryId = null; // las categorías cambian según el tipo
      _error = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_amountValid) {
      setState(() => _error = 'El monto debe ser mayor que cero.');
      return;
    }
    final today = DateTime.now();
    if (_selectedDate.isAfter(DateTime(today.year, today.month, today.day))) {
      setState(() => _error = 'La fecha no puede ser posterior a hoy.');
      return;
    }
    if (_originId == null) {
      setState(() => _error = 'Selecciona una cuenta.');
      return;
    }
    if (_isTransfer) {
      if (_destinationId == null) {
        setState(() => _error = 'Selecciona la cuenta de destino.');
        return;
      }
      if (_destinationId == _originId) {
        setState(() => _error = 'La cuenta de origen y la de destino deben ser distintas.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final trx = context.read<TransactionProvider>();
    final accounts = context.read<AccountProvider>();
    final date = DateFormatter.toApiDate(_selectedDate);
    final desc = _descripcionController.text.trim();
    final bool ok;

    if (_isTransfer) {
      ok = await trx.createTransfer(
        cuentaOrigenId: _originId!,
        cuentaDestinoId: _destinationId!,
        monto: _monto!,
        fecha: date,
        descripcion: desc.isEmpty ? 'Transferencia entre cuentas' : desc,
      );
    } else {
      ok = await trx.createTransaction(
        cuentaId: _originId!,
        categoriaId: _type == 'ajuste' ? null : _categoryId,
        tipo: _type,
        monto: _monto!,
        fecha: date,
        descripcion: desc.isEmpty ? _defaultDescription : desc,
        nota: _notaController.text.trim().isEmpty ? null : _notaController.text.trim(),
        sentido: _type == 'ajuste' ? _sentido : null,
      );
    }

    if (!mounted) return;
    if (ok) {
      await accounts.fetchAccounts();
      if (!mounted) return;
      final acc = accounts.accounts.where((a) => a.id == _originId).firstOrNull;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            acc == null
                ? '¡Transacción guardada!'
                : '¡Transacción guardada! Nuevo saldo en ${acc.nombre}: ${CurrencyFormatter.format(acc.saldoActual)}',
          ),
          backgroundColor: AppTheme.emeraldPrimary,
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = trx.errorMessage ?? 'No se pudo guardar la transacción.';
      });
    }
  }

  String get _defaultDescription => switch (_type) {
        'ingreso' => 'Ingreso',
        'ajuste' => 'Ajuste de saldo',
        _ => 'Gasto',
      };

  Widget _typeTabs() {
    Widget tab(String value, String label) {
      final selected = _type == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _setType(value),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? context.nx.card : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? context.nx.text : context.nx.muted,
                  ),
                ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.nx.border),
      ),
      child: Row(
        children: [
          tab('ingreso', 'Ingreso'),
          tab('gasto', 'Gasto'),
          tab('transferencia', 'Transferir'),
          tab('ajuste', 'Ajuste'),
        ],
      ),
    );
  }

  Widget _amountCard() {
    final hasText = _montoController.text.trim().isNotEmpty;
    final valid = _amountValid;
    final accent = valid ? context.nx.positive : (hasText ? context.nx.negative : context.nx.border);
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
          Text('Monto del $_kindLabel', style: TextStyle(color: context.nx.muted)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('RD\$',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.nx.positive)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: context.nx.text),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: context.nx.border),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          Container(height: 3, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(valid ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18, color: valid ? context.nx.positive : (hasText ? context.nx.negative : context.nx.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  valid ? 'Monto válido' : 'El monto debe ser mayor a RD\$ 0.00',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valid ? context.nx.positive : (hasText ? context.nx.negative : context.nx.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final v in const [100.0, 500.0, 1000.0]) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _addQuick(v),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.nx.text,
                      side: BorderSide(color: context.nx.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('+${CurrencyFormatter.format(v).replaceAll('RD\$ ', '').replaceAll('.00', '')}'),
                  ),
                ),
                if (v != 1000.0) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.nx.text)),
          ?trailing,
        ],
      ),
    );
  }

  Widget _accountChoice(AccountModel a, String? selectedId, ValueChanged<String> onTap, {String? disabledId}) {
    final selected = selectedId == a.id;
    final disabled = disabledId == a.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : () => onTap(a.id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppTheme.emeraldPrimary.withValues(alpha: 0.10) : context.nx.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppTheme.emeraldPrimary : context.nx.border, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    a.tipo == 'efectivo'
                        ? Icons.payments_outlined
                        : (a.tipo == 'tarjeta' ? Icons.credit_card : Icons.account_balance_outlined),
                    color: context.nx.positive,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nombre, style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                      Text('Saldo: ${CurrencyFormatter.format(a.saldoActual)}',
                          style: TextStyle(fontSize: 12, color: context.nx.muted)),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: context.nx.positive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().accounts.where((a) => !a.archivada).toList();
    final categories = context.watch<TransactionProvider>().categories;
    final kindCategories =
        categories.where((c) => c.tipo == _type || c.tipo == 'ambos').toList();
    final isLoading = context.watch<TransactionProvider>().isLoading || _saving;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text('Nueva transacción'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _typeTabs(),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
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
                  ),
                  const SizedBox(height: 12),
                ],
                _amountCard(),

                if (_type == 'ajuste') ...[
                  _sectionLabel('Efecto del ajuste'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'entrada', label: Text('Aumenta el saldo'), icon: Icon(Icons.add)),
                      ButtonSegment(value: 'salida', label: Text('Disminuye el saldo'), icon: Icon(Icons.remove)),
                    ],
                    selected: {_sentido},
                    onSelectionChanged: (s) => setState(() => _sentido = s.first),
                  ),
                  const SizedBox(height: 6),
                  Text('Un ajuste corrige la diferencia entre el saldo registrado y el saldo real de la cuenta.',
                      style: TextStyle(fontSize: 12, color: context.nx.muted)),
                ],

                _sectionLabel(_isTransfer ? 'Cuenta de origen' : 'Cuenta'),
                if (accounts.isEmpty)
                  Text('Primero crea una cuenta en la pestaña Cuentas.', style: TextStyle(color: context.nx.muted))
                else
                  for (final a in accounts)
                    _accountChoice(a, _originId, (id) => setState(() => _originId = id),
                        disabledId: _isTransfer ? _destinationId : null),

                if (_isTransfer) ...[
                  _sectionLabel('Cuenta de destino'),
                  for (final a in accounts)
                    _accountChoice(a, _destinationId, (id) => setState(() => _destinationId = id), disabledId: _originId),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.indigoAI.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppTheme.indigoAI),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Las transferencias entre tus cuentas no cuentan como gasto ni ingreso.',
                              style: TextStyle(fontSize: 12, color: context.nx.text)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (!_isTransfer && _type != 'ajuste') ...[
                  _sectionLabel('Categoría'),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('category-$_type'),
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                    hint: const Text('Sin categoría'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Sin categoría')),
                      for (final c in kindCategories)
                        DropdownMenuItem<String?>(value: c.id, child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 6),
                  Text('Si no eliges una, quedará “Sin categoría” y podrás corregirla después.',
                      style: TextStyle(fontSize: 12, color: context.nx.muted)),
                ],

                _sectionLabel('Fecha de emisión'),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(), // RN-TRX-02: no se admiten fechas futuras
                      helpText: 'Fecha de la transacción',
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.calendar_today_outlined, color: context.nx.muted),
                      suffixIcon: Icon(Icons.check_circle_outline, color: context.nx.positive),
                    ),
                    child: Text(DateFormatter.format(_selectedDate),
                        style: TextStyle(fontSize: 16, color: context.nx.text)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Formato DD/MM/AAAA · No puede ser fecha futura',
                    style: TextStyle(fontSize: 12, color: context.nx.muted)),

                _sectionLabel('Descripción / nota'),
                TextField(
                  controller: _descripcionController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: _isTransfer ? 'Ej. Ahorro del mes' : 'Ej. Compra quincenal en el supermercado',
                    counterText: '',
                    prefixIcon: Icon(Icons.edit_note, color: context.nx.muted),
                  ),
                ),
                if (!_isTransfer) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notaController,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Nota adicional (opcional)',
                      counterText: '',
                      prefixIcon: Icon(Icons.notes, color: context.nx.muted),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _submit,
                  icon: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isTransfer ? 'Ejecutar transferencia' : 'Guardar transacción'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
