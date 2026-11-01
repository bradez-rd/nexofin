import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';
import '../assistant/assistant_screen.dart';

/// Simulador financiero (RF-SIM-01 a 08): gasto hipotético, ahorro para una meta y compra a cuotas.
/// Todas las cifras las calcula el motor del servidor con los datos del usuario.
class SimulatorTab extends StatefulWidget {
  const SimulatorTab({super.key});

  @override
  State<SimulatorTab> createState() => _SimulatorTabState();
}

class _SimulatorTabState extends State<SimulatorTab> {
  final _api = ModulesApi();
  String _kind = 'expense';
  final _monto = TextEditingController();
  final _tasa = TextEditingController(text: '0');
  final _cuotas = TextEditingController(text: '12');
  String? _categoria;
  DateTime? _fechaLimite;
  int _horizonte = 0; // 0 = fin de mes
  bool _loading = false;
  String? _error;
  Json? _result;

  Future<void> _run() async {
    final m = parseMoney(_monto.text);
    if (m == null || m <= 0) return setState(() => _error = 'Indica un monto mayor que cero');
    late Json params;
    switch (_kind) {
      case 'expense':
        params = {'monto': m, if (_categoria != null) 'categoria_id': _categoria, if (_horizonte > 0) 'horizonte_meses': _horizonte};
      case 'saving':
        if (_fechaLimite == null) return setState(() => _error = 'Elige la fecha límite de la meta');
        params = {'monto_objetivo': m, 'fecha_limite': apiDate(_fechaLimite!)};
      default:
        final c = int.tryParse(_cuotas.text.trim());
        if (c == null || c < 1) return setState(() => _error = 'Indica el número de cuotas');
        params = {'monto': m, 'tasa_anual': double.tryParse(_tasa.text.replaceAll(',', '.')) ?? 0, 'num_cuotas': c};
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sim = await _api.simulate(_kind, params);
      setState(() => _result = sim);
    } catch (e) {
      setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_kind) { 'expense' => 'Monto del gasto (RD\$)', 'saving' => 'Monto que quieres juntar (RD\$)', _ => 'Monto de la compra (RD\$)' };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('Gasto'), icon: Icon(Icons.shopping_bag_outlined)),
            ButtonSegment(value: 'saving', label: Text('Ahorro'), icon: Icon(Icons.savings_outlined)),
            ButtonSegment(value: 'installments', label: Text('Cuotas'), icon: Icon(Icons.calendar_month_outlined)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            _result = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        NxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyField(controller: _monto, label: label),
              const SizedBox(height: 12),
              if (_kind == 'expense') ...[
                CategoryPicker(value: _categoria, allowNone: true, label: 'Categoría (opcional)', onChanged: (v) => setState(() => _categoria = v)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _horizonte,
                  decoration: const InputDecoration(labelText: 'Horizonte'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Hasta fin de mes')),
                    for (final m in [1, 2, 3, 6, 12]) DropdownMenuItem(value: m, child: Text(m == 1 ? '1 mes' : '$m meses')),
                  ],
                  onChanged: (v) => setState(() => _horizonte = v ?? 0),
                ),
              ],
              if (_kind == 'saving') DateField(label: 'Fecha límite', value: _fechaLimite, firstDate: DateTime.now().add(const Duration(days: 1)), onChanged: (d) => setState(() => _fechaLimite = d)),
              if (_kind == 'installments')
                Row(children: [
                  Expanded(child: TextField(controller: _tasa, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tasa anual %'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _cuotas, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cuotas'))),
                ]),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: context.nx.negative))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _run,
                  icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate_outlined),
                  label: const Text('Simular'),
                ),
              ),
            ],
          ),
        ),
        if (_result != null) ...[const SizedBox(height: 16), _ResultCard(sim: _result!, api: _api)],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Preguntar al asistente'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulationHistoryScreen())),
              icon: const Icon(Icons.history),
              label: const Text('Historial'),
            ),
          ),
        ]),
      ],
    );
  }
}

class _ResultCard extends StatefulWidget {
  final Json sim;
  final ModulesApi api;
  const _ResultCard({required this.sim, required this.api});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final r = Map<String, dynamic>.from(widget.sim['resultado'] as Map);
    final res = Map<String, dynamic>.from(r['resultado'] as Map);
    final concluyente = r['concluyente'] == true;
    final alternativas = (r['alternativas'] as List).cast<Map>();
    final supuestos = Map<String, dynamic>.from(r['supuestos'] as Map);

    Widget row(String label, num? v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: context.nx.muted))),
            Text(v == null ? '—' : rd(v), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? context.nx.text)),
          ]),
        );

    final lines = <Widget>[
      if (res.containsKey('saldo_libre_despues')) ...[
        row('Saldo libre antes', n(res['saldo_libre_antes'])),
        row('Saldo libre después', n(res['saldo_libre_despues']), bold: true, color: n(res['saldo_libre_despues']) < 0 ? context.nx.negative : context.nx.positive),
      ],
      if (res['efecto_presupuesto'] != null) ...[
        const Divider(),
        Text('Presupuesto de ${(res['efecto_presupuesto'] as Map)['categoria']}: ${(res['efecto_presupuesto'] as Map)['porcentaje_antes']}% → ${(res['efecto_presupuesto'] as Map)['porcentaje_despues']}%', style: TextStyle(color: (res['efecto_presupuesto'] as Map)['supera_presupuesto'] == true ? context.nx.negative : context.nx.text)),
      ],
      if (res['compromete_metas'] == true) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Este gasto comprometería tus aportes a metas.', style: TextStyle(color: context.nx.warning, fontWeight: FontWeight.w700))),
      if (res.containsKey('ahorro_mensual_requerido')) ...[
        row('Ahorro mensual requerido', n(res['ahorro_mensual_requerido']), bold: true),
        row('Capacidad mensual de ahorro', res['capacidad_mensual_ahorro'] == null ? null : n(res['capacidad_mensual_ahorro'])),
      ],
      if (res.containsKey('cuota_mensual')) ...[
        row('Cuota mensual', n(res['cuota_mensual']), bold: true),
        row('Costo total', n(res['costo_total'])),
        row('Intereses pagados', n(res['intereses_pagados'])),
        if (res.containsKey('flujo_mensual_despues')) row('Flujo mensual después', n(res['flujo_mensual_despues']), color: n(res['flujo_mensual_despues']) < 0 ? context.nx.negative : null),
      ],
    ];

    return NxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Resultado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.nx.text))),
            NxChip(concluyente ? 'Estimación' : 'Datos insuficientes', color: concluyente ? context.nx.warning : context.nx.negative),
          ]),
          const SizedBox(height: 8),
          Text(r['resumen'] as String, style: TextStyle(color: context.nx.text, height: 1.35)),
          if (!concluyente) ...[
            const SizedBox(height: 8),
            for (final f in (r['faltantes'] as List)) Text('• $f', style: TextStyle(color: context.nx.muted)),
          ],
          const SizedBox(height: 10),
          ...lines,
          if (alternativas.isNotEmpty) ...[
            const Divider(),
            Text('Alternativas', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
            for (final a in alternativas) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• ${a['descripcion']}', style: TextStyle(color: context.nx.text))),
          ],
          NxExpander(
            title: 'Supuestos usados',
            children: [
              for (final e in supuestos.entries.where((e) => e.value is! Map && e.value is! List))
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Expanded(child: Text(e.key.replaceAll('_', ' '), style: TextStyle(color: context.nx.muted, fontSize: 12))), Text(e.value is num ? rd(e.value as num) : '${e.value}', style: TextStyle(color: context.nx.text, fontSize: 12))])),
            ],
          ),
          Text(r['aviso'] as String, style: TextStyle(fontSize: 11, color: context.nx.muted)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saved
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.api.saveSimulation(widget.sim['id'] as String);
                    if (!mounted) return;
                    setState(() => _saved = true);
                    messenger.showSnackBar(const SnackBar(content: Text('Simulación guardada en tu historial'), behavior: SnackBarBehavior.floating));
                  },
            icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
            label: Text(_saved ? 'Guardada' : 'Guardar simulación'),
          ),
        ],
      ),
    );
  }
}

/// Historial de simulaciones guardadas: reabrir, recalcular y comparar hasta tres.
class SimulationHistoryScreen extends StatefulWidget {
  const SimulationHistoryScreen({super.key});

  @override
  State<SimulationHistoryScreen> createState() => _SimulationHistoryScreenState();
}

class _SimulationHistoryScreenState extends State<SimulationHistoryScreen> {
  final _api = ModulesApi();
  final _selected = <String>{};

  Future<void> _compare() async {
    final rows = await _api.compare(_selected.toList());
    if (!mounted) return;
    showNxSheet<void>(
      context,
      title: 'Comparación de escenarios',
      builder: (ctx) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in rows)
            Container(
              width: 200,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ctx.nx.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ctx.nx.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NxChip(switch (e['tipo']) { 'gasto' => 'Gasto', 'ahorro_meta' => 'Ahorro', _ => 'Cuotas' }),
                const SizedBox(height: 8),
                Text(e['resumen'] as String, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: ctx.nx.text)),
                const SizedBox(height: 8),
                if (e['saldo_libre_despues'] != null) Text('Saldo libre: ${rd(n(e['saldo_libre_despues']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (e['cuota_mensual'] != null) Text('Cuota: ${rd(n(e['cuota_mensual']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                if ((e['efecto_metas'] as Map)['ahorro_mensual_requerido'] != null) Text('Ahorro mensual: ${rd(n((e['efecto_metas'] as Map)['ahorro_mensual_requerido']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (e['efecto_presupuesto'] != null) Text('Presupuesto → ${(e['efecto_presupuesto'] as Map)['porcentaje_despues']}%'),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Historial de simulaciones',
      actions: [if (_selected.length >= 2) TextButton(onPressed: _compare, child: Text('Comparar (${_selected.length})'))],
      body: AsyncView<List<Json>>(
        load: _api.simulations,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.history, title: 'Sin simulaciones guardadas', message: 'Guarda una simulación para consultarla después o compararla con otra.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = list[i];
              final id = s['id'] as String;
              final r = Map<String, dynamic>.from(s['resultado'] as Map);
              return NxCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Checkbox(
                    value: _selected.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true && _selected.length < 3) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    }),
                  ),
                  Expanded(child: Text(r['resumen'] as String, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.nx.text, fontSize: 13))),
                  IconButton(
                    tooltip: 'Recalcular con mis datos actuales',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final r2 = await _api.recalculate(id);
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text((r2['actual'] as Map)['resultado']['resumen'] as String), behavior: SnackBarBehavior.floating));
                    },
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
