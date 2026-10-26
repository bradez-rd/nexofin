/**
 * NexoFin AI - Frontend Client Controller
 * Conecta la interfaz de usuario con la API REST de Node.js + PostgreSQL.
 */

const API_BASE = '/api/v1';

const state = {
  token: localStorage.getItem('nexofin_token') || null,
  user: JSON.parse(localStorage.getItem('nexofin_user') || 'null'),
  accounts: [],
  categories: [],
  transactions: [],
  summary: null,
};

// ============================================================================
// Utilidades de Red (Fetch con Auth)
// ============================================================================

async function apiRequest(endpoint, options = {}) {
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  if (state.token) {
    headers['Authorization'] = `Bearer ${state.token}`;
  }

  try {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
    });

    const data = await res.json();
    if (!res.ok) {
      const errorMsg = data?.error?.message || 'Error en la petición al servidor';
      throw new Error(errorMsg);
    }
    return data;
  } catch (error) {
    console.error(`API Error [${endpoint}]:`, error.message);
    throw error;
  }
}

function formatRD(amount) {
  const num = Number(amount) || 0;
  return 'RD$ ' + num.toLocaleString('es-DO', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatDate(dateStr) {
  if (!dateStr) return '';
  const parts = dateStr.split('-');
  if (parts.length === 3) {
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
  }
  return dateStr;
}

function showToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  
  const icon = type === 'success' ? 'check_circle' : type === 'error' ? 'error' : 'info';
  toast.innerHTML = `
    <span class="material-symbols-outlined">${icon}</span>
    <span>${message}</span>
  `;

  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

// ============================================================================
// 1. Verificación de Salud de Base de Datos
// ============================================================================

async function checkDatabaseHealth() {
  const badgeText = document.getElementById('db-health-text');
  const badgeDot = document.querySelector('.health-dot');

  try {
    const res = await apiRequest('/health');
    if (res.status === 'UP' && res.database.connected) {
      badgeText.textContent = `${res.database.engine} (${res.database.latencyMs}ms)`;
      badgeDot.style.background = '#10B981';
    } else {
      badgeText.textContent = 'BD No Disponible';
      badgeDot.style.background = '#EF4444';
    }
  } catch (err) {
    if (badgeText) badgeText.textContent = 'Servidor Desconectado';
    if (badgeDot) badgeDot.style.background = '#EF4444';
  }
}

// ============================================================================
// 2. Control de Vistas y Autenticación
// ============================================================================

function updateUIForAuthState() {
  const authView = document.getElementById('auth-view');
  const appView = document.getElementById('app-view');
  const userMenu = document.getElementById('user-profile-menu');
  const userDisplayName = document.getElementById('user-display-name');
  const userDisplayEmail = document.getElementById('user-display-email');
  const userAvatar = document.getElementById('user-avatar-initials');
  const welcomeUserText = document.getElementById('welcome-user-text');

  if (state.token && state.user) {
    authView.classList.add('hidden');
    appView.classList.remove('hidden');
    userMenu.classList.remove('hidden');

    userDisplayName.textContent = state.user.nombre;
    userDisplayEmail.textContent = state.user.email;
    userAvatar.textContent = state.user.nombre.charAt(0).toUpperCase();
    welcomeUserText.textContent = `¡Hola, ${state.user.nombre}! 👋`;

    // Cargar datos del usuario
    loadDashboardData();
  } else {
    authView.classList.remove('hidden');
    appView.classList.add('hidden');
    userMenu.classList.add('hidden');
  }
}

function setSession(authData) {
  state.token = authData.token;
  state.user = authData.user;
  localStorage.setItem('nexofin_token', authData.token);
  localStorage.setItem('nexofin_user', JSON.stringify(authData.user));
  updateUIForAuthState();
}

function logout() {
  state.token = null;
  state.user = null;
  localStorage.removeItem('nexofin_token');
  localStorage.removeItem('nexofin_user');
  updateUIForAuthState();
  showToast('Has cerrado sesión correctamente', 'info');
}

// ============================================================================
// 3. Cuentas Financieras (Módulo CTA)
// ============================================================================

async function loadAccounts() {
  try {
    const res = await apiRequest('/accounts');
    state.accounts = res.data.accounts || [];
    renderAccountsList();
    populateAccountSelects();
    await loadBalancesSummary();
  } catch (err) {
    console.error('Error cargando cuentas:', err);
  }
}

async function loadBalancesSummary() {
  try {
    const res = await apiRequest('/accounts/summary/balances');
    const summaries = res.data.summary || [];
    const dop = summaries.find((s) => s.moneda === 'DOP');

    const totalBalance = dop ? dop.total_saldo : 0;
    const count = dop ? dop.cantidad_cuentas : state.accounts.length;

    document.getElementById('metric-total-balance').textContent = formatRD(totalBalance);
    document.getElementById('metric-active-accounts-count').textContent = `${count} cuenta(s) activa(s)`;
  } catch (err) {
    console.error('Error cargando resumen patrimonial:', err);
  }
}

function renderAccountsList() {
  const container = document.getElementById('accounts-list-container');
  if (!container) return;

  if (state.accounts.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1; text-align: center; padding: 2rem; background: rgba(18,24,38,0.5); border-radius: 14px; border: 1px dashed var(--border-color);">
        <span class="material-symbols-outlined" style="font-size: 2.5rem; color: var(--text-muted); margin-bottom: 0.5rem;">account_balance</span>
        <p style="font-weight: 600;">No tienes cuentas registradas aún.</p>
        <small class="text-muted">Presiona "+ Nueva Cuenta" o el acceso de demo para iniciar.</small>
      </div>
    `;
    return;
  }

  container.innerHTML = state.accounts
    .map((acc) => {
      const typeClass = `type-${acc.tipo}`;
      const typeLabel = acc.tipo === 'bancaria' ? 'Cuenta Bancaria' : acc.tipo === 'efectivo' ? 'Efectivo' : 'Tarjeta';
      const icon = acc.tipo === 'bancaria' ? 'account_balance' : acc.tipo === 'efectivo' ? 'payments' : 'credit_card';

      return `
        <div class="account-card" data-id="${acc.id}">
          <div class="account-card-top">
            <span class="account-type-badge ${typeClass}">${typeLabel}</span>
            <span class="material-symbols-outlined" style="color: var(--text-muted); font-size: 1.25rem;">${icon}</span>
          </div>
          <div class="account-name">${acc.nombre}</div>
          <div class="account-balance">${formatRD(acc.saldo_actual !== undefined ? acc.saldo_actual : acc.saldo_inicial)}</div>
          <div class="account-initial">Saldo Inicial: ${formatRD(acc.saldo_inicial)}</div>
        </div>
      `;
    })
    .join('');
}

function populateAccountSelects() {
  const selectTrx = document.getElementById('quick-trx-account');
  const selectFrom = document.getElementById('transfer-account-from');
  const selectTo = document.getElementById('transfer-account-to');
  const selectFilter = document.getElementById('filter-account');

  const optionsHtml = state.accounts
    .map((acc) => `<option value="${acc.id}">${acc.nombre} (${formatRD(acc.saldo_actual)})</option>`)
    .join('');

  if (selectTrx) {
    selectTrx.innerHTML = '<option value="" disabled selected>Selecciona una cuenta</option>' + optionsHtml;
  }
  if (selectFrom) {
    selectFrom.innerHTML = '<option value="" disabled selected>Cuenta origen</option>' + optionsHtml;
  }
  if (selectTo) {
    selectTo.innerHTML = '<option value="" disabled selected>Cuenta destino</option>' + optionsHtml;
  }
  if (selectFilter) {
    selectFilter.innerHTML = '<option value="">Todas las cuentas</option>' + optionsHtml;
  }
}

// ============================================================================
// 4. Categorías y Transacciones (Módulo TRX)
// ============================================================================

async function loadCategories() {
  try {
    const res = await apiRequest('/categories');
    state.categories = res.data.categories || [];
    populateCategorySelect();
  } catch (err) {
    console.error('Error cargando categorías:', err);
  }
}

function populateCategorySelect(tipo = 'gasto') {
  const select = document.getElementById('quick-trx-category');
  if (!select) return;

  const filtered = state.categories.filter((c) => !c.tipo || c.tipo === tipo);
  select.innerHTML =
    '<option value="" selected>Sin categoría (Opcional)</option>' +
    filtered.map((cat) => `<option value="${cat.id}">${cat.nombre}</option>`).join('');
}

async function loadTransactions() {
  const tbody = document.getElementById('transactions-tbody');
  if (!tbody) return;

  try {
    const search = document.getElementById('filter-search')?.value || '';
    const type = document.getElementById('filter-type')?.value || '';
    const accountId = document.getElementById('filter-account')?.value || '';

    const params = new URLSearchParams();
    if (search) params.append('busqueda', search);
    if (type) params.append('tipo', type);
    if (accountId) params.append('cuenta_id', accountId);

    const res = await apiRequest(`/transactions?${params.toString()}`);
    state.transactions = res.data.transactions || [];
    renderTransactionsTable();
    await loadMonthlySummary();
  } catch (err) {
    console.error('Error cargando transacciones:', err);
    tbody.innerHTML = `<tr><td colspan="7" class="text-center py-4 text-muted">Error al cargar transacciones</td></tr>`;
  }
}

function renderTransactionsTable() {
  const tbody = document.getElementById('transactions-tbody');
  if (!tbody) return;

  if (state.transactions.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="7" class="text-center py-4 text-muted">
          No hay movimientos registrados con los filtros aplicados.
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = state.transactions
    .map((trx) => {
      const isIncome = trx.sentido === 'entrada';
      const isTransfer = trx.tipo === 'transferencia';
      const amountClass = isIncome ? 'trx-amount-in' : 'trx-amount-out';
      const prefix = isIncome ? '+' : '-';

      const account = state.accounts.find((a) => a.id === trx.cuenta_id);
      const category = state.categories.find((c) => c.id === trx.categoria_id);

      const typeBadgeClass = isTransfer
        ? 'background: rgba(99,102,241,0.15); color: #818CF8;'
        : isIncome
        ? 'background: rgba(16,185,129,0.15); color: #34D399;'
        : 'background: rgba(239,68,68,0.15); color: #F87171;';

      const typeLabel = isTransfer
        ? 'Transferencia'
        : trx.tipo.charAt(0).toUpperCase() + trx.tipo.slice(1);

      return `
        <tr>
          <td><strong>${formatDate(trx.fecha)}</strong></td>
          <td>${trx.descripcion || 'Sin descripción'}</td>
          <td>
            <span class="trx-badge" style="background: rgba(255,255,255,0.06); color: var(--text-secondary);">
              ${category ? category.nombre : 'General'}
            </span>
          </td>
          <td><small class="text-muted">${account ? account.nombre : 'Cuenta'}</small></td>
          <td>
            <span class="trx-badge" style="${typeBadgeClass}">
              ${typeLabel}
            </span>
          </td>
          <td class="text-right ${amountClass}">${prefix} ${formatRD(trx.monto)}</td>
          <td class="text-center">
            <button class="btn btn-icon-ghost btn-delete-trx" data-id="${trx.id}" title="Eliminar movimiento">
              <span class="material-symbols-outlined" style="font-size: 1.15rem; color: #EF4444;">delete</span>
            </button>
          </td>
        </tr>
      `;
    })
    .join('');

  // Enlazar botones de borrado lógico
  document.querySelectorAll('.btn-delete-trx').forEach((btn) => {
    btn.addEventListener('click', async (e) => {
      const trxId = btn.getAttribute('data-id');
      if (confirm('¿Deseas eliminar lógicamente esta transacción? Los saldos se recalcularán.')) {
        try {
          await apiRequest(`/transactions/${trxId}`, { method: 'DELETE' });
          showToast('Transacción eliminada lógicamente');
          await loadAccounts();
          await loadTransactions();
        } catch (err) {
          showToast(err.message, 'error');
        }
      }
    });
  });
}

async function loadMonthlySummary() {
  try {
    const now = new Date();
    const res = await apiRequest(`/transactions/summary/monthly?anio=${now.getFullYear()}&mes=${now.getMonth() + 1}`);
    const summary = res.data;

    document.getElementById('metric-month-income').textContent = `+ ${formatRD(summary.totalIngresos)}`;
    document.getElementById('metric-month-expense').textContent = `- ${formatRD(summary.totalGastos)}`;

    const netEl = document.getElementById('metric-month-net');
    netEl.textContent = formatRD(summary.balanceNeto);
    if (summary.balanceNeto >= 0) {
      netEl.style.color = 'var(--success)';
      document.getElementById('metric-net-badge').textContent = 'Superávit Financiero';
      document.getElementById('metric-net-badge').className = 'metric-badge badge-success';
    } else {
      netEl.style.color = 'var(--danger)';
      document.getElementById('metric-net-badge').textContent = 'Déficit Financiero';
      document.getElementById('metric-net-badge').className = 'metric-badge badge-danger';
    }
  } catch (err) {
    console.error('Error cargando resumen mensual:', err);
  }
}

async function loadDashboardData() {
  await loadCategories();
  await loadAccounts();
  await loadTransactions();
}

// ============================================================================
// 5. Demostración Rápida Automática (1-Click Evaluation)
// ============================================================================

async function triggerQuickDemo() {
  const demoEmail = 'brailin@nexofin.com';
  const demoPass = 'PasswordSegura2026!';

  showToast('Iniciando sesión demo de evaluación...', 'info');

  try {
    // 1. Intentar iniciar sesión
    let res;
    try {
      res = await apiRequest('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email: demoEmail, password: demoPass }),
      });
    } catch (e) {
      // Si no existe, registrarlo
      res = await apiRequest('/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          nombre: 'Brailin Mendez',
          email: demoEmail,
          password: demoPass,
          moneda_predeterminada: 'DOP',
        }),
      });
    }

    setSession(res.data);
    showToast('¡Sesión demo iniciada exitosamente!');

    // 2. Si no tiene cuentas creadas, poblar automáticamente datos de demostración
    const accountsRes = await apiRequest('/accounts');
    if (!accountsRes.data.accounts || accountsRes.data.accounts.length === 0) {
      showToast('Configurando cuentas de demostración iniciales...', 'info');

      // Crear cuenta 1
      const acc1 = await apiRequest('/accounts', {
        method: 'POST',
        body: JSON.stringify({
          nombre: 'Cuenta Corriente Banreservas',
          tipo: 'bancaria',
          moneda: 'DOP',
          saldo_inicial: 50000.0,
        }),
      });

      // Crear cuenta 2
      const acc2 = await apiRequest('/accounts', {
        method: 'POST',
        body: JSON.stringify({
          nombre: 'Efectivo en Billetera',
          tipo: 'efectivo',
          moneda: 'DOP',
          saldo_inicial: 5000.0,
        }),
      });

      const acc1Id = acc1.data.account.id;
      const acc2Id = acc2.data.account.id;

      // Registrar ingreso
      await apiRequest('/transactions', {
        method: 'POST',
        body: JSON.stringify({
          cuenta_id: acc1Id,
          tipo: 'ingreso',
          monto: 35000.0,
          fecha: new Date().toISOString().split('T')[0],
          descripcion: 'Nómina Quincenal ITLA',
          categoria_id: 'a0000000-0000-4000-8000-000000000001',
        }),
      });

      // Registrar gasto
      await apiRequest('/transactions', {
        method: 'POST',
        body: JSON.stringify({
          cuenta_id: acc2Id,
          tipo: 'gasto',
          monto: 1450.0,
          fecha: new Date().toISOString().split('T')[0],
          descripcion: 'Almuerzo y Cafetería',
          categoria_id: 'b0000000-0000-4000-8000-000000000002',
        }),
      });

      // Transferencia
      await apiRequest('/transactions/transfer', {
        method: 'POST',
        body: JSON.stringify({
          cuenta_origen_id: acc1Id,
          cuenta_destino_id: acc2Id,
          monto: 3000.0,
          fecha: new Date().toISOString().split('T')[0],
          descripcion: 'Retiro en Cajero Automático',
        }),
      });
    }

    await loadDashboardData();
  } catch (err) {
    showToast('Error en el acceso demo: ' + err.message, 'error');
  }
}

// ============================================================================
// 6. Listeners y Eventos del DOM
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
  // Verificación de conectividad en vivo
  checkDatabaseHealth();
  setInterval(checkDatabaseHealth, 15000);

  // Inicializar fecha de hoy por defecto
  const todayStr = new Date().toISOString().split('T')[0];
  const dateInput = document.getElementById('quick-trx-date');
  const transferDateInput = document.getElementById('transfer-date');
  if (dateInput) dateInput.value = todayStr;
  if (transferDateInput) transferDateInput.value = todayStr;

  // Botón Demo Rápido
  document.getElementById('btn-quick-demo')?.addEventListener('click', triggerQuickDemo);

  // Logout
  document.getElementById('btn-logout')?.addEventListener('click', logout);

  // Pestañas de Auth (Login / Registro)
  const tabLogin = document.getElementById('tab-btn-login');
  const tabRegister = document.getElementById('tab-btn-register');
  const formLogin = document.getElementById('form-login');
  const formRegister = document.getElementById('form-register');

  tabLogin?.addEventListener('click', () => {
    tabLogin.classList.add('active');
    tabRegister.classList.remove('active');
    formLogin.classList.remove('hidden');
    formRegister.classList.add('hidden');
  });

  tabRegister?.addEventListener('click', () => {
    tabRegister.classList.add('active');
    tabLogin.classList.remove('active');
    formRegister.classList.remove('hidden');
    formLogin.classList.add('hidden');
  });

  // Envío: Formulario Login
  formLogin?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;

    try {
      const res = await apiRequest('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      setSession(res.data);
      showToast('¡Bienvenido de nuevo a NexoFin!');
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Envío: Formulario Registro
  formRegister?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const nombre = document.getElementById('register-name').value;
    const email = document.getElementById('register-email').value;
    const password = document.getElementById('register-password').value;
    const moneda = document.getElementById('register-currency').value;

    try {
      const res = await apiRequest('/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          nombre,
          email,
          password,
          moneda_predeterminada: moneda,
        }),
      });
      setSession(res.data);
      showToast('¡Cuenta creada exitosamente en NexoFin!');
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Pestañas de Operaciones Rápidas (Movimiento vs Transferencia)
  const tabTrx = document.getElementById('tab-switch-trx');
  const tabTransfer = document.getElementById('tab-switch-transfer');
  const formQuickTrx = document.getElementById('form-quick-transaction');
  const formQuickTransfer = document.getElementById('form-quick-transfer');

  tabTrx?.addEventListener('click', () => {
    tabTrx.classList.add('active');
    tabTransfer.classList.remove('active');
    formQuickTrx.classList.remove('hidden');
    formQuickTransfer.classList.add('hidden');
  });

  tabTransfer?.addEventListener('click', () => {
    tabTransfer.classList.add('active');
    tabTrx.classList.remove('active');
    formQuickTransfer.classList.remove('hidden');
    formQuickTrx.classList.add('hidden');
  });

  // Cambio de tipo de movimiento (actualizar categorías sugeridas)
  document.getElementById('quick-trx-type')?.addEventListener('change', (e) => {
    populateCategorySelect(e.target.value);
  });

  // Envío: Registro Rápido de Movimiento
  formQuickTrx?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const tipo = document.getElementById('quick-trx-type').value;
    const monto = parseFloat(document.getElementById('quick-trx-amount').value);
    const cuenta_id = document.getElementById('quick-trx-account').value;
    const categoria_id = document.getElementById('quick-trx-category').value || null;
    const fecha = document.getElementById('quick-trx-date').value;
    const descripcion = document.getElementById('quick-trx-desc').value;

    try {
      await apiRequest('/transactions', {
        method: 'POST',
        body: JSON.stringify({
          cuenta_id,
          categoria_id,
          tipo,
          monto,
          fecha,
          descripcion,
        }),
      });

      showToast('Movimiento registrado exitosamente');
      formQuickTrx.reset();
      document.getElementById('quick-trx-date').value = todayStr;
      await loadAccounts();
      await loadTransactions();
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Envío: Transferencia Atómica Rápida
  formQuickTransfer?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const cuenta_origen_id = document.getElementById('transfer-account-from').value;
    const cuenta_destino_id = document.getElementById('transfer-account-to').value;
    const monto = parseFloat(document.getElementById('transfer-amount').value);
    const fecha = document.getElementById('transfer-date').value;
    const descripcion = document.getElementById('transfer-desc').value;

    if (cuenta_origen_id === cuenta_destino_id) {
      showToast('La cuenta origen y destino deben ser distintas', 'error');
      return;
    }

    try {
      await apiRequest('/transactions/transfer', {
        method: 'POST',
        body: JSON.stringify({
          cuenta_origen_id,
          cuenta_destino_id,
          monto,
          fecha,
          descripcion,
        }),
      });

      showToast('Transferencia ejecutada atómicamente');
      formQuickTransfer.reset();
      document.getElementById('transfer-date').value = todayStr;
      await loadAccounts();
      await loadTransactions();
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Filtros de Historial
  document.getElementById('filter-search')?.addEventListener('input', loadTransactions);
  document.getElementById('filter-type')?.addEventListener('change', loadTransactions);
  document.getElementById('filter-account')?.addEventListener('change', loadTransactions);
  document.getElementById('btn-refresh-accounts')?.addEventListener('click', () => {
    loadAccounts();
    showToast('Saldos actualizados desde la base de datos', 'info');
  });

  // Modales
  const modalAccount = document.getElementById('modal-new-account');
  document.getElementById('btn-open-account-modal')?.addEventListener('click', () => {
    modalAccount.classList.remove('hidden');
  });

  document.querySelectorAll('[data-close-modal]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const modalId = btn.getAttribute('data-close-modal');
      document.getElementById(modalId)?.classList.add('hidden');
    });
  });

  document.getElementById('acc-modal-type')?.addEventListener('change', (e) => {
    const cardFields = document.getElementById('credit-card-fields');
    if (e.target.value === 'tarjeta') {
      cardFields.classList.remove('hidden');
    } else {
      cardFields.classList.add('hidden');
    }
  });

  document.getElementById('form-create-account')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const nombre = document.getElementById('acc-modal-name').value;
    const tipo = document.getElementById('acc-modal-type').value;
    const saldo_inicial = parseFloat(document.getElementById('acc-modal-balance').value) || 0;
    const moneda = document.getElementById('acc-modal-currency').value;
    const limite = parseFloat(document.getElementById('acc-modal-limit')?.value) || null;

    try {
      await apiRequest('/accounts', {
        method: 'POST',
        body: JSON.stringify({
          nombre,
          tipo,
          saldo_inicial,
          moneda,
          limite_credito: limite,
        }),
      });

      showToast('Cuenta financiera creada exitosamente');
      modalAccount.classList.add('hidden');
      document.getElementById('form-create-account').reset();
      await loadAccounts();
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Iniciar estado
  updateUIForAuthState();
});
