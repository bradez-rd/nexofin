import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final String initialType; // 'ingreso', 'gasto', 'transferencia'

  const AddTransactionScreen({super.key, this.initialType = 'gasto'});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type; // 'ingreso', 'gasto', 'transferencia'

  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _notaController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedAccountId;
  String? _selectedDestinationAccountId;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accProvider = context.read<AccountProvider>();
      final trxProvider = context.read<TransactionProvider>();

      if (accProvider.accounts.isEmpty) {
        accProvider.fetchAccounts();
      } else {
        setState(() {
          _selectedAccountId = accProvider.accounts.first.id;
          if (accProvider.accounts.length > 1) {
            _selectedDestinationAccountId = accProvider.accounts[1].id;
          }
        });
      }

      trxProvider.fetchCategories();
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser estrictamente mayor que 0')),
      );
      return;
    }

    final trxProvider = context.read<TransactionProvider>();
    final accProvider = context.read<AccountProvider>();
    final formattedDate = DateFormatter.toApiDate(_selectedDate);

    bool success = false;

    if (_type == 'transferencia') {
      if (_selectedAccountId == null || _selectedDestinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona ambas cuentas para transferir')),
        );
        return;
      }
      if (_selectedAccountId == _selectedDestinationAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cuenta de origen y destino deben ser distintas')),
        );
        return;
      }

      success = await trxProvider.createTransfer(
        cuentaOrigenId: _selectedAccountId!,
        cuentaDestinoId: _selectedDestinationAccountId!,
        monto: monto,
        fecha: formattedDate,
        descripcion: _descripcionController.text.trim().isEmpty
            ? 'Transferencia de fondos'
            : _descripcionController.text.trim(),
      );
    } else {
      if (_selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una cuenta')),
        );
        return;
      }

      success = await trxProvider.createTransaction(
        cuentaId: _selectedAccountId!,
        categoriaId: _selectedCategoryId,
        tipo: _type,
        monto: monto,
        fecha: formattedDate,
        descripcion: _descripcionController.text.trim().isEmpty
            ? (_type == 'ingreso' ? 'Ingreso' : 'Gasto')
            : _descripcionController.text.trim(),
        nota: _notaController.text.trim().isEmpty ? null : _notaController.text.trim(),
      );
    }

    if (!mounted) return;

    if (success) {
      await accProvider.fetchAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Movimiento registrado con éxito!'),
            backgroundColor: AppTheme.emeraldLight,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trxProvider.errorMessage ?? 'Error al registrar movimiento'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final accounts = accountProvider.accounts;
    final categories = transactionProvider.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Movimiento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Selector Tabs
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTypeButton('gasto', 'Gasto', AppTheme.errorRed),
                    _buildTypeButton('ingreso', 'Ingreso', AppTheme.emeraldLight),
                    _buildTypeButton('transferencia', 'Transferir', AppTheme.indigoAI),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Monto Field
              TextFormField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Monto (RD\$)',
                  prefixText: 'RD\$ ',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa un monto';
                  if (double.tryParse(val) == null) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Account Selector
              if (_type == 'transferencia') ...[
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de Origen (Salida)',
                    prefixIcon: Icon(Icons.arrow_upward, color: AppTheme.errorRed),
                  ),
                  items: accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text('${acc.nombre} (${acc.tipo})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  validator: (val) => val == null ? 'Selecciona la cuenta origen' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDestinationAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de Destino (Entrada)',
                    prefixIcon: Icon(Icons.arrow_downward, color: AppTheme.emeraldLight),
                  ),
                  items: accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text('${acc.nombre} (${acc.tipo})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDestinationAccountId = val),
                  validator: (val) => val == null ? 'Selecciona la cuenta destino' : null,
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta',
                    prefixIcon: Icon(Icons.account_balance, color: AppTheme.emeraldLight),
                  ),
                  items: accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text('${acc.nombre} (${acc.tipo})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  validator: (val) => val == null ? 'Selecciona una cuenta' : null,
                ),
                const SizedBox(height: 16),

                // Category Selector
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría (Opcional)',
                    prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF94A3B8)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                    ...categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.nombre),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
              ],
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del Movimiento',
                    prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF94A3B8)),
                  ),
                  child: Text(
                    DateFormatter.format(_selectedDate),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Concepto',
                  hintText: 'Ej. Supermercado, Pago de Nómina',
                  prefixIcon: Icon(Icons.edit_note, color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              if (_type != 'transferencia') ...[
                TextFormField(
                  controller: _notaController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nota Adicional (Opcional)',
                    hintText: 'Detalles para auditoría o comprobante',
                    prefixIcon: Icon(Icons.notes, color: Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 8),

              // Submit Button
              ElevatedButton(
                onPressed: transactionProvider.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'ingreso'
                      ? AppTheme.emeraldPrimary
                      : (_type == 'transferencia' ? AppTheme.indigoAI : const Color(0xFFB91C1C)),
                ),
                child: transactionProvider.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _type == 'transferencia'
                            ? 'Ejecutar Transferencia Atómica'
                            : 'Guardar ${_type.toUpperCase()}',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String typeKey, String label, Color activeColor) {
    final isSelected = _type == typeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = typeKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
