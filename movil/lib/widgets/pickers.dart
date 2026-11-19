import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import 'nx_kit.dart';

/// Selector de cuenta (excluye archivadas; opcionalmente tarjetas).
class AccountPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool includeCards;
  const AccountPicker({super.key, required this.value, required this.onChanged, this.label = 'Cuenta', this.includeCards = true});

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().accounts.where((a) => !a.archivada && (includeCards || a.tipo != 'tarjeta')).toList();
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final AccountModel a in accounts)
          DropdownMenuItem(value: a.id, child: Text('${a.nombre} · ${rd(a.saldoActual)}', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Selector de categoría por tipo ('gasto' o 'ingreso').
class CategoryPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String tipo;
  final String label;
  final bool allowNone;
  const CategoryPicker({super.key, required this.value, required this.onChanged, this.tipo = 'gasto', this.label = 'Categoría', this.allowNone = false});

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<TransactionProvider>().categories.where((c) => c.tipo == tipo).toList();
    return DropdownButtonFormField<String?>(
      initialValue: cats.any((c) => c.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowNone) const DropdownMenuItem<String?>(value: null, child: Text('Sin categoría')),
        for (final CategoryModel c in cats) DropdownMenuItem<String?>(value: c.id, child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}
