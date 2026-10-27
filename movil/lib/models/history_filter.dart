import '../core/utils/date_formatter.dart';

const Object _keep = Object();

/// Filtros del historial de movimientos. Solo incluye lo que la API soporta:
/// tipo, cuenta, categoría, rango de fechas y texto de búsqueda.
class HistoryFilter {
  final String? tipo; // ingreso | gasto | transferencia
  final String? cuentaId;
  final String? categoriaId;
  final String? busqueda;
  final DateTime? desde;
  final DateTime? hasta;

  /// Preajuste elegido en la hoja de filtros: mes | 30d | quincena | custom.
  final String? datePreset;

  const HistoryFilter({
    this.tipo,
    this.cuentaId,
    this.categoriaId,
    this.busqueda,
    this.desde,
    this.hasta,
    this.datePreset,
  });

  /// Cantidad de filtros avanzados activos (la búsqueda y el chip de tipo no cuentan).
  int get activeCount =>
      (cuentaId != null ? 1 : 0) + (categoriaId != null ? 1 : 0) + (desde != null || hasta != null ? 1 : 0);

  HistoryFilter copyWith({
    Object? tipo = _keep,
    Object? cuentaId = _keep,
    Object? categoriaId = _keep,
    Object? busqueda = _keep,
    Object? desde = _keep,
    Object? hasta = _keep,
    Object? datePreset = _keep,
  }) {
    return HistoryFilter(
      tipo: identical(tipo, _keep) ? this.tipo : tipo as String?,
      cuentaId: identical(cuentaId, _keep) ? this.cuentaId : cuentaId as String?,
      categoriaId: identical(categoriaId, _keep) ? this.categoriaId : categoriaId as String?,
      busqueda: identical(busqueda, _keep) ? this.busqueda : busqueda as String?,
      desde: identical(desde, _keep) ? this.desde : desde as DateTime?,
      hasta: identical(hasta, _keep) ? this.hasta : hasta as DateTime?,
      datePreset: identical(datePreset, _keep) ? this.datePreset : datePreset as String?,
    );
  }

  /// Quita solo los filtros avanzados (mantiene tipo y búsqueda).
  HistoryFilter clearAdvanced() => HistoryFilter(tipo: tipo, busqueda: busqueda);

  Map<String, dynamic> toQuery({required int limit, int offset = 0}) {
    final q = <String, dynamic>{'limit': limit, 'offset': offset};
    if (tipo != null) q['tipo'] = tipo;
    if (cuentaId != null) q['cuenta_id'] = cuentaId;
    if (categoriaId != null) q['categoria_id'] = categoriaId;
    if (busqueda != null && busqueda!.isNotEmpty) q['busqueda'] = busqueda;
    if (desde != null) q['fecha_inicio'] = DateFormatter.toApiDate(desde!);
    if (hasta != null) q['fecha_fin'] = DateFormatter.toApiDate(hasta!);
    return q;
  }
}
