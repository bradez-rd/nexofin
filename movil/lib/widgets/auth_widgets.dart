import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Encabezado de marca de las pantallas de acceso (login / registro).
class AuthBrandHeader extends StatelessWidget {
  final VoidCallback? onSettings;
  const AuthBrandHeader({super.key, this.onSettings});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              dark ? 'assets/images/logo_nexofin_dark.png' : 'assets/images/logo_nexofin.png',
              height: 52,
              fit: BoxFit.contain,
              semanticLabel: 'NexoFin, inteligencia para tus finanzas',
            ),
          ),
        ),
        if (onSettings != null)
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.nx.muted),
            tooltip: 'Configurar servidor API',
            onPressed: onSettings,
          ),
      ],
    );
  }
}

/// Selector "Iniciar sesión | Crear cuenta".
class AuthModeTabs extends StatelessWidget {
  final bool loginSelected;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  const AuthModeTabs({super.key, required this.loginSelected, this.onLogin, this.onRegister});

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, IconData icon, bool selected, VoidCallback? onTap) {
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: selected ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? context.nx.card : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: selected ? context.nx.positive : context.nx.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? context.nx.positive : context.nx.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.nx.border),
      ),
      child: Row(
        children: [
          tab('Iniciar sesión', Icons.lock_outline, loginSelected, onLogin),
          tab('Crear cuenta', Icons.person_add_alt_1_outlined, !loginSelected, onRegister),
        ],
      ),
    );
  }
}

/// Etiqueta de campo con un elemento opcional a la derecha.
class AuthFieldLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const AuthFieldLabel(this.label, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: context.nx.text)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            // Si el aviso de la derecha no cabe en pantallas angostas, se reduce en lugar de desbordar
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso de error accesible (se anuncia a lectores de pantalla).
class AuthErrorBanner extends StatelessWidget {
  final String title;
  final String body;
  const AuthErrorBanner({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.nx.negative.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.nx.negative.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.gpp_bad_outlined, color: context.nx.negative),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: context.nx.negative)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 13, color: context.nx.text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
