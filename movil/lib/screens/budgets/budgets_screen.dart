import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';

/// Presupuestos mensuales por categoría (RF-PRE-01/02).
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<List<Json>>>();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _mes => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _shift(int d) {
    setState(() => _month = DateTime(_month.year, _month.month + d));
    _key.currentState?.reload();
  }

  Color _color(BuildContext c, String estado) => switch (estado) {
        'superado' => c.nx.negative,
        'alerta' => c.nx.warning,
        _ => c.nx.positive,
      };

  Future<void> _edit(Json? b) async {
    final limite = TextEditingController(text: b == null ? '' : '${n(b['monto_limite'])}');
    String? categoria = b?['categoria_id'] as String?;
    double umbral = b == null ? 0.8 : n(b['umbral_alerta']).toDouble();
    String? error;
    final saved = await showNxSheet<bool>(
      context,
      title: b == null ? 'Nuevo presupuesto' : 'Editar presupuesto',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (b == null) CategoryPicker(value: categoria, onChanged: (v) => set(() => categoria = v)) else Text(b['categoria_nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            MoneyField(controller: limite, label: 'Límite mensual (RD\$)'),
            const SizedBox(height: 12),
            Text('Avisarme al llegar al ${(umbral * 100).round()}%'),
            Slider(value: umbral, min: 0.5, max: 1, divisions: 10, label: '${(umbral * 100).round()}%', onChanged: (v) => set(() => umbral = v)),
            if (error != null) Text(error!, style: TextStyle(color: ctx.nx.negative)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final monto = parseMoney(limite.text);
                  if (monto == null || monto <= 0) return set(() => error = 'Indica un límite mayor que cero');
                  if (b == null && categoria == null) return set(() => error = 'Elige una categoría');
                  try {
                    if (b == null) {
                      await _api.createBudget(categoria!, _mes, monto, umbral: umbral);
                    } else {
                      await _api.updateBudget(b['id'] as String, monto, umbral);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    set(() => error = errText(e));
                  }
                },
                child: const Text('Guardar'),
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
      title: 'Presupuestos',
      fab: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Presupuesto'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(tooltip: 'Mes anterior', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
              Text(_mes, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.nx.text)),
              IconButton(tooltip: 'Mes siguiente', icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
            ],
          ),
          Expanded(
            child: AsyncView<List<Json>>(
              key: _key,
              load: () => _api.budgets(_mes),
              builder: (context, list, reload) {
                if (list.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 60),
                    NxEmpty(icon: Icons.pie_chart_outline, title: 'Sin presupuestos este mes', message: 'Define un límite por categoría y te avisaremos antes de pasarte.'),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final b = list[i];
                    final pct = n(b['porcentaje']).toDouble();
                    final color = _color(context, b['estado'] as String);
                    return NxCard(
                      onTap: () => _edit(b),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(b['categoria_nombre'] as String, style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text))),
                            NxChip(switch (b['estado']) { 'superado' => 'Superado', 'alerta' => 'En alerta', _ => 'Al día' }, color: color),
                            IconButton(
                              tooltip: 'Eliminar presupuesto',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                if (await confirmDialog(context, 'Eliminar presupuesto', '¿Eliminar el presupuesto de ${b['categoria_nombre']}?', confirm: 'Eliminar', danger: true)) {
                                  await _api.deleteBudget(b['id'] as String);
                                  reload();
                                }
                              },
                            ),
                          ]),
                          const SizedBox(height: 6),
                          NxProgress(value: pct / 100, color: color),
                          const SizedBox(height: 8),
                          Text('${rd(n(b['consumido']))} de ${rd(n(b['monto_limite']))} · $pct%', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                          Text(n(b['disponible']) >= 0 ? 'Te quedan ${rd(n(b['disponible']))}' : 'Te pasaste por ${rd(-n(b['disponible']))}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
