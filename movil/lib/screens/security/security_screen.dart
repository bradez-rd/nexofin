import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';
import '../auth/login_screen.dart';

/// Seguridad y privacidad: contraseña, verificación en dos pasos, permisos, datos y baja de la cuenta.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _api = ModulesApi();
  final _key = GlobalKey<AsyncViewState<Json>>();

  Future<Json> _load() async {
    final p = await ApiService().get('/auth/profile');
    final user = Map<String, dynamic>.from((p['data'] as Map)['user'] as Map);
    final act = await _api.activity();
    return {'user': user, 'activity': act};
  }

  Future<void> _changePassword() async {
    final actual = TextEditingController();
    final nueva = TextEditingController();
    String? error;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Cambiar contraseña',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(children: [
          TextField(controller: actual, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
          const SizedBox(height: 12),
          TextField(controller: nueva, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña nueva (mínimo 10 caracteres)')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: ctx.nx.negative))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nueva.text.length < 10) return set(() => error = 'La contraseña debe tener al menos 10 caracteres');
                try {
                  await _api.changePassword(actual.text, nueva.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  set(() => error = errText(e));
                }
              },
              child: const Text('Actualizar contraseña'),
            ),
          ),
        ]),
      ),
    );
    if (ok == true && mounted) toast(context, 'Contraseña actualizada. Las demás sesiones se cerraron.');
  }

  Future<void> _enable2fa() async {
    final setup = await _api.twoFactorSetup();
    if (!mounted) return;
    final code = TextEditingController();
    String? error;
    final ok = await showNxSheet<bool>(
      context,
      title: 'Activar verificación en dos pasos',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('1. Agrega este código secreto a tu app de autenticación (Google Authenticator, Authy…).\n2. Escribe el código de 6 dígitos que te muestre.', style: TextStyle(color: ctx.nx.muted)),
          const SizedBox(height: 12),
          NxCard(
            child: Row(children: [
              Expanded(child: SelectableText(setup['secreto'] as String, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.2))),
              IconButton(tooltip: 'Copiar código secreto', icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: setup['secreto'] as String))),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Código de 6 dígitos', counterText: '')),
          if (error != null) Text(error!, style: TextStyle(color: ctx.nx.negative)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await _api.twoFactorEnable(code.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  set(() => error = errText(e));
                }
              },
              child: const Text('Activar'),
            ),
          ),
        ]),
      ),
    );
    if (ok == true) _key.currentState?.reload();
  }

  Future<void> _disable2fa() async {
    final pw = await _askPassword('Desactivar verificación en dos pasos', 'Escribe tu contraseña para confirmar.');
    if (pw == null) return;
    try {
      await _api.twoFactorDisable(pw);
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<String?> _askPassword(String title, String message) async {
    final c = TextEditingController();
    return showNxSheet<String>(
      context,
      title: title,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: TextStyle(color: ctx.nx.muted)),
        const SizedBox(height: 12),
        TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Confirmar'))),
      ]),
    );
  }

  Future<void> _export() async {
    try {
      final data = await _api.exportData();
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      final path = await FilePicker.saveFile(dialogTitle: 'Guardar mis datos', fileName: 'nexofin_mis_datos.json', bytes: bytes, mimeType: 'application/json');
      if (mounted && path != null) toast(context, 'Datos exportados');
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> _delete() async {
    final pw = await _askPassword('Eliminar mi cuenta', 'Se borrarán tu cuenta y todos tus datos financieros. Esta acción no se puede deshacer. Escribe tu contraseña para confirmar.');
    if (pw == null || !mounted) return;
    try {
      await _api.deleteAccount(pw);
      if (!mounted) return;
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  String _actionLabel(String a) => switch (a) {
        'login' => 'Inicio de sesión',
        'logout' => 'Cierre de sesión',
        'registro' => 'Registro',
        'password_cambio' => 'Cambio de contraseña',
        'password_reset' => 'Restablecimiento de contraseña',
        'password_reset_solicitud' => 'Solicitud de restablecimiento',
        'dos_factores' => 'Verificación en dos pasos',
        'exportacion' => 'Exportación de datos',
        'transaccion_eliminada' => 'Transacción eliminada',
        'importacion_confirmada' => 'Importación confirmada',
        'consentimiento_ia' => 'Permiso del asistente',
        _ => a,
      };

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Seguridad y privacidad',
      body: AsyncView<Json>(
        key: _key,
        load: _load,
        builder: (context, data, reload) {
          final user = Map<String, dynamic>.from(data['user'] as Map);
          final act = (data['activity'] as List).cast<Map>();
          final twoFa = user['dos_factores_activo'] == true;
          final ai = user['consentimiento_ia_en'] != null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NxCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(leading: const Icon(Icons.password), title: const Text('Cambiar contraseña'), trailing: const Icon(Icons.chevron_right), onTap: _changePassword),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Verificación en dos pasos'),
                    subtitle: Text(twoFa ? 'Activada' : 'Desactivada'),
                    trailing: TextButton(onPressed: twoFa ? _disable2fa : _enable2fa, child: Text(twoFa ? 'Desactivar' : 'Activar')),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome_outlined),
                    activeThumbColor: AppTheme.emeraldLight,
                    title: const Text('Permitir que el asistente use mis datos'),
                    subtitle: const Text('Necesario para el chat financiero (usa Gemini o Claude)'),
                    value: ai,
                    onChanged: (v) async {
                      await _api.setAiConsent(v);
                      reload();
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              NxCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Descargar mis datos'), subtitle: const Text('Archivo JSON con tus cuentas, movimientos, presupuestos y metas'), onTap: _export),
                  const Divider(height: 1),
                  ListTile(leading: Icon(Icons.delete_forever_outlined, color: context.nx.negative), title: Text('Eliminar mi cuenta', style: TextStyle(color: context.nx.negative)), onTap: _delete),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Actividad reciente', style: TextStyle(fontWeight: FontWeight.w800, color: context.nx.text)),
              const SizedBox(height: 8),
              for (final a in act)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(a['resultado'] == 'exito' ? Icons.check_circle_outline : Icons.error_outline, color: a['resultado'] == 'exito' ? context.nx.positive : context.nx.negative, size: 20),
                  title: Text(_actionLabel(a['accion'] as String)),
                  subtitle: Text(DateFormatter.format(a['fecha'])),
                  trailing: a['resultado'] == 'exito' ? null : const NxChip('Fallido'),
                ),
            ],
          );
        },
      ),
    );
  }
}
