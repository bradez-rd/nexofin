import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';

/// Apariencia de una transacción según su tipo. El tipo se comunica con icono,
/// etiqueta y signo, no solo con color (accesibilidad).
class TxStyle {
  final Color color;
  final IconData icon;
  final String label; // Gasto | Ingreso | Transferencia
  final String amountText;

  const TxStyle({required this.color, required this.icon, required this.label, required this.amountText});

  factory TxStyle.of(BuildContext context, TransactionModel t) {
    if (t.isTransfer) {
      return TxStyle(
        color: AppTheme.indigoAI,
        icon: Icons.swap_horiz,
        label: 'Transferencia',
        amountText: CurrencyFormatter.format(t.monto),
      );
    }
    if (t.isIncome) {
      return TxStyle(
        color: context.nx.positive,
        icon: Icons.south_west,
        label: 'Ingreso',
        amountText: CurrencyFormatter.formatSigned(t.monto),
      );
    }
    return TxStyle(
      color: context.nx.negative,
      icon: Icons.north_east,
      label: 'Gasto',
      amountText: CurrencyFormatter.formatSigned(-t.monto),
    );
  }
}
