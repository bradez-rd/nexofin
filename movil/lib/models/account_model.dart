class AccountModel {
  final String id;
  final String usuarioId;
  final String nombre;
  final String tipo; // 'efectivo', 'bancaria', 'tarjeta'
  final String moneda;
  final double saldoInicial;
  final double saldoActual;
  final double? limiteCredito;
  final int? diaCorte;
  final int? diaPago;
  final bool archivada;

  AccountModel({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldoInicial,
    required this.saldoActual,
    this.limiteCredito,
    this.diaCorte,
    this.diaPago,
    required this.archivada,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'bancaria',
      moneda: json['moneda']?.toString() ?? 'DOP',
      saldoInicial: double.tryParse(json['saldo_inicial']?.toString() ?? '0') ?? 0.0,
      saldoActual: double.tryParse(json['saldo_actual']?.toString() ?? '0') ??
          double.tryParse(json['saldo_inicial']?.toString() ?? '0') ??
          0.0,
      limiteCredito: json['limite_credito'] != null
          ? double.tryParse(json['limite_credito'].toString())
          : null,
      diaCorte: json['dia_corte'] != null ? int.tryParse(json['dia_corte'].toString()) : null,
      diaPago: json['dia_pago'] != null ? int.tryParse(json['dia_pago'].toString()) : null,
      archivada: json['archivada'] == true || json['archivada'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre': nombre,
      'tipo': tipo,
      'moneda': moneda,
      'saldo_inicial': saldoInicial,
      'saldo_actual': saldoActual,
      'limite_credito': limiteCredito,
      'dia_corte': diaCorte,
      'dia_pago': diaPago,
      'archivada': archivada,
    };
  }
}

class BalanceSummaryModel {
  final String moneda;
  final double patrimonioNeto;
  final int totalCuentas;

  BalanceSummaryModel({
    required this.moneda,
    required this.patrimonioNeto,
    required this.totalCuentas,
  });

  factory BalanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return BalanceSummaryModel(
      moneda: json['moneda']?.toString() ?? 'DOP',
      patrimonioNeto: double.tryParse(json['patrimonio_neto']?.toString() ?? '0') ?? 0.0,
      totalCuentas: int.tryParse(json['total_cuentas']?.toString() ?? '0') ?? 0,
    );
  }
}
