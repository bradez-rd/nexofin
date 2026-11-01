import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';

/// Reportes: balance, posición financiera, distribución del gasto, tendencia y exportación (RF-DAS-01 a 05).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<Json>>();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _mes => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _desde => '$_mes-01';
  String get _hasta => apiDate(DateTime(_month.year, _month.month + 1, 0));

  Future<Json> _load() async {
    final results = await Future.wait([_api.summary(_desde, _hasta), _api.position(), _api.spending(_mes), _api.trend()]);
    return {'summary': results[0], 'position': results[1], 'spending': results[2], 'trend': {'meses': results[3]}};
  }

  void _shift(int d) {
    setState(() => _month = DateTime(_month.year, _month.month + d));
    _key.currentState?.reload();
  }

  Future<void> _export(String formato) async {
    try {
      final bytes = await ApiService().download('/dashboard/export', queryParams: {'formato': formato, 'desde': _desde, 'hasta': _hasta});
      final path = await FilePicker.saveFile(dialogTitle: 'Guardar reporte', fileName: 'nexofin_reporte_$_mes.$formato', bytes: Uint8List.fromList(bytes));
      if (mounted && path != null) toast(context, 'Reporte guardado');
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Reportes',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Exportar reporte',
          icon: const Icon(Icons.ios_share),
          onSelected: _export,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
            PopupMenuItem(value: 'xlsx', child: Text('Exportar Excel')),
            PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
          ],
        ),
      ],
      body: AsyncView<Json>(
        key: _key,
        load: _load,
        builder: (context, data, reload) {
          final s = Map<String, dynamic>.from(data['summary'] as Map);
          final p = Map<String, dynamic>.from(data['position'] as Map);
          final sp = Map<String, dynamic>.from(data['spending'] as Map);
          final tr = ((data['trend'] as Map)['meses'] as List).cast<Map>();
          final cats = (sp['categorias'] as List).cast<Map>();
          final maxTrend = tr.fold<num>(1, (m, e) => [m, n(e['ingresos']), n(e['gastos'])].reduce((a, b) => a > b ? a : b));
          final desglose = Map<String, dynamic>.from(p['desglose'] as Map);
          final proy = Map<String, dynamic>.from(desglose['proyeccion'] as Map);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(tooltip: 'Mes anterior', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                Text(_mes, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.nx.text)),
                IconButton(tooltip: 'Mes siguiente', icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
              ]),
              NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Balance del mes', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                  const SizedBox(height: 8),
                  _line(context, 'Ingresos', n(s['ingresos']), context.nx.positive),
                  _line(context, 'Gastos', n(s['gastos']), context.nx.negative),
                  const Divider(),
                  _line(context, 'Saldo neto', n(s['saldo_neto']), n(s['saldo_neto']) >= 0 ? context.nx.positive : context.nx.negative, bold: true),
                  Text('Las transferencias entre cuentas no cuentan como ingreso ni gasto.', style: TextStyle(fontSize: 11, color: context.nx.muted)),
                ]),
              ),
              const SizedBox(height: 12),
              NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Posición financiera', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                  const SizedBox(height: 8),
                  _line(context, 'Saldo disponible', n(p['saldo_disponible']), context.nx.text),
                  _line(context, 'Deuda total', n(p['deuda_total']), context.nx.negative),
                  _line(context, 'Saldo libre al cierre del mes', n(p['saldo_libre_proyectado']), n(p['saldo_libre_proyectado']) >= 0 ? context.nx.positive : context.nx.negative, bold: true),
                  NxExpander(
                    title: '¿Cómo se calcula?',
                    children: [
                      _line(context, 'Ingresos esperados', n(proy['ingresos_esperados']), context.nx.text),
                      _line(context, 'Gastos fijos', n(proy['gastos_fijos']), context.nx.text),
                      _line(context, 'Cuotas de deudas', n(proy['cuotas_de_deuda']), context.nx.text),
                      _line(context, 'Gasto variable estimado', n(proy['gasto_variable_estimado']), context.nx.text),
                      _line(context, 'Compromiso con metas', n(proy['compromiso_metas']), context.nx.text),
                      Text(desglose['formula'] as String, style: TextStyle(fontSize: 11, color: context.nx.muted)),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Gasto por categoría', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                  const SizedBox(height: 8),
                  if (cats.isEmpty) Text('Sin gastos en este mes.', style: TextStyle(color: context.nx.muted)),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text(c['nombre'] as String)), Text('${rd(n(c['monto']))} · ${c['porcentaje']}%', style: TextStyle(color: context.nx.muted, fontSize: 12))]),
                        const SizedBox(height: 4),
                        NxProgress(value: n(c['porcentaje']).toDouble() / 100, color: context.nx.accent),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tendencia de 6 meses', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final m in tr)
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                              _bar(110 * n(m['ingresos']) / maxTrend, context.nx.positive),
                              const SizedBox(width: 3),
                              _bar(110 * n(m['gastos']) / maxTrend, context.nx.negative),
                            ]),
                            const SizedBox(height: 4),
                            Text((m['mes'] as String).substring(5), style: TextStyle(fontSize: 11, color: context.nx.muted)),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.square, size: 10, color: context.nx.positive),
                    const SizedBox(width: 4),
                    Text('Ingresos', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                    const SizedBox(width: 12),
                    Icon(Icons.square, size: 10, color: context.nx.negative),
                    const SizedBox(width: 4),
                    Text('Gastos', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                  ]),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double h, Color c) => Container(width: 12, height: h < 2 ? 2 : h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));

  Widget _line(BuildContext context, String label, num v, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: context.nx.muted))),
          Text(rd(v), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
        ]),
      );
}
