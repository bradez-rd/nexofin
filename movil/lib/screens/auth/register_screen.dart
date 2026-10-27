import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_widgets.dart';
import '../home/main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Refresca los indicadores (correo válido, fuerza y coincidencia) al escribir.
    for (final c in [_emailController, _passwordController, _confirmController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final v = _emailController.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  // Reglas de contraseña. Solo la longitud la exige la API; las demás se recomiendan.
  bool get _ruleLength => _passwordController.text.length >= 10;
  bool get _ruleDigitOrSymbol => RegExp(r'[0-9\W_]').hasMatch(_passwordController.text);
  bool get _ruleCase =>
      RegExp(r'[a-z]').hasMatch(_passwordController.text) && RegExp(r'[A-Z]').hasMatch(_passwordController.text);

  int get _strength {
    if (_passwordController.text.isEmpty) return 0;
    var score = 0;
    if (_ruleLength) score++;
    if (_ruleDigitOrSymbol) score++;
    if (_ruleCase) score++;
    if (_passwordController.text.length >= 14) score++;
    return score;
  }

  void _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _error = 'Debes aceptar los Términos de Servicio y la Política de Privacidad para continuar.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      nombre: _nombreController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      moneda: 'DOP',
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Cuenta creada exitosamente!'),
          backgroundColor: context.nx.positive,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      setState(() => _error = authProvider.errorMessage ?? 'No se pudo crear la cuenta.');
    }
  }

  Widget _benefits() {
    Widget item(IconData icon, String text) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, size: 20, color: context.nx.positive),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.nx.muted),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.nx.border),
      ),
      child: Row(
        children: [
          item(Icons.payments_outlined, 'Cuentas en RD\$'),
          item(Icons.query_stats, 'Simulador What-If'),
          item(Icons.shield_outlined, 'Sin publicidad'),
        ],
      ),
    );
  }

  Widget _ruleRow(String text, bool ok, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? context.nx.positive : context.nx.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              required ? '$text (obligatorio)' : text,
              style: TextStyle(fontSize: 12, color: ok ? context.nx.text : context.nx.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strengthMeter() {
    final labels = ['', 'Débil', 'Media', 'Fuerte', 'Muy fuerte'];
    final colors = [
      context.nx.muted,
      context.nx.negative,
      context.nx.warning,
      context.nx.positive,
      context.nx.positive,
    ];
    final level = _strength;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.nx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fortaleza de la contraseña',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.nx.muted)),
              Text(
                labels[level],
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors[level]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < level ? colors[level] : context.nx.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _ruleRow('Mínimo 10 caracteres', _ruleLength, required: true),
          _ruleRow('Al menos 1 número o símbolo', _ruleDigitOrSymbol),
          _ruleRow('Mayúsculas y minúsculas combinadas', _ruleCase),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final confirm = _confirmController.text;
    final matches = confirm.isNotEmpty && confirm == _passwordController.text;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandHeader(),
                    const SizedBox(height: 24),
                    Text(
                      'Crea tu cuenta en NexoFin',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: context.nx.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu asesor financiero inteligente en República Dominicana. Configuración lista en menos de 2 minutos.',
                      style: TextStyle(fontSize: 14, color: context.nx.muted),
                    ),
                    const SizedBox(height: 20),
                    AuthModeTabs(
                      loginSelected: false,
                      onLogin: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),
                    _benefits(),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      AuthErrorBanner(title: 'No se pudo crear la cuenta', body: _error!),
                      const SizedBox(height: 16),
                    ],

                    // Nombre
                    AuthFieldLabel(
                      'Nombre completo',
                      trailing: Text('Requerido', style: TextStyle(fontSize: 12, color: context.nx.muted)),
                    ),
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(
                        hintText: 'Tu nombre y apellido',
                        prefixIcon: Icon(Icons.person_outline, color: context.nx.muted),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 2) return 'Ingresa al menos 2 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Correo
                    AuthFieldLabel(
                      'Correo electrónico',
                      trailing: _emailController.text.isEmpty
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _emailValid ? Icons.check_circle_outline : Icons.error_outline,
                                  size: 14,
                                  color: _emailValid ? context.nx.positive : context.nx.negative,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _emailValid ? 'Válido' : 'Revisa el formato',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _emailValid ? context.nx.positive : context.nx.negative,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: 'tucorreo@ejemplo.com',
                        prefixIcon: Icon(Icons.email_outlined, color: context.nx.muted),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'El correo es obligatorio';
                        if (!_emailValid) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contraseña
                    const AuthFieldLabel('Contraseña de seguridad'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        hintText: 'Crea una contraseña segura',
                        prefixIcon: Icon(Icons.lock_outline, color: context.nx.muted),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: context.nx.muted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 10) {
                          return 'La contraseña debe tener mínimo 10 caracteres';
                        }
                        return null;
                      },
                    ),
                    _strengthMeter(),
                    const SizedBox(height: 16),

                    // Confirmación
                    AuthFieldLabel(
                      'Confirmar contraseña',
                      trailing: confirm.isEmpty
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  matches ? Icons.check_circle_outline : Icons.error_outline,
                                  size: 14,
                                  color: matches ? context.nx.positive : context.nx.negative,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  matches ? 'Las contraseñas coinciden' : 'No coinciden',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: matches ? context.nx.positive : context.nx.negative,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Repite tu contraseña',
                        prefixIcon: Icon(Icons.lock_reset, color: context.nx.muted),
                      ),
                      validator: (val) {
                        if (val != _passwordController.text) return 'Las contraseñas no coinciden';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Términos
                    InkWell(
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                            activeColor: AppTheme.emeraldPrimary,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Acepto los Términos de Servicio y la Política de Privacidad de NexoFin AI.',
                                style: TextStyle(fontSize: 12, color: context.nx.muted, height: 1.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _submit,
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Crear cuenta y comenzar'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('¿Ya tienes una cuenta? ', style: TextStyle(color: context.nx.muted)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Iniciar sesión',
                            style: TextStyle(color: context.nx.positive, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: context.nx.border),
                    const SizedBox(height: 8),
                    Text(
                      'Proyecto académico ITLA • República Dominicana',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: context.nx.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
