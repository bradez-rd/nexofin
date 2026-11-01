import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/api_service.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../widgets/pickers.dart';

/// Importación de estados de cuenta CSV, Excel o PDF con revisión previa (RF-IMP-01 a 08).
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<List<Json>>>();

  Future<void> _start() async {
    String? cuenta;
    final picked = await showNxSheet<String>(
      context,
      title: 'Importar estado de cuenta',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Acepta archivos CSV, XLSX o PDF de hasta 5 MB. Podrás revisar cada movimiento antes de guardarlo.', style: TextStyle(color: ctx.nx.muted)),
          const SizedBox(height: 12),
          AccountPicker(value: cuenta, label: 'Cuenta destino', includeCards: true, onChanged: (v) => set(() => cuenta = v)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: cuenta == null ? null : () => Navigator.pop(ctx, cuenta),
              icon: const Icon(Icons.attach_file),
              label: const Text('Elegir archivo'),
            ),
          ),
        ]),
      ),
    );
    if (picked == null) return;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx', 'pdf']);
    if (files.isEmpty) return;
    final f = files.first;
    final bytes = await f.readAsBytes();
    await _upload(picked, f.name, base64Encode(bytes));
  }

  Future<void> _upload(String cuenta, String nombre, String contenido, {Json? mapeo}) async {
    try {
      final r = await _api.upload({'cuenta_id': cuenta, 'nombre_archivo': nombre, 'contenido_base64': contenido, 'mapeo': ?mapeo});
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ImportReviewScreen(importId: (r['importacion'] as Map)['id'] as String)));
      _key.currentState?.reload();
    } on ApiException catch (e) {
      if (e.statusCode == 422 && mounted) {
        final mapped = await _askMapping(e);
        if (mapped != null) await _upload(cuenta, nombre, contenido, mapeo: mapped);
      } else if (mounted) {
        toast(context, e.message, error: true);
      }
    }
  }

  /// La API no reconoció las columnas: el usuario indica cuál es la fecha, la descripción y el monto.
  Future<Json?> _askMapping(ApiException e) async {
    final cols = ((e.details?['columnas'] as List?) ?? const []).map((c) => '$c').toList();
    if (cols.isEmpty) {
      toast(context, e.message, error: true);
      return null;
    }
    int? fecha, desc, monto;
    return showNxSheet<Json>(
      context,
      title: 'Indica las columnas',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget picker(String label, int? value, ValueChanged<int?> onChanged) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<int>(
                  initialValue: value,
                  decoration: InputDecoration(labelText: label),
                  items: [for (var i = 0; i < cols.length; i++) DropdownMenuItem(value: i, child: Text(cols[i].isEmpty ? 'Columna ${i + 1}' : cols[i]))],
                  onChanged: (v) => set(() => onChanged(v)),
                ),
              );
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No reconocimos las columnas del archivo. Elige cuál corresponde a cada dato; lo recordaremos para el mismo formato.', style: TextStyle(color: ctx.nx.muted)),
            const SizedBox(height: 12),
            picker('Fecha', fecha, (v) => fecha = v),
            picker('Descripción', desc, (v) => desc = v),
            picker('Monto (negativo = salida)', monto, (v) => monto = v),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: fecha == null || desc == null || monto == null ? null : () => Navigator.pop(ctx, {'fecha': fecha, 'descripcion': desc, 'monto': monto}),
                child: const Text('Reintentar con este mapeo'),
              ),
            ),
          ]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Importaciones',
      fab: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldPrimary,
        foregroundColor: Colors.white,
        onPressed: _start,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importar'),
      ),
      body: AsyncView<List<Json>>(
        key: _key,
        load: _api.imports,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.upload_file_outlined, title: 'Sin importaciones', message: 'Sube el estado de cuenta de tu banco y revisa los movimientos antes de guardarlos.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final it = list[i];
              final estado = it['estado'] as String;
              return NxCard(
                padding: const EdgeInsets.all(12),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ImportReviewScreen(importId: it['id'] as String)));
                  reload();
                },
                child: Row(children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it['nombre_archivo'] as String, style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                    Text(DateFormatter.format(it['creada_en']), style: TextStyle(fontSize: 12, color: context.nx.muted)),
                    if (it['motivo_fallo'] != null) Text(it['motivo_fallo'] as String, style: TextStyle(fontSize: 12, color: context.nx.negative)),
                  ])),
                  NxChip(_estadoLabel(estado), color: estado == 'confirmada' ? context.nx.positive : (estado == 'fallida' ? context.nx.negative : null)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

String _estadoLabel(String e) => switch (e) {
      'en_cola' => 'En cola',
      'procesando' => 'Procesando',
      'lista_revision' => 'Lista para revisar',
      'fallida' => 'Fallida',
      'confirmada' => 'Confirmada',
      'cancelada' => 'Cancelada',
      _ => 'Revertida',
    };

/// Revisión de los movimientos detectados: aprobar, excluir y confirmar todo o nada.
class ImportReviewScreen extends StatefulWidget {
  final String importId;
  const ImportReviewScreen({super.key, required this.importId});

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<Json>>();
  bool _busy = false;

  Future<void> _run(Future<Json> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) toast(context, done);
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Revisar importación',
      body: AsyncView<Json>(
        key: _key,
        load: () => _api.importDetail(widget.importId),
        builder: (context, data, reload) {
          final imp = Map<String, dynamic>.from(data['importacion'] as Map);
          final res = Map<String, dynamic>.from(data['resumen'] as Map);
          final movs = (data['movimientos'] as List).cast<Map>();
          final estado = imp['estado'] as String;
          final review = estado == 'lista_revision';
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: NxCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(imp['nombre_archivo'] as String, style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text))), NxChip(_estadoLabel(estado))]),
                  if (imp['motivo_fallo'] != null) Text(imp['motivo_fallo'] as String, style: TextStyle(color: context.nx.negative)),
                  const SizedBox(height: 8),
                  Text('${res['detectados']} movimientos · ${res['duplicados_potenciales']} posibles duplicados · ${res['sin_categoria_sugerida']} sin categoría', style: TextStyle(color: context.nx.muted, fontSize: 13)),
                  Text('Entradas ${rd(n(res['total_entradas']))} · Salidas ${rd(n(res['total_salidas']))}', style: TextStyle(color: context.nx.text, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: movs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final m = movs[i];
                  final entrada = m['sentido'] == 'entrada';
                  final excluded = m['decision'] == 'excluido';
                  return Opacity(
                    opacity: excluded ? 0.55 : 1,
                    child: NxCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m['descripcion'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                          Wrap(spacing: 6, children: [
                            Text(DateFormatter.format(m['fecha']), style: TextStyle(fontSize: 12, color: context.nx.muted)),
                            if (m['duplicado_potencial'] == true) NxChip('Posible duplicado', color: context.nx.warning),
                          ]),
                        ])),
                        Text('${entrada ? '+' : '-'}${rd(n(m['monto']))}', style: TextStyle(fontWeight: FontWeight.w800, color: entrada ? context.nx.positive : context.nx.negative)),
                        if (review)
                          Switch(
                            value: !excluded,
                            onChanged: (v) async {
                              await _api.updateImportMovement(widget.importId, m['id'] as String, {'decision': v ? 'aprobado' : 'excluido'});
                              reload();
                            },
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: review
                    ? Row(children: [
                        Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _run(() => _api.cancelImport(widget.importId), 'Importación cancelada'), child: const Text('Cancelar'))),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _busy || n(res['aprobados']) == 0 ? null : () => _run(() => _api.confirmImport(widget.importId), 'Importación guardada'),
                            child: Text('Guardar ${res['aprobados']} movimientos'),
                          ),
                        ),
                      ])
                    : estado == 'confirmada'
                        ? OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await confirmDialog(context, 'Deshacer importación', 'Los movimientos importados se darán de baja y los saldos se recalcularán.', confirm: 'Deshacer', danger: true)) {
                                      await _run(() => _api.revertImport(widget.importId), 'Importación deshecha');
                                    }
                                  },
                            icon: const Icon(Icons.undo),
                            label: const Text('Deshacer importación (30 días)'),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
