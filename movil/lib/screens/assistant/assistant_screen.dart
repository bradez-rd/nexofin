import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';

class _Msg {
  final bool mine;
  final String text;
  final String? tipo;
  final List<Map> cifras;
  final String? simulacionId;
  _Msg(this.mine, this.text, {this.tipo, this.cifras = const [], this.simulacionId});
}

/// Chat con el asistente financiero (RF-ASI-01 a 08). Las respuestas indican su tipo de contenido
/// (cálculo, estimación o educativo) y permiten ver de dónde sale cada cifra.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _api = ModulesApi();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  String? _conversationId;
  bool _sending = false;
  bool _needsConsent = false;

  static const _suggestions = ['¿Cuánto tengo?', '¿Cuánto gasté este mes?', '¿Puedo gastar 5,000 en ropa?', '¿Cómo voy con mis presupuestos?'];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _sending = true;
    });
    _toBottom();
    try {
      final r = await _api.ask(text, conversacionId: _conversationId);
      _conversationId = r['conversacion_id'] as String?;
      final resp = r['respuesta'] as Map;
      setState(() => _msgs.add(_Msg(false, resp['contenido'] as String, tipo: resp['tipo_contenido'] as String?, cifras: (resp['cifras'] as List).cast<Map>(), simulacionId: resp['simulacion_id'] as String?)));
    } catch (e) {
      final msg = errText(e);
      if (msg.contains('consentimiento')) {
        setState(() => _needsConsent = true);
      } else {
        setState(() => _msgs.add(_Msg(false, msg)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _grantConsent() async {
    await _api.setAiConsent(true);
    setState(() => _needsConsent = false);
  }

  Widget _label(BuildContext context, String? tipo) {
    if (tipo == null) return const SizedBox.shrink();
    final (text, color) = switch (tipo) {
      'calculo' => ('Cálculo con tus datos', context.nx.positive),
      'estimacion' => ('Estimación', context.nx.warning),
      _ => ('Contenido educativo', context.nx.accent),
    };
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: NxChip(text, color: color));
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Asistente financiero',
      actions: [
        IconButton(
          tooltip: 'Nueva conversación',
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () => setState(() {
            _msgs.clear();
            _conversationId = null;
          }),
        ),
      ],
      body: _needsConsent
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: NxEmpty(
                icon: Icons.privacy_tip_outlined,
                title: 'Antes de empezar',
                message: 'El asistente usa tus cuentas, movimientos y metas para responder. Los cálculos se hacen en el servidor de NexoFin con tus propios datos y puedes retirar el permiso cuando quieras.',
                action: ElevatedButton(onPressed: _grantConsent, child: const Text('Aceptar y continuar')),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _msgs.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const SizedBox(height: 24),
                            Icon(Icons.auto_awesome, size: 40, color: context.nx.accent),
                            const SizedBox(height: 12),
                            Text('Pregúntame sobre tus finanzas', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.nx.text)),
                            const SizedBox(height: 6),
                            Text('Solo consulto y simulo; no cambio tus datos sin tu confirmación.', textAlign: TextAlign.center, style: TextStyle(color: context.nx.muted)),
                            const SizedBox(height: 16),
                            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                              for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _send(s)),
                            ]),
                          ],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: _msgs.length + (_sending ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _msgs.length) return const Padding(padding: EdgeInsets.all(8), child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                            final m = _msgs[i];
                            return Align(
                              alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
                                decoration: BoxDecoration(
                                  color: m.mine ? AppTheme.emeraldPrimary : context.nx.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: m.mine ? null : Border.all(color: context.nx.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!m.mine) _label(context, m.tipo),
                                    Text(m.text, style: TextStyle(color: m.mine ? Colors.white : context.nx.text, height: 1.35)),
                                    if (!m.mine && m.cifras.isNotEmpty)
                                      NxExpander(
                                        title: 'Ver detalle del cálculo',
                                        children: [
                                          for (final c in m.cifras)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text('${c['etiqueta']}: ${c['valor'] is num ? rd(c['valor'] as num) : c['valor']}', style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text, fontSize: 13)),
                                                Text('Origen: ${c['origen']}', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                                              ]),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          maxLength: 1000,
                          decoration: const InputDecoration(hintText: 'Escribe tu pregunta…', counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Enviar',
                        style: IconButton.styleFrom(backgroundColor: AppTheme.emeraldPrimary),
                        onPressed: _sending ? null : () => _send(),
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
