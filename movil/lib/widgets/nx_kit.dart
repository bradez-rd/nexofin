import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../services/api_service.dart';

/// Utilidades visuales compartidas por las pantallas de los módulos de NexoFin.

String rd(num? v) => CurrencyFormatter.format(v);

num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

String errText(Object e) => e is ApiException ? e.message : 'Ocurrió un error inesperado. Inténtalo de nuevo.';

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? context.nx.negative : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Pantalla simple con título, acciones y cuerpo.
class NxPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;
  const NxPage({super.key, required this.title, required this.body, this.actions = const [], this.fab});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: body),
        floatingActionButton: fab,
      );
}

class NxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const NxCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material (y no un DecoratedBox) para que ListTile e InkWell dibujen bien sus efectos de toque.
    return Material(
      color: context.nx.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.nx.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: double.infinity, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class NxProgress extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  const NxProgress({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: 8,
          backgroundColor: context.nx.border,
          valueColor: AlwaysStoppedAnimation(color ?? context.nx.positive),
        ),
      );
}

class NxChip extends StatelessWidget {
  final String label;
  final Color? color;
  const NxChip(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.nx.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class NxEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const NxEmpty({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: context.nx.muted),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.nx.text)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.nx.muted)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

/// Carga asíncrona con estados de carga, error con reintento y recarga por arrastre.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const AsyncView({super.key, required this.load, required this.builder});

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await widget.load();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return NxEmpty(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar',
        message: errText(_error!),
        action: OutlinedButton(onPressed: reload, child: const Text('Reintentar')),
      );
    }
    return RefreshIndicator(onRefresh: reload, child: widget.builder(context, _data as T, reload));
  }
}

/// Hoja inferior con formulario; devuelve lo que se pase a `Navigator.pop`.
Future<R?> showNxSheet<R>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.nx.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ctx.nx.text)),
            const SizedBox(height: 16),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String confirm = 'Confirmar', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.nx.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(
          style: danger ? ElevatedButton.styleFrom(backgroundColor: ctx.nx.negative, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r == true;
}

/// Campo numérico de monto.
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const MoneyField({super.key, required this.controller, this.label = 'Monto (RD\$)'});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: 'RD\$ '),
      );
}

double? parseMoney(String text) => double.tryParse(text.replaceAll(',', '').trim());

/// Campo de fecha que abre el selector del sistema.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.firstDate, this.lastDate});

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 5),
          lastDate: lastDate ?? DateTime(now.year + 20),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
        child: Text(text.isEmpty ? 'Seleccionar' : text, style: TextStyle(color: text.isEmpty ? context.nx.muted : context.nx.text)),
      ),
    );
  }
}

String apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Sección que se despliega al tocar el título (reemplaza a ExpansionTile dentro de tarjetas).
class NxExpander extends StatefulWidget {
  final String title;
  final List<Widget> children;
  const NxExpander({super.key, required this.title, required this.children});

  @override
  State<NxExpander> createState() => _NxExpanderState();
}

class _NxExpanderState extends State<NxExpander> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: TextStyle(color: context.nx.accent, fontWeight: FontWeight.w700, fontSize: 14))),
              Icon(_open ? Icons.expand_less : Icons.expand_more, color: context.nx.muted),
            ]),
          ),
        ),
        if (_open) ...widget.children,
      ],
    );
  }
}
