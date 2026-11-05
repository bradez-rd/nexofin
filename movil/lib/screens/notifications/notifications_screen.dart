import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../../core/theme/app_theme.dart';

const _typeNames = {
  'presupuesto_umbral': 'Presupuesto cerca del límite',
  'presupuesto_superado': 'Presupuesto superado',
  'cuota_proxima': 'Cuota próxima a vencer',
  'pago_tarjeta_proximo': 'Pago de tarjeta próximo',
  'importacion_lista': 'Importación lista para revisar',
  'meta_alcanzada': 'Meta alcanzada',
};

IconData _icon(String tipo) => switch (tipo) {
      'presupuesto_superado' => Icons.warning_amber_rounded,
      'presupuesto_umbral' => Icons.pie_chart_outline,
      'cuota_proxima' => Icons.event_outlined,
      'pago_tarjeta_proximo' => Icons.credit_card,
      'importacion_lista' => Icons.upload_file_outlined,
      _ => Icons.emoji_events_outlined,
    };

/// Centro de notificaciones con historial y preferencias (RF-NOT-01 a 03).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<Json>>();

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Notificaciones',
      actions: [
        IconButton(
          tooltip: 'Marcar todas como leídas',
          icon: const Icon(Icons.done_all),
          onPressed: () async {
            await _api.markAllRead();
            _key.currentState?.reload();
          },
        ),
        IconButton(
          tooltip: 'Preferencias',
          icon: const Icon(Icons.tune),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPrefsScreen())),
        ),
      ],
      body: AsyncView<Json>(
        key: _key,
        load: _api.notifications,
        builder: (context, data, reload) {
          final list = (data['notifications'] as List).cast<Map>();
          if (list.isEmpty) {
            return ListView(children: const [SizedBox(height: 60), NxEmpty(icon: Icons.notifications_none, title: 'Sin notificaciones', message: 'Aquí verás avisos de presupuestos, vencimientos, importaciones y metas.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final nt = list[i];
              final unread = nt['leida'] != true;
              return NxCard(
                padding: const EdgeInsets.all(12),
                onTap: unread
                    ? () async {
                        await _api.markRead(nt['id'] as String);
                        reload();
                      }
                    : null,
                child: Row(children: [
                  Icon(_icon(nt['tipo'] as String), color: unread ? context.nx.accent : context.nx.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nt['mensaje'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w500, color: context.nx.text)),
                      Text(DateFormatter.format(nt['creada_en']), style: TextStyle(fontSize: 12, color: context.nx.muted)),
                    ]),
                  ),
                  if (unread) Container(width: 10, height: 10, decoration: BoxDecoration(color: context.nx.accent, shape: BoxShape.circle)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ModulesApi();
    return NxPage(
      title: 'Preferencias de avisos',
      body: AsyncView<List<Json>>(
        load: api.notificationPrefs,
        builder: (context, prefs, reload) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Elige qué avisos quieres recibir dentro de la aplicación. Un aviso desactivado no se genera.', style: TextStyle(color: context.nx.muted)),
            ),
            for (final p in prefs)
              SwitchListTile(
                activeThumbColor: AppTheme.emeraldLight,
                title: Text(_typeNames[p['tipo']] ?? '${p['tipo']}'),
                value: p['canal_app'] == true,
                onChanged: (v) async {
                  await api.setNotificationPref(p['tipo'] as String, v);
                  reload();
                },
              ),
          ],
        ),
      ),
    );
  }
}
