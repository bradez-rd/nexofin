import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../assistant/assistant_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../imports/import_screen.dart';
import '../notifications/notifications_screen.dart';
import '../recurring/recurring_screen.dart';
import '../reports/reports_screen.dart';
import '../security/security_screen.dart';

/// Perfil (RF-AUT-08), acceso a las herramientas financieras y cierre de sesión.
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
        _section(context, 'Planificación', [
          _Entry(Icons.pie_chart_outline, 'Presupuestos', 'Límites mensuales por categoría', () => const BudgetsScreen()),
          _Entry(Icons.savings_outlined, 'Metas de ahorro', 'Objetivos con aportes y progreso', () => const GoalsScreen()),
          _Entry(Icons.credit_score_outlined, 'Deudas', 'Cuotas, pagos y calendario', () => const DebtsScreen()),
          _Entry(Icons.autorenew, 'Recurrentes', 'Renta, suscripciones y nómina', () => const RecurringScreen()),
        ]),
        const SizedBox(height: 16),
        _section(context, 'Análisis', [
          _Entry(Icons.auto_awesome, 'Asistente financiero', 'Pregunta con lenguaje natural', () => const AssistantScreen()),
          _Entry(Icons.insights_outlined, 'Reportes', 'Balance, distribución, tendencia y exportación', () => const ReportsScreen()),
          _Entry(Icons.notifications_none, 'Notificaciones', 'Avisos de presupuestos y vencimientos', () => const NotificationsScreen()),
        ]),
        const SizedBox(height: 16),
        _section(context, 'Datos', [
          _Entry(Icons.upload_file_outlined, 'Importar estado de cuenta', 'CSV, Excel o PDF', () => const ImportScreen()),
          _Entry(Icons.label_outline, 'Categorías y reglas', 'Reglas automáticas y movimientos por revisar', () => const CategoriesScreen()),
          _Entry(Icons.shield_outlined, 'Seguridad y privacidad', 'Contraseña, dos pasos, mis datos', () => const SecurityScreen()),
        ]),
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

  Widget _section(BuildContext context, String title, List<_Entry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.nx.muted)),
        ),
        Material(
          color: context.nx.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.nx.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.nx.border),
                ListTile(
                  leading: Icon(entries[i].icon, color: context.nx.accent),
                  title: Text(entries[i].title, style: TextStyle(fontWeight: FontWeight.w700, color: context.nx.text)),
                  subtitle: Text(entries[i].subtitle, style: TextStyle(fontSize: 12, color: context.nx.muted)),
                  trailing: Icon(Icons.chevron_right, color: context.nx.muted),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => entries[i].page())),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Entry {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() page;
  const _Entry(this.icon, this.title, this.subtitle, this.page);
}
