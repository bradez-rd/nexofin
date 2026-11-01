import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';

/// Transacciones recurrentes: renta, suscripciones y nómina (RF-TRX-06).
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<List<Json>>>();

  static const _freq = {'semanal': 'Semanal', 'quincenal': 'Quincenal', 'mensual': 'Mensual', 'anual': 'Anual'};

  Future<void> _create() async {
    final desc = TextEditingController();
    final monto = TextEditingController();
    String tipo = 'gasto';
    String frecuencia = 'mensual';
    String? cuenta;
    String? categoria;
    DateTime inicio = DateTime.now();
    DateTime? fin;
    String? error;
    final saved = await showNxSheet<bool>(
      context,
      title: 'Nueva recurrencia',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'gasto', label: Text('Gasto')), ButtonSegment(value: 'ingreso', label: Text('Ingreso'))],
              selected: {tipo},
              onSelectionChanged: (s) => set(() {
                tipo = s.first;
                categoria = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción (renta, Netflix, nómina…)')),
            const SizedBox(height: 12),
            MoneyField(controller: monto),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: frecuencia,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: [for (final e in _freq.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => set(() => frecuencia = v ?? 'mensual'),
            ),
            const SizedBox(height: 12),
            AccountPicker(value: cuenta, includeCards: false, onChanged: (v) => set(() => cuenta = v)),
            const SizedBox(height: 12),
            CategoryPicker(value: categoria, tipo: tipo, allowNone: true, label: 'Categoría (opcional)', onChanged: (v) => set(() => categoria = v)),
            const SizedBox(height: 12),
            DateField(label: 'Primera fecha', value: inicio, onChanged: (d) => set(() => inicio = d)),
            const SizedBox(height: 12),
            DateField(label: 'Fecha de fin (opcional)', value: fin, onChanged: (d) => set(() => fin = d)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final m = parseMoney(monto.text);
                  if (desc.text.trim().length < 2) return set(() => error = 'Escribe una descripción');
                  if (m == null || m <= 0) return set(() => error = 'Indica un monto mayor que cero');
                  if (cuenta == null) return set(() => error = 'Elige la cuenta');
                  try {
                    await _api.createRecurring({
                      'cuenta_id': cuenta,
                      'categoria_id': categoria,
                      'tipo': tipo,
                      'monto': m,
                      'descripcion': desc.text.trim(),
                      'frecuencia': frecuencia,
                      'fecha_inicio': apiDate(inicio),
                      if (fin != null) 'fecha_fin': apiDate(fin!),
                    });
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    set(() => error = errText(e));
                  }
                },
                child: const Text('Crear recurrencia'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Recurrentes',
      fab: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Recurrente'),
      ),
      body: AsyncView<List<Json>>(
        key: _key,
        load: _api.recurring,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.autorenew, title: 'Sin recurrencias', message: 'Programa tu renta, suscripciones o nómina y se registrarán solas en cada periodo.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = list[i];
              final ingreso = r['tipo'] == 'ingreso';
              final estado = r['estado'] as String;
              return NxCard(
                child: Row(children: [
                  Icon(ingreso ? Icons.south_west : Icons.north_east, color: ingreso ? context.nx.positive : context.nx.negative),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['descripcion'] as String, style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                      Text('${_freq[r['frecuencia']]} · desde ${DateFormatter.format(r['fecha_inicio'])}${r['fecha_fin'] != null ? ' hasta ${DateFormatter.format(r['fecha_fin'])}' : ''}', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                      const SizedBox(height: 4),
                      NxChip(switch (estado) { 'pausada' => 'Pausada', 'finalizada' => 'Finalizada', _ => 'Activa' }, color: estado == 'activa' ? context.nx.positive : null),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(rd(n(r['monto'])), style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                    if (estado != 'finalizada')
                      PopupMenuButton<String>(
                        tooltip: 'Opciones',
                        onSelected: (v) async {
                          final id = r['id'] as String;
                          if (v == 'finalizar') {
                            if (await confirmDialog(context, 'Finalizar recurrencia', 'No se generarán más movimientos; los ya creados se conservan.', confirm: 'Finalizar', danger: true)) await _api.finishRecurring(id);
                          } else {
                            await _api.updateRecurring(id, {'estado': v});
                          }
                          reload();
                        },
                        itemBuilder: (_) => [
                          if (estado == 'activa') const PopupMenuItem(value: 'pausada', child: Text('Pausar')) else const PopupMenuItem(value: 'activa', child: Text('Reanudar')),
                          const PopupMenuItem(value: 'finalizar', child: Text('Finalizar')),
                        ],
                      ),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
