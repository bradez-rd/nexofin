import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
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
  String _selectedCurrency = 'DOP';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      nombre: _nombreController.text,
      email: _emailController.text,
      password: _passwordController.text,
      moneda: _selectedCurrency,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente!'),
          backgroundColor: AppTheme.emeraldLight,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error al registrar usuario'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Únete a NexoFin AI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Centraliza tus cuentas, analiza tus gastos y proyecta tu libertad financiera.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 24),

                // Name
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Ingresa al menos 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'El correo es requerido';
                    if (!val.contains('@') || !val.contains('.')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña (mínimo 10 caracteres)',
                    helperText: 'Política RF-AUT-01: Al menos 10 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 10) {
                      return 'La contraseña debe tener mínimo 10 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Currency selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Moneda Predeterminada',
                    prefixIcon: Icon(Icons.monetization_on_outlined, color: Color(0xFF94A3B8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DOP', child: Text('Peso Dominicano (RD\$ DOP)')),
                    DropdownMenuItem(value: 'USD', child: Text('Dólar Estadounidense (US\$ USD)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrency = val);
                  },
                ),
                const SizedBox(height: 28),

                // Submit
                ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _submit,
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Completar Registro'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
