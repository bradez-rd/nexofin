import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/modules_api.dart';
import '../../widgets/nx_kit.dart';

/// Recuperar el acceso: pide el correo y luego el enlace recibido con la contraseña nueva (RF-AUT-05).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ModulesApi();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _request() async {
    if (!_email.text.contains('@')) return setState(() => _error = 'Escribe un correo válido');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _api.forgotPassword(_email.text.trim());
      setState(() {
        _sent = true;
        // En el entorno de desarrollo la API devuelve el enlace para poder probar sin servidor de correo.
        final demo = r['enlace_demo'] as String?;
        if (demo != null) _token.text = demo.split('token=').last;
        _info = 'Si el correo está registrado, recibirás un enlace que vence en 30 minutos. Pega aquí el código del enlace y elige tu nueva contraseña.';
      });
    } catch (e) {
      setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_password.text.length < 10) return setState(() => _error = 'La contraseña debe tener al menos 10 caracteres');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.resetPassword(_token.text.trim(), _password.text);
      if (!mounted) return;
      toast(context, 'Contraseña restablecida. Inicia sesión con la nueva contraseña.');
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxPage(
      title: 'Recuperar acceso',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_sent ? 'Restablece tu contraseña' : 'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.', style: TextStyle(color: context.nx.muted, height: 1.4)),
          const SizedBox(height: 16),
          TextField(controller: _email, enabled: !_sent, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
          if (_sent) ...[
            const SizedBox(height: 12),
            if (_info != null) Text(_info!, style: TextStyle(color: context.nx.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: _token, decoration: const InputDecoration(labelText: 'Código del enlace')),
            const SizedBox(height: 12),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña nueva (mínimo 10 caracteres)')),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: context.nx.negative))),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldPrimary, foregroundColor: Colors.white),
            onPressed: _busy ? null : (_sent ? _reset : _request),
            child: Text(_sent ? 'Cambiar contraseña' : 'Enviar enlace'),
          ),
        ],
      ),
    );
  }
}
