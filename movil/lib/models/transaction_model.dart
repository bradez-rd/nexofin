class TransactionModel {
  final String id;
  final String cuentaId;
  final String? categoriaId;
  final String tipo; // 'ingreso', 'gasto', 'transferencia', 'ajuste', 'aporte_meta'
  final String sentido; // 'entrada', 'salida'
  final double monto;
  final String fecha; // YYYY-MM-DD
  final String? descripcion;
  final String? nota;
  final String? transferenciaVinculadaId;
  final String? cuentaNombre;
  final String? categoriaNombre;
  final String? categoriaIcono;

  TransactionModel({
    required this.id,
    required this.cuentaId,
    this.categoriaId,
    required this.tipo,
    required this.sentido,
    required this.monto,
    required this.fecha,
    this.descripcion,
    this.nota,
    this.transferenciaVinculadaId,
    this.cuentaNombre,
    this.categoriaNombre,
    this.categoriaIcono,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      cuentaId: json['cuenta_id']?.toString() ?? '',
      categoriaId: json['categoria_id']?.toString(),
      tipo: json['tipo']?.toString() ?? 'gasto',
      sentido: json['sentido']?.toString() ?? (json['tipo'] == 'ingreso' ? 'entrada' : 'salida'),
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      fecha: json['fecha']?.toString().split('T').first ?? '',
      descripcion: json['descripcion']?.toString(),
      nota: json['nota']?.toString(),
      transferenciaVinculadaId: json['transferencia_vinculada_id']?.toString(),
      cuentaNombre: json['cuenta_nombre']?.toString(),
      categoriaNombre: json['categoria_nombre']?.toString(),
      categoriaIcono: json['categoria_icono']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cuenta_id': cuentaId,
      'categoria_id': categoriaId,
      'tipo': tipo,
      'sentido': sentido,
      'monto': monto,
      'fecha': fecha,
      'descripcion': descripcion,
      'nota': nota,
      'transferencia_vinculada_id': transferenciaVinculadaId,
    };
  }

  bool get isIncome => sentido == 'entrada' || tipo == 'ingreso';
  bool get isTransfer => tipo == 'transferencia' || transferenciaVinculadaId != null;
}

class MonthlySummaryModel {
  final double ingresos;
  final double gastos;
  final double balanceNeto;
  final int totalTransacciones;

  MonthlySummaryModel({
    required this.ingresos,
    required this.gastos,
    required this.balanceNeto,
    required this.totalTransacciones,
  });

  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryModel(
      ingresos: double.tryParse(json['ingresos']?.toString() ?? '0') ?? 0.0,
      gastos: double.tryParse(json['gastos']?.toString() ?? '0') ?? 0.0,
      balanceNeto: double.tryParse(json['balance_neto']?.toString() ?? '0') ?? 0.0,
      totalTransacciones: int.tryParse(json['total_transacciones']?.toString() ?? '0') ?? 0,
    );
  }
}
