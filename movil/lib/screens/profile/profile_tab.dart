import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Perfil (RF-AUT-08, solo lectura por ahora) y cierre de sesión.
class ProfileTab extends StatelessWidget {
  final VoidCallback onLogout;
  const ProfileTab({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = user?.nombre ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    Widget row(IconData icon, String label, String value) {
      return ListTile(
        leading: Icon(icon, color: context.nx.muted),
        title: Text(label, style: TextStyle(fontSize: 12, color: context.nx.muted)),
        subtitle: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.nx.text)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.emeraldPrimary,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nx.text)),
              Text(user?.email ?? '', style: TextStyle(color: context.nx.muted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: context.nx.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.nx.border),
          ),
          child: Column(
            children: [
              row(Icons.payments_outlined, 'Moneda predeterminada', user?.monedaPredeterminada == 'DOP' ? 'Peso dominicano (RD\$)' : (user?.monedaPredeterminada ?? '')),
              Divider(height: 1, color: context.nx.border),
              row(Icons.schedule, 'Zona horaria', user?.zonaHoraria ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.nx.negative,
            side: BorderSide(color: context.nx.negative),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
