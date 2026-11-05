import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';

/// Metas de ahorro: crear, aportar y ver el progreso (RF-PRE-03 a 06).
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<List<Json>>>();

  Future<void> _create() async {
    final nombre = TextEditingController();
    final objetivo = TextEditingController();
    DateTime? fecha;
    String? error;
    final saved = await showNxSheet<bool>(
      context,
      title: 'Nueva meta de ahorro',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          children: [
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre de la meta')),
            const SizedBox(height: 12),
            MoneyField(controller: objetivo, label: 'Monto objetivo (RD\$)'),
            const SizedBox(height: 12),
            DateField(label: 'Fecha límite', value: fecha, firstDate: DateTime.now().add(const Duration(days: 1)), onChanged: (d) => set(() => fecha = d)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final monto = parseMoney(objetivo.text);
                  if (nombre.text.trim().length < 2) return set(() => error = 'Escribe un nombre');
                  if (monto == null || monto <= 0) return set(() => error = 'Indica un monto mayor que cero');
                  if (fecha == null) return set(() => error = 'Elige la fecha límite');
                  try {
                    await _api.createGoal(nombre.text.trim(), monto, apiDate(fecha!));
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    set(() => error = errText(e));
                  }
                },
                child: const Text('Crear meta'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _key.currentState?.reload();
  }

  Future<void> _contribute(Json g) async {
    final monto = TextEditingController();
    String? cuenta;
    DateTime fecha = DateTime.now();
    String? error;
    final res = await showNxSheet<Json>(
      context,
      title: 'Aportar a ${g['nombre']}',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          children: [
            Text('Necesitas ${rd(n(g['monto_mensual_necesario']))} al mes para llegar a tiempo.', style: TextStyle(color: ctx.nx.muted)),
            const SizedBox(height: 12),
            MoneyField(controller: monto),
            const SizedBox(height: 12),
            AccountPicker(value: cuenta, label: 'Cuenta de origen', includeCards: false, onChanged: (v) => set(() => cuenta = v)),
            const SizedBox(height: 12),
            DateField(label: 'Fecha', value: fecha, lastDate: DateTime.now(), onChanged: (d) => set(() => fecha = d)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final m = parseMoney(monto.text);
                  if (m == null || m <= 0) return set(() => error = 'Indica un monto mayor que cero');
                  if (cuenta == null) return set(() => error = 'Elige la cuenta de origen');
                  try {
                    final r = await _api.contribute(g['id'] as String, m, apiDate(fecha), cuenta!);
                    if (ctx.mounted) Navigator.pop(ctx, r);
                  } catch (e) {
                    set(() => error = errText(e));
                  }
                },
                child: const Text('Registrar aporte'),
              ),
            ),
          ],
        ),
      ),
    );
    if (res != null) {
      if (mounted) toast(context, (res['meta'] as Map)['estado'] == 'alcanzada' ? '¡Meta alcanzada! 🎉' : 'Aporte registrado');
      _key.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Metas de ahorro',
      fab: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Meta'),
      ),
      body: AsyncView<List<Json>>(
        key: _key,
        load: _api.goals,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 60),
              NxEmpty(icon: Icons.savings_outlined, title: 'Aún no tienes metas', message: 'Crea una meta con monto y fecha y te diremos cuánto ahorrar cada mes.'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final g = list[i];
              final estado = g['estado'] as String;
              final active = estado == 'activa';
              return NxCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(g['nombre'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.nx.text))),
                      NxChip(switch (estado) { 'alcanzada' => 'Alcanzada', 'pausada' => 'Pausada', 'cerrada' => 'Cerrada', _ => 'Activa' }, color: estado == 'alcanzada' ? context.nx.positive : null),
                      if (estado != 'alcanzada' && estado != 'cerrada')
                        PopupMenuButton<String>(
                          tooltip: 'Opciones de la meta',
                          onSelected: (v) async {
                            await _api.updateGoal(g['id'] as String, {'estado': v});
                            reload();
                          },
                          itemBuilder: (_) => [
                            if (active) const PopupMenuItem(value: 'pausada', child: Text('Pausar')) else const PopupMenuItem(value: 'activa', child: Text('Reanudar')),
                            const PopupMenuItem(value: 'cerrada', child: Text('Cerrar meta')),
                          ],
                        ),
                    ]),
                    const SizedBox(height: 8),
                    NxProgress(value: n(g['porcentaje']).toDouble() / 100),
                    const SizedBox(height: 8),
                    Text('${rd(n(g['acumulado']))} de ${rd(n(g['monto_objetivo']))} · ${g['porcentaje']}%', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Fecha límite: ${DateFormatter.format(g['fecha_limite'])}', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                    if (active) ...[
                      Text('Necesitas ${rd(n(g['monto_mensual_necesario']))} al mes', style: TextStyle(color: context.nx.text, fontWeight: FontWeight.w700, fontSize: 13)),
                      if (g['fecha_estimada_cumplimiento'] != null)
                        Text('Al ritmo actual la alcanzarías el ${DateFormatter.format(g['fecha_estimada_cumplimiento'])}', style: TextStyle(color: context.nx.muted, fontSize: 12)),
                      if (g['vencida'] == true) Text('La fecha límite ya pasó', style: TextStyle(color: context.nx.negative, fontSize: 12)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: () => _contribute(g), icon: const Icon(Icons.add, size: 18), label: const Text('Aportar')),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
