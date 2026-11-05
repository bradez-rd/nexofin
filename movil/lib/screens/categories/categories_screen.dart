import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';

/// Categorías, reglas de categorización y bandeja de revisión (RF-CAT-01 a 06).
class CategoriesScreen extends StatelessWidget {
  final int initialTab;
  const CategoriesScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorías'),
          bottom: const TabBar(tabs: [Tab(text: 'Categorías'), Tab(text: 'Reglas'), Tab(text: 'Por revisar')]),
        ),
        body: const SafeArea(child: TabBarView(children: [_CategoriesTab(), _RulesTab(), _ReviewTab()])),
      ),
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final _api = ModulesApi();

  Future<void> _create() async {
    final nombre = TextEditingController();
    String tipo = 'gasto';
    String? error;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Nueva categoría',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(children: [
          TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'gasto', label: Text('Gasto')), ButtonSegment(value: 'ingreso', label: Text('Ingreso'))],
            selected: {tipo},
            onSelectionChanged: (s) => set(() => tipo = s.first),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nombre.text.trim().length < 2) return set(() => error = 'Escribe un nombre');
                try {
                  await _api.createCategory(nombre.text.trim(), tipo);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  set(() => error = errText(e));
                }
              },
              child: const Text('Crear'),
            ),
          ),
        ]),
      ),
    );
    if (ok == true && mounted) await context.read<TransactionProvider>().fetchCategories();
  }

  Future<void> _delete(CategoryModel c) async {
    String? reasignar;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Eliminar "${c.nombre}"',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Si la categoría tiene movimientos, elige a cuál categoría pasarán. Ninguna transacción queda sin categoría.', style: TextStyle(color: ctx.nx.muted)),
          const SizedBox(height: 12),
          CategoryPicker(value: reasignar, tipo: c.tipo, label: 'Reasignar a', allowNone: true, onChanged: (v) => set(() => reasignar = v)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ctx.nx.negative, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _api.deleteCategory(c.id, reasignarA: reasignar);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) toast(ctx, errText(e), error: true);
                }
              },
              child: const Text('Eliminar categoría'),
            ),
          ),
        ]),
      ),
    );
    if (ok == true && mounted) await context.read<TransactionProvider>().fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<TransactionProvider>().categories;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Categoría')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          for (final tipo in ['gasto', 'ingreso']) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(tipo == 'gasto' ? 'Gastos' : 'Ingresos', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text))),
            for (final c in cats.where((c) => c.tipo == tipo))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 16, backgroundColor: _colorOf(c.color, context), child: const Icon(Icons.label_outline, size: 16, color: Colors.white)),
                title: Text(c.nombre),
                trailing: c.esSistema ? const NxChip('Sistema') : IconButton(tooltip: 'Eliminar categoría', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(c)),
              ),
          ],
        ],
      ),
    );
  }

  Color _colorOf(String? hex, BuildContext context) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return context.nx.muted;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
}

class _RulesTab extends StatefulWidget {
  const _RulesTab();

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<List<Json>>>();

  Future<void> _create() async {
    final texto = TextEditingController();
    String? cat;
    String? error;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Nueva regla',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(children: [
          Text('Si la descripción contiene el texto, se asigna la categoría. Tus reglas tienen prioridad sobre la clasificación automática.', style: TextStyle(color: ctx.nx.muted)),
          const SizedBox(height: 12),
          TextField(controller: texto, decoration: const InputDecoration(labelText: 'La descripción contiene…')),
          const SizedBox(height: 12),
          CategoryPicker(value: cat, onChanged: (v) => set(() => cat = v)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (texto.text.trim().length < 2) return set(() => error = 'Escribe al menos 2 caracteres');
                if (cat == null) return set(() => error = 'Elige una categoría');
                try {
                  await _api.createRule(texto.text.trim(), cat!);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  set(() => error = errText(e));
                }
              },
              child: const Text('Crear regla'),
            ),
          ),
        ]),
      ),
    );
    if (ok == true) _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final cats = {for (final c in context.watch<TransactionProvider>().categories) c.id: c.nombre};
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Regla')),
      body: AsyncView<List<Json>>(
        key: _key,
        load: _api.rules,
        builder: (context, rules, reload) {
          if (rules.isEmpty) {
            return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.rule, title: 'Sin reglas', message: 'Crea una regla para que NexoFin categorice por ti los comercios que repites.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rules[i];
              return NxCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('"${r['texto_contiene']}"', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
                    Text('→ ${cats[r['categoria_id']] ?? 'Categoría'}', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                  ])),
                  IconButton(
                    tooltip: 'Eliminar regla',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await _api.deleteRule(r['id'] as String);
                      reload();
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

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  final _api = ModulesApi();

  Future<void> _assign(Json item, Future<void> Function() reload) async {
    String? cat;
    bool regla = true;
    final tipo = item['tipo'] as String;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Categorizar movimiento',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item['descripcion'] ?? 'Sin descripción'} · ${rd(n(item['monto']))}', style: TextStyle(fontWeight: FontWeight.w700, color: ctx.nx.text)),
          const SizedBox(height: 12),
          CategoryPicker(value: cat, tipo: tipo, onChanged: (v) => set(() => cat = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Crear una regla con esta descripción'), value: regla, onChanged: (v) => set(() => regla = v)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cat == null
                  ? null
                  : () async {
                      try {
                        await _api.categorize(item['id'] as String, cat!, crearRegla: regla);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) toast(ctx, errText(e), error: true);
                      }
                    },
              child: const Text('Guardar categoría'),
            ),
          ),
        ]),
      ),
    );
    if (ok == true) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Json>>(
      load: _api.reviewInbox,
      builder: (context, items, reload) {
        if (items.isEmpty) {
          return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.task_alt, title: 'Todo categorizado', message: 'Los movimientos con baja confianza o sin categoría aparecerán aquí para que los revises.')]);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = items[i];
            return NxCard(
              padding: const EdgeInsets.all(12),
              onTap: () => _assign(t, reload),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['descripcion'] ?? 'Sin descripción'}', style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                  Text('${DateFormatter.format(t['fecha'])} · ${t['estado_categoria'] == 'pendiente_revision' ? 'Baja confianza' : 'Sin categoría'}', style: TextStyle(color: context.nx.muted, fontSize: 12)),
                ])),
                Text(rd(n(t['monto'])), style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
              ]),
            );
          },
        );
      },
    );
  }
}
