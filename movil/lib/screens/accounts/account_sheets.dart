import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/account_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

/// Hoja para crear o editar una cuenta. Con [existing] edita nombre y datos de tarjeta.
Future<void> showAccountFormSheet(BuildContext context, {AccountModel? existing, String defaultType = 'bancaria'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.nx.surface,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AccountForm(existing: existing, defaultType: defaultType),
    ),
  );
}

class _AccountForm extends StatefulWidget {
  final AccountModel? existing;
  final String defaultType;
  const _AccountForm({this.existing, required this.defaultType});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _limit;
  late final TextEditingController _cutDay;
  late final TextEditingController _payDay;
  late String _type;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _type = a?.tipo ?? widget.defaultType;
    _name = TextEditingController(text: a?.nombre ?? '');
    _balance = TextEditingController(text: '0');
    _limit = TextEditingController(text: a?.limiteCredito?.toStringAsFixed(2) ?? '');
    _cutDay = TextEditingController(text: a?.diaCorte?.toString() ?? '');
    _payDay = TextEditingController(text: a?.diaPago?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _limit.dispose();
    _cutDay.dispose();
    _payDay.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  int? _day(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v < 1 || v > 31) return null;
    return v;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }
    if (_type == 'tarjeta') {
      if (_limit.text.trim().isNotEmpty && (_num(_limit) ?? 0) <= 0) {
        setState(() => _error = 'El límite de crédito debe ser mayor que cero.');
        return;
      }
      if (_cutDay.text.trim().isNotEmpty && _day(_cutDay) == null) {
        setState(() => _error = 'El día de corte debe estar entre 1 y 31.');
        return;
      }
      if (_payDay.text.trim().isNotEmpty && _day(_payDay) == null) {
        setState(() => _error = 'El día de pago debe estar entre 1 y 31.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = context.read<AccountProvider>();
    final bool ok;
    if (_editing) {
      ok = await provider.updateAccount(
        widget.existing!.id,
        nombre: name,
        limiteCredito: _type == 'tarjeta' ? _num(_limit) : null,
        diaCorte: _type == 'tarjeta' ? _day(_cutDay) : null,
        diaPago: _type == 'tarjeta' ? _day(_payDay) : null,
      );
    } else {
      ok = await provider.createAccount(
        nombre: name,
        tipo: _type,
        saldoInicial: _num(_balance) ?? 0,
        limiteCredito: _type == 'tarjeta' ? _num(_limit) : null,
        diaCorte: _type == 'tarjeta' ? _day(_cutDay) : null,
        diaPago: _type == 'tarjeta' ? _day(_payDay) : null,
      );
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Cuenta actualizada.' : 'Cuenta creada.')),
      );
    } else {
      setState(() {
        _saving = false;
        _error = provider.errorMessage ?? 'No se pudo guardar la cuenta.';
      });
    }
  }

  Widget _typeChip(String value, String label, IconData icon) {
    final selected = _type == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _editing ? null : () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.nx.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? context.nx.positive : context.nx.muted),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? context.nx.positive : context.nx.muted)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_editing ? 'Editar cuenta' : 'Nueva cuenta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nx.text)),
            const SizedBox(height: 14),
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
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.nx.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.nx.border),
              ),
              child: Row(
                children: [
                  _typeChip('bancaria', 'Bancaria', Icons.account_balance_outlined),
                  _typeChip('efectivo', 'Efectivo', Icons.payments_outlined),
                  _typeChip('tarjeta', 'Tarjeta', Icons.credit_card_outlined),
                ],
              ),
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('El tipo de cuenta no se puede cambiar.',
                    style: TextStyle(fontSize: 12, color: context.nx.muted)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de la cuenta',
                hintText: 'Ej. Banco Popular – Nómina',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: _type == 'tarjeta' ? 'Saldo inicial (negativo = deuda)' : 'Saldo inicial',
                  prefixText: 'RD\$ ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
            ],
            if (_type == 'tarjeta') ...[
              const SizedBox(height: 14),
              TextField(
                controller: _limit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Límite de crédito (opcional)',
                  prefixText: 'RD\$ ',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cutDay,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Día de corte', hintText: '1–31'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _payDay,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Día de pago', hintText: '1–31'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_editing ? 'Guardar cambios' : 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abono a una tarjeta de crédito. Según RN-CTA-02 se registra como transferencia
/// desde otra cuenta propia, por lo que no cuenta como gasto.
Future<void> showCardPaymentSheet(BuildContext context, AccountModel card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.nx.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CardPayment(card: card),
    ),
  );
}

class _CardPayment extends StatefulWidget {
  final AccountModel card;
  const _CardPayment({required this.card});

  @override
  State<_CardPayment> createState() => _CardPaymentState();
}

class _CardPaymentState extends State<_CardPayment> {
  final _amount = TextEditingController();
  String? _originId;
  bool _saving = false;
  String? _error;

  double get _debt => widget.card.saldoActual < 0 ? -widget.card.saldoActual : 0;
  double? get _value => double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    _amount.text = _debt > 0 ? _debt.toStringAsFixed(2) : '';
    _amount.addListener(() => setState(() {}));
    final origins = _origins(context.read<AccountProvider>());
    if (origins.isNotEmpty) _originId = origins.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  List<AccountModel> _origins(AccountProvider p) =>
      p.accounts.where((a) => !a.archivada && a.tipo != 'tarjeta').toList();

  String? get _validation {
    final v = _value;
    if (v == null || v <= 0) return 'El monto debe ser mayor que cero.';
    if (v > _debt + 0.004) return 'El abono no puede superar la deuda: ${CurrencyFormatter.format(_debt)}.';
    return null;
  }

  Future<void> _confirm() async {
    final problem = _validation;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_originId == null) {
      setState(() => _error = 'Selecciona la cuenta de origen de los fondos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final tx = context.read<TransactionProvider>();
    final ok = await tx.createTransfer(
      cuentaOrigenId: _originId!,
      cuentaDestinoId: widget.card.id,
      monto: _value!,
      fecha: DateFormatter.toApiDate(DateTime.now()),
      descripcion: 'Pago de tarjeta ${widget.card.nombre}',
    );
    if (!mounted) return;
    if (ok) {
      // Se cierra enseguida; los saldos se refrescan en segundo plano.
      final accounts = context.read<AccountProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final amount = CurrencyFormatter.format(_value);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Abono de $amount registrado en ${widget.card.nombre}.')),
      );
      accounts.fetchAccounts();
    } else {
      setState(() {
        _saving = false;
        _error = tx.errorMessage ?? 'No se pudo registrar el abono.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final origins = _origins(context.watch<AccountProvider>());
    final value = _value ?? 0;
    final remaining = (_debt - value).clamp(0, double.infinity);
    final problem = _amount.text.isEmpty ? null : _validation;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Abonar a tarjeta',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nx.text)),
                ),
                IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.nx.negative.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.nx.negative.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card, color: context.nx.negative, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(widget.card.nombre,
                                style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Deuda utilizada', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                      Text(CurrencyFormatter.format(_debt),
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.nx.negative)),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
                ],
                const SizedBox(height: 18),
                Text('Monto del abono', style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(prefixText: 'RD\$ ', hintText: '0.00'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.done_all, size: 16),
                      label: Text('Pago total (${CurrencyFormatter.format(_debt)})'),
                      onPressed: _debt > 0 ? () => _amount.text = _debt.toStringAsFixed(2) : null,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Otro monto'),
                      onPressed: () => _amount.clear(),
                    ),
                  ],
                ),
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: context.nx.negative),
                        const SizedBox(width: 6),
                        Expanded(child: Text(problem, style: TextStyle(fontSize: 12, color: context.nx.negative))),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text('Cuenta de origen de los fondos',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                const SizedBox(height: 8),
                if (origins.isEmpty)
                  Text('Necesitas una cuenta de efectivo o bancaria para pagar.', style: TextStyle(color: context.nx.muted))
                else
                  for (final a in origins)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _originId = a.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _originId == a.id ? AppTheme.emeraldPrimary.withValues(alpha: 0.10) : context.nx.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _originId == a.id ? AppTheme.emeraldPrimary : context.nx.border,
                              width: _originId == a.id ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _originId == a.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: _originId == a.id ? context.nx.positive : context.nx.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(a.nombre, style: TextStyle(fontWeight: FontWeight.w600, color: context.nx.text))),
                              Text(CurrencyFormatter.format(a.saldoActual),
                                  style: TextStyle(fontSize: 13, color: context.nx.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.indigoAI.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.nx.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Deuda tras el abono', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                          Text(CurrencyFormatter.format(remaining),
                              style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: context.nx.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'El abono a una tarjeta se registra como transferencia entre tus cuentas: reduce tu deuda y tu efectivo, pero no cuenta como gasto.',
                              style: TextStyle(fontSize: 12, color: context.nx.muted, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
              onPressed: (_saving || _debt <= 0) ? null : _confirm,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_debt <= 0 ? 'No hay deuda por pagar' : 'Confirmar abono'),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
