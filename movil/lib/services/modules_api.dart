import 'api_service.dart';

typedef Json = Map<String, dynamic>;

/// Acceso a los módulos de la API (presupuestos, metas, deudas, simulador, asistente, etc.).
/// Devuelve el contenido de `data` de cada respuesta; los errores llegan como [ApiException].
class ModulesApi {
  final ApiService _api;
  ModulesApi([ApiService? api]) : _api = api ?? ApiService();

  Future<Json> _get(String path, [Map<String, dynamic>? q]) async => ((await _api.get(path, queryParams: q))['data'] ?? {}) as Json;
  Future<Json> _post(String path, [Object? body]) async => ((await _api.post(path, body ?? {}))['data'] ?? {}) as Json;
  Future<Json> _put(String path, Object body) async => ((await _api.put(path, body))['data'] ?? {}) as Json;
  Future<void> _delete(String path) async {
    await _api.delete(path);
  }

  List<Json> _list(dynamic v) => (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ---- Presupuestos -------------------------------------------------------------------------
  Future<List<Json>> budgets(String mes) async => _list((await _get('/budgets', {'mes': mes}))['budgets']);
  Future<void> createBudget(String categoriaId, String mes, double limite, {double umbral = 0.8}) =>
      _post('/budgets', {'categoria_id': categoriaId, 'mes': mes, 'monto_limite': limite, 'umbral_alerta': umbral});
  Future<void> updateBudget(String id, double limite, double umbral) => _put('/budgets/$id', {'monto_limite': limite, 'umbral_alerta': umbral});
  Future<void> deleteBudget(String id) => _delete('/budgets/$id');

  // ---- Metas --------------------------------------------------------------------------------
  Future<List<Json>> goals() async => _list((await _get('/goals'))['goals']);
  Future<void> createGoal(String nombre, double objetivo, String fechaLimite) =>
      _post('/goals', {'nombre': nombre, 'monto_objetivo': objetivo, 'fecha_limite': fechaLimite});
  Future<void> updateGoal(String id, Json data) => _put('/goals/$id', data);
  Future<Json> contribute(String id, double monto, String fecha, String cuentaId) =>
      _post('/goals/$id/contributions', {'monto': monto, 'fecha': fecha, 'cuenta_id': cuentaId});

  // ---- Deudas -------------------------------------------------------------------------------
  Future<List<Json>> debts() async => _list((await _get('/debts'))['debts']);
  Future<Json> debt(String id) => _get('/debts/$id');
  Future<Json> createDebt(Json data) => _post('/debts', data);
  Future<Json> payDebt(String id, double monto, String fecha, String cuentaId) =>
      _post('/debts/$id/payments', {'monto': monto, 'fecha': fecha, 'cuenta_id': cuentaId});
  Future<List<Json>> calendar({int dias = 60}) async => _list((await _get('/debts/calendar', {'dias': dias}))['items']);

  // ---- Recurrentes ----------------------------------------------------------------------------
  Future<List<Json>> recurring() async => _list((await _get('/recurring'))['recurrentes']);
  Future<void> createRecurring(Json data) => _post('/recurring', data);
  Future<void> updateRecurring(String id, Json data) => _put('/recurring/$id', data);
  Future<void> finishRecurring(String id) => _delete('/recurring/$id');

  // ---- Categorías y reglas ----------------------------------------------------------------------
  Future<List<Json>> rules() async => _list((await _get('/categories/rules'))['rules']);
  Future<void> createRule(String texto, String categoriaId) => _post('/categories/rules', {'texto_contiene': texto, 'categoria_id': categoriaId});
  Future<void> deleteRule(String id) => _delete('/categories/rules/$id');
  Future<List<Json>> reviewInbox() async => _list((await _get('/categories/review'))['items']);
  Future<Json> categorize(String transactionId, String categoriaId, {bool crearRegla = false}) =>
      _post('/categories/transactions/$transactionId', {'categoria_id': categoriaId, 'crear_regla': crearRegla});
  Future<void> createCategory(String nombre, String tipo) => _post('/categories', {'nombre': nombre, 'tipo': tipo});
  Future<void> deleteCategory(String id, {String? reasignarA}) => _delete('/categories/$id${reasignarA != null ? '?reasignar_a=$reasignarA' : ''}');

  // ---- Notificaciones ------------------------------------------------------------------------------
  Future<Json> notifications() => _get('/notifications');
  Future<void> markAllRead() => _post('/notifications/read-all');
  Future<void> markRead(String id) => _post('/notifications/$id/read');
  Future<List<Json>> notificationPrefs() async => _list((await _get('/notifications/preferences'))['preferences']);
  Future<void> setNotificationPref(String tipo, bool app) => _put('/notifications/preferences/$tipo', {'canal_app': app, 'canal_correo': false});

  // ---- Simulador -------------------------------------------------------------------------------------
  Future<Json> simulate(String kind, Json params) async => (await _post('/simulations/$kind', params))['simulacion'] as Json;
  Future<List<Json>> simulations() async => _list((await _get('/simulations'))['simulaciones']);
  Future<void> saveSimulation(String id) => _post('/simulations/$id/save');
  Future<Json> recalculate(String id) => _post('/simulations/$id/recalculate');
  Future<List<Json>> compare(List<String> ids) async => _list((await _post('/simulations/compare', {'ids': ids}))['escenarios']);

  // ---- Asistente ---------------------------------------------------------------------------------------
  Future<Json> ask(String mensaje, {String? conversacionId}) =>
      _post('/assistant/messages', {'mensaje': mensaje, 'conversacion_id': ?conversacionId});
  Future<List<Json>> conversations() async => _list((await _get('/assistant/conversations'))['conversaciones']);
  Future<List<Json>> conversationMessages(String id) async => _list((await _get('/assistant/conversations/$id/messages'))['mensajes']);
  Future<void> deleteConversation(String id) => _delete('/assistant/conversations/$id');
  Future<void> setAiConsent(bool otorgado) => _put('/auth/consent-ai', {'otorgado': otorgado});

  // ---- Reportes -------------------------------------------------------------------------------------------
  Future<Json> summary(String desde, String hasta) => _get('/dashboard/summary', {'desde': desde, 'hasta': hasta});
  Future<Json> position() => _get('/dashboard/position');
  Future<Json> spending(String mes) => _get('/dashboard/spending', {'mes': mes});
  Future<List<Json>> trend({int meses = 6}) async => _list((await _get('/dashboard/trend', {'meses': meses}))['meses']);

  // ---- Importación ------------------------------------------------------------------------------------------
  Future<List<Json>> imports() async => _list((await _get('/imports'))['importaciones']);
  Future<Json> upload(Json data) => _post('/imports', data);
  Future<Json> importDetail(String id) => _get('/imports/$id');
  Future<Json> updateImportMovement(String id, String movementId, Json data) => _put('/imports/$id/movements/$movementId', data);
  Future<Json> confirmImport(String id) => _post('/imports/$id/confirm');
  Future<Json> cancelImport(String id) => _post('/imports/$id/cancel');
  Future<Json> revertImport(String id) => _post('/imports/$id/revert');

  // ---- Seguridad -------------------------------------------------------------------------------------------------
  Future<void> changePassword(String actual, String nueva) => _post('/auth/change-password', {'password_actual': actual, 'password_nueva': nueva});
  Future<Json> forgotPassword(String email) => _post('/auth/forgot-password', {'email': email});
  Future<void> resetPassword(String token, String password) => _post('/auth/reset-password', {'token': token, 'password': password});
  Future<Json> twoFactorSetup() => _post('/auth/2fa/setup');
  Future<void> twoFactorEnable(String codigo) => _post('/auth/2fa/enable', {'codigo': codigo});
  Future<void> twoFactorDisable(String password) => _post('/auth/2fa/disable', {'password': password});
  Future<Json> exportData() => _get('/auth/export');
  Future<List<Json>> activity() async => _list((await _get('/audit/activity'))['activity']);
  Future<void> deleteAccount(String password) => _api.delete('/auth/account', body: {'password': password, 'confirmacion': 'ELIMINAR'});
}
