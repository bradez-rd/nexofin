import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

class SimulatorTab extends StatefulWidget {
  const SimulatorTab({super.key});

  @override
  State<SimulatorTab> createState() => _SimulatorTabState();
}

class _SimulatorTabState extends State<SimulatorTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Simulator state
  final _gastoSimuladoController = TextEditingController(text: '15000');
  final _mesesProyeccionController = TextEditingController(text: '6');
  double _impactoCalculado = 0.0;
  bool _simulacionCalculada = false;

  // AI Chat state
  final _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'text':
          '¡Hola! Soy tu Asesor Financiero NexoFin AI. Puedo ayudarte a analizar tus finanzas, evaluar tu capacidad de endeudamiento o simular compras en RD\$. ¿Qué te gustaría consultar hoy?',
      'time': 'Ahora'
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gastoSimuladoController.dispose();
    _mesesProyeccionController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _ejecutarSimulacion(double saldoActual, double ingresos, double gastos) {
    final gastoFuturo = double.tryParse(_gastoSimuladoController.text) ?? 0.0;
    final meses = int.tryParse(_mesesProyeccionController.text) ?? 6;

    final ahorroMensual = (ingresos - gastos).clamp(0.0, double.infinity);
    final proyeccion = saldoActual + (ahorroMensual * meses) - gastoFuturo;

    setState(() {
      _impactoCalculado = proyeccion;
      _simulacionCalculada = true;
    });
  }

  void _enviarPreguntaAI(double saldoActual, double ingresos, double gastos) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'time': 'Ahora',
      });
      _chatController.clear();
    });

    // Generate intelligent deterministic response based on real financial state
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      String respuesta;
      final lower = text.toLowerCase();
      final ahorroMensual = ingresos - gastos;

      if (lower.contains('endeudamiento') || lower.contains('préstamo') || lower.contains('credito')) {
        final capacidad = ingresos * 0.35;
        respuesta =
            'De acuerdo a las mejores prácticas financieras dominicanas (normas de la Superintendencia de Bancos), tu cuota mensual máxima no debe superar el 35% de tus ingresos netos. Con tus ingresos actuales de ${CurrencyFormatter.format(ingresos)}, tu capacidad máxima de cuota estimada es de **${CurrencyFormatter.format(capacidad)}/mes**.';
      } else if (lower.contains('ahorro') || lower.contains('ahorrar')) {
        respuesta =
            'Tu flujo neto mensual actual es de ${CurrencyFormatter.format(ahorroMensual)}. Siguiendo la regla 50/30/20, se recomienda destinar al menos el 20% (${CurrencyFormatter.format(ingresos * 0.20)}) a un fondo de emergencia en una cuenta de alto rendimiento en DOP.';
      } else if (lower.contains('gasto') || lower.contains('reducir')) {
        respuesta =
            'Tus egresos mensuales suman ${CurrencyFormatter.format(gastos)}. Te sugiero auditar las categorías recurrentes y verificar que tus gastos variables no superen el 30% del presupuesto total.';
      } else {
        respuesta =
            'Con tu patrimonio neto actual de ${CurrencyFormatter.format(saldoActual)} y un balance neto mensual de ${CurrencyFormatter.format(ahorroMensual)}, tu salud financiera determinística es positiva. ¿Deseas simular una meta de ahorro o verificar tu capacidad de pago?';
      }

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': respuesta,
          'time': 'Ahora',
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final saldoActual = accountProvider.totalNetWorthDOP;
    final summary = transactionProvider.monthlySummary;
    final ingresos = summary?.ingresos ?? 0.0;
    final gastos = summary?.gastos ?? 0.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: context.nx.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.indigoAI,
            labelColor: context.nx.text,
            unselectedLabelColor: context.nx.muted,
            tabs: const [
              Tab(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 16),
                    SizedBox(width: 8),
                    Text('Simulador What-If'),
                  ],
                ),
              ),
              Tab(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: AppTheme.indigoAI),
                    SizedBox(width: 8),
                    Text('Asesor IA'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Simulator What-If
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.indigoAI.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.indigoAI.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insights, color: AppTheme.indigoAI, size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Proyecta el impacto de compras mayores, financiamientos o metas sin comprometer tu liquidez real.',
                          style: TextStyle(fontSize: 13, color: context.nx.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.nx.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.nx.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parámetros de Simulación',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.nx.text),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _gastoSimuladoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Gasto o Inversión Extraordinaria (RD\$)',
                          prefixText: 'RD\$ ',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _mesesProyeccionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Horizonte de Proyección (Meses)',
                          suffixText: 'meses',
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.indigoAI),
                        onPressed: () => _ejecutarSimulacion(saldoActual, ingresos, gastos),
                        child: const Text('Simular Impacto Proyectado'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Results Card
                if (_simulacionCalculada)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _impactoCalculado >= 0
                              ? const Color(0xFF0F3B30)
                              : const Color(0xFF3B0F15),
                          context.nx.card,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _impactoCalculado >= 0 ? context.nx.positive : context.nx.negative,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saldo Libre Proyectado',
                              style: TextStyle(fontSize: 14, color: context.nx.muted),
                            ),
                            Icon(
                              _impactoCalculado >= 0 ? Icons.check_circle : Icons.warning_rounded,
                              color: _impactoCalculado >= 0 ? context.nx.positive : context.nx.negative,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          CurrencyFormatter.format(_impactoCalculado),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _impactoCalculado >= 0 ? context.nx.positive : context.nx.negative,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _impactoCalculado >= 0
                              ? '¡Escenario viable! Mantendrás solvencia y liquidez positiva tras efectuar el desembolso.'
                              : 'Alerta de sobreendeudamiento: El gasto supera tu tasa de ahorro libre proyectada para ese periodo.',
                          style: TextStyle(fontSize: 13, color: context.nx.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Tab 2: AI Advisor Chat
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = _messages[idx];
                    final isUser = msg['role'] == 'user';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isUser ? AppTheme.emeraldPrimary : context.nx.card,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                            bottomLeft: !isUser ? Radius.zero : const Radius.circular(16),
                          ),
                          border: Border.all(
                            color: isUser ? Colors.transparent : context.nx.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 14, color: AppTheme.indigoAI),
                                  SizedBox(width: 6),
                                  Text(
                                    'NexoFin AI',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.indigoAI,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              msg['text'],
                              style: TextStyle(fontSize: 14, color: context.nx.text, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Chat Input Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.nx.surface,
                  border: Border(top: BorderSide(color: context.nx.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: const InputDecoration(
                          hintText: 'Pregunta a NexoFin AI sobre tus finanzas...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _enviarPreguntaAI(saldoActual, ingresos, gastos),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppTheme.indigoAI),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () => _enviarPreguntaAI(saldoActual, ingresos, gastos),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
