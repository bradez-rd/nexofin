import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/auth_widgets.dart';
import 'register_screen.dart';
import '../home/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error; // mensaje del servidor tras un intento fallido

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      setState(() => _error = authProvider.errorMessage ?? 'Error al iniciar sesión');
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _showServerSettings() {
    final apiService = ApiService();
    final urlController = TextEditingController(text: apiService.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nx.surface,
        title: const Text('Configuración del servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajusta la URL base de la API REST de NexoFin según tu entorno de ejecución:',
              style: TextStyle(fontSize: 13, color: context.nx.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL de la API REST',
                hintText: 'http://10.0.2.2:3000/api/v1',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Emulador Android', style: TextStyle(fontSize: 12)),
                  onPressed: () => urlController.text = 'http://10.0.2.2:3000/api/v1',
                ),
                ActionChip(
                  label: const Text('Localhost', style: TextStyle(fontSize: 12)),
                  onPressed: () => urlController.text = 'http://localhost:3000/api/v1',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await apiService.setBaseUrl(urlController.text);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Servidor configurado en: ${urlController.text}')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    final locked = message.toLowerCase().contains('bloquead');
    final invalid = message.toLowerCase().contains('credenciales');
    final title = locked
        ? 'Cuenta bloqueada temporalmente'
        : invalid
            ? 'Credenciales inválidas'
            : 'No se pudo iniciar sesión';
    // Mensaje genérico: nunca se indica cuál campo falló (RF-AUT-03).
    final body = invalid ? 'Por seguridad, verifica tu correo y contraseña.' : message;
    return AuthErrorBanner(title: title, body: body);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

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
                    AuthBrandHeader(onSettings: _showServerSettings),
                    const SizedBox(height: 24),
                    Text(
                      'Bienvenido a NexoFin AI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: context.nx.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tus finanzas inteligentes y simulaciones en un solo lugar.',
                      style: TextStyle(fontSize: 14, color: context.nx.muted),
                    ),
                    const SizedBox(height: 20),
                    AuthModeTabs(loginSelected: true, onRegister: _goToRegister),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      _errorBanner(_error!),
                      const SizedBox(height: 16),
                    ],

                    AuthFieldLabel(
                      'Correo electrónico',
                      trailing: Text('Requerido', style: TextStyle(fontSize: 12, color: context.nx.muted)),
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
                        if (!val.contains('@') || !val.contains('.')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AuthFieldLabel(
                      'Contraseña',
                      trailing: GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('La recuperación de contraseña estará disponible próximamente.'),
                          ),
                        ),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.nx.positive,
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => authProvider.isLoading ? null : _submit(),
                      decoration: InputDecoration(
                        hintText: '••••••••••',
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
                        if (val == null || val.isEmpty) return 'La contraseña es requerida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

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
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Ingresar a NexoFin'),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.indigoAI.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.nx.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppTheme.indigoAI, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '¿Aún no eres parte?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: context.nx.text,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crea tu cuenta en menos de 2 minutos. Comienza con tu primera cuenta y meta financiera sin costo ni publicidad.',
                            style: TextStyle(fontSize: 13, height: 1.4, color: context.nx.muted),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                            onPressed: _goToRegister,
                            icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                            label: const Text('Crear cuenta gratuita'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.indigoAI,
                              side: const BorderSide(color: AppTheme.indigoAI),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
