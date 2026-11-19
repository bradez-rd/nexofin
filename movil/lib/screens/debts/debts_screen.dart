import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';

/// Deudas y préstamos con calendario de cuotas y pagos (RF-CTA-06 a 09).
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<List<Json>>>();

  Future<void> _create() async {
    final acreedor = TextEditingController();
    final monto = TextEditingController();
    final tasa = TextEditingController(text: '0');
    final cuotas = TextEditingController();
    DateTime? primera;
    String? error;
    final saved = await showNxSheet<bool>(
      context,
      title: 'Nueva deuda',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          children: [
            TextField(controller: acreedor, decoration: const InputDecoration(labelText: 'Acreedor (banco, persona…)')),
            const SizedBox(height: 12),
            MoneyField(controller: monto, label: 'Monto original (RD\$)'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: tasa, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tasa anual %'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: cuotas, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'N.º de cuotas'))),
            ]),
            const SizedBox(height: 12),
            DateField(label: 'Fecha de la primera cuota', value: primera, onChanged: (d) => set(() => primera = d)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final m = parseMoney(monto.text);
                  final c = int.tryParse(cuotas.text.trim());
                  final t = double.tryParse(tasa.text.replaceAll(',', '.')) ?? 0;
                  if (acreedor.text.trim().length < 2) return set(() => error = 'Indica el acreedor');
                  if (m == null || m <= 0) return set(() => error = 'Indica un monto mayor que cero');
                  if (c == null || c < 1) return set(() => error = 'Indica el número de cuotas');
                  if (primera == null) return set(() => error = 'Elige la fecha de la primera cuota');
                  try {
                    await _api.createDebt({'acreedor': acreedor.text.trim(), 'monto_original': m, 'tasa_anual': t, 'num_cuotas': c, 'fecha_primera_cuota': apiDate(primera!)});
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    set(() => error = errText(e));
                  }
                },
                child: const Text('Registrar deuda'),
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
      title: 'Deudas',
      actions: [
        IconButton(
          tooltip: 'Calendario de obligaciones',
          icon: const Icon(Icons.event_note_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ObligationsCalendarScreen())),
        ),
      ],
      fab: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Deuda'),
      ),
      body: AsyncView<List<Json>>(
        key: _key,
        load: _api.debts,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 60),
              NxEmpty(icon: Icons.credit_score_outlined, title: 'Sin deudas registradas', message: 'Registra un préstamo para ver su calendario de cuotas y el saldo pendiente.'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = list[i];
              final prox = d['proxima_cuota'] as Map?;
              final saldada = d['estado'] == 'saldada';
              return NxCard(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: d['id'] as String)));
                  reload();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(d['acreedor'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.nx.text))),
                      NxChip(saldada ? 'Saldada' : 'Activa', color: saldada ? context.nx.positive : context.nx.warning),
                    ]),
                    const SizedBox(height: 8),
                    Text('Pendiente: ${rd(n(d['saldo_pendiente']))}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: context.nx.text)),
                    Text('${d['cuotas_restantes']} cuotas restantes · tasa ${d['tasa_anual']}%', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                    if (prox != null)
                      Text('Próxima: cuota ${prox['numero']} el ${DateFormatter.format(prox['vencimiento'])} · ${rd(n(prox['monto_pendiente']))}', style: TextStyle(color: context.nx.muted, fontSize: 13)),
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

class DebtDetailScreen extends StatefulWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<Json>>();

  Future<void> _pay(Json debt) async {
    final monto = TextEditingController(text: debt['proxima_cuota'] == null ? '' : '${n((debt['proxima_cuota'] as Map)['monto_pendiente'])}');
    String? cuenta;
    DateTime fecha = DateTime.now();
    String? error;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Pagar a ${debt['acreedor']}',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          children: [
            MoneyField(controller: monto),
            const SizedBox(height: 12),
            AccountPicker(value: cuenta, label: 'Pagar desde', includeCards: false, onChanged: (v) => set(() => cuenta = v)),
            const SizedBox(height: 12),
            DateField(label: 'Fecha del pago', value: fecha, lastDate: DateTime.now(), onChanged: (d) => set(() => fecha = d)),
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
                    await _api.payDebt(widget.debtId, m, apiDate(fecha), cuenta!);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    set(() => error = errText(e));
                  }
                },
                child: const Text('Registrar pago'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (mounted) toast(context, 'Pago registrado');
      _key.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Detalle de la deuda',
      body: AsyncView<Json>(
        key: _key,
        load: () => _api.debt(widget.debtId),
        builder: (context, data, reload) {
          final d = Map<String, dynamic>.from(data['deuda'] as Map);
          final cuotas = (data['cuotas'] as List).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['acreedor'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: context.nx.text)),
                  const SizedBox(height: 8),
                  Text('Saldo pendiente: ${rd(n(d['saldo_pendiente']))}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: context.nx.text)),
                  Text('Capital pendiente: ${rd(n(d['capital_pendiente']))} · monto original ${rd(n(d['monto_original']))}', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                  if (d['estado'] != 'saldada') ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: () => _pay(d), icon: const Icon(Icons.payments_outlined), label: const Text('Registrar pago')),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              Text('Calendario de cuotas', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
              const SizedBox(height: 8),
              for (final c in cuotas)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: context.nx.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.nx.border)),
                  child: Row(children: [
                    CircleAvatar(radius: 14, backgroundColor: context.nx.surface, child: Text('${c['numero']}', style: TextStyle(fontSize: 12, color: context.nx.text))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(DateFormatter.format(c['vencimiento']), style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                        Text('Capital ${rd(n(c['capital']))} · interés ${rd(n(c['interes']))}', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(rd(n(c['monto'])), style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                      NxChip(switch (c['estado']) { 'pagada' => 'Pagada', 'parcial' => 'Parcial', _ => 'Pendiente' }, color: c['estado'] == 'pagada' ? context.nx.positive : null),
                    ]),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Calendario cronológico de los próximos 60 días (cuotas, tarjetas y recurrentes de gasto).
class ObligationsCalendarScreen extends StatelessWidget {
  const ObligationsCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ModulesApi();
    return NxPage(
      title: 'Próximas obligaciones',
      body: AsyncView<List<Json>>(
        load: api.calendar,
        builder: (context, items, reload) {
          if (items.isEmpty) {
            return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.event_available_outlined, title: 'Nada por pagar', message: 'No hay cuotas, tarjetas ni gastos recurrentes en los próximos 60 días.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              final icon = switch (it['tipo']) { 'cuota_deuda' => Icons.account_balance_outlined, 'pago_tarjeta' => Icons.credit_card, _ => Icons.autorenew };
              return NxCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(icon, color: context.nx.muted),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it['descripcion'] as String, style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                    Text(DateFormatter.format(it['fecha']), style: TextStyle(fontSize: 12, color: context.nx.muted)),
                  ])),
                  Text(it['monto'] == null ? '—' : rd(n(it['monto'])), style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
