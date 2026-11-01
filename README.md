# NexoFin AI

> **Plataforma integral de gestión financiera personal, proyección determinística y asesor inteligente.**  
> Proyecto desarrollado para **Programación III** — **Instituto Tecnológico de las Américas (ITLA)**.

[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-blue.svg)](https://www.typescriptlang.org/)
[![Node.js](https://img.shields.io/badge/Node.js-20%2B-green.svg)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-5.x-lightgrey.svg)](https://expressjs.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![Tests Passing](https://img.shields.io/badge/Tests-225%20Passing-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()

---

## Datos del Proyecto e Integrantes

- **Institución:** Instituto Tecnológico de las Américas (ITLA)
- **Asignatura:** Programación III
- **Docente:** Prof. Eduandy Isabel Cruz Abreu
- **Repositorio Oficial en GitHub:** [https://github.com/bradez-rd/nexofin](https://github.com/bradez-rd/nexofin)

### Equipo de Desarrollo

| Nombre Completo | Matrícula | Rol / Contribución |
| :--- | :--- | :--- |
| **Brailin Mendez** | 2024-1281 | Arquitectura backend, capa de dominio, base de datos y API |
| **Paola Piantini** | 2025-1222 | Especificación de requisitos (SRS) y diseño de casos de uso |
| **Romel Augusto Rojas** | 2025-1022 | Modelo relacional, DER, diseño de base de datos y esquemas |
| **Luiggi Medrano Ramírez** | 2022-1095 | Prototipos de interfaz, wireframes y flujos de usuario |

---

## Resumen del Sistema

**NexoFin AI** centraliza las finanzas personales en moneda local (**RD$**) y divisas con absoluta precisión matemática y auditoría determinística. A diferencia de las apps convencionales de finanzas, garantiza:
1. **Precisión Financiera Exacta:** Tipos monetarios en `NUMERIC(14,2)` con redondeo bancario estricto (RN-DAT-01).
2. **Saldos Siempre Consistentes:** Los saldos de cuentas y deudas nunca se almacenan como variables estáticas mutables; se derivan en tiempo real mediante vistas SQL indexadas (`vista_saldo_cuenta` y `vista_saldo_deuda`), eliminando discrepancias de balance (RNF-CON-05).
3. **Operaciones Atómicas:** Transferencias entre cuentas, pagos de deuda y aportes a metas se ejecutan en transacciones SQL atómicas pareadas (salida y entrada vinculadas con clave foránea).
4. **Bajas Lógicas e Historial:** Las transacciones no se borran físicamente; las modificaciones archivan el estado anterior en `transaccion_historial` (RN-DAT-04 / RF-TRX-03).

---

## Arquitectura y Estructura del Proyecto

El backend implementa un **Monolito Modular en Capas (Clean Architecture)** conforme a la Sección 1 del [Documento de Diseño del Sistema](docs/NexoFin_AI_Documento_de_Diseno.md):

```text
nexofin/
├── docker-compose.yml              # Orquestación con PostgreSQL 16 y API REST
├── package.json                    # Scripts globales del workspace
├── README.md                       # Documentación técnica de inicio y despliegue
├── docs/                           # Documentación de ingeniería de software
│   ├── NexoFin_AI_SRS_v2.0.md      # Especificación formal de requisitos
│   ├── NexoFin_AI_Documento_de_Diseno.md # Casos de uso, DER, secuencia, diagramas
│   └── images/                     # Diagramas UML y prototipos de interfaz
├── movil/                          # Aplicación móvil Android en Flutter (Dart + Material 3)
│   ├── lib/                        # Código fuente (core, models, providers, screens, services)
│   ├── android/                    # Configuración nativa Android (Gradle, Manifest)
│   └── test/                       # Pruebas automatizadas de la app móvil
└── app/                            # API REST en Node.js + TypeScript
    ├── Dockerfile                  # Imagen de producción multi-etapa
    ├── package.json                # Dependencias y scripts de backend
    ├── tsconfig.json               # Configuración de compilación TypeScript
    ├── jest.config.js              # Configuración de suite de pruebas Jest
    ├── .env.example                # Plantilla de variables de entorno
    ├── db/
    │   ├── schema.sql              # Esquema DDL con 24 tablas, vistas e índices
    │   └── seeds.sql               # Categorías del sistema por defecto
    ├── src/
    │   ├── config/                 # Configuración centralizada de variables de entorno
    │   │   └── env.ts
    │   ├── domain/                 # NÚCLEO PURO: Sin dependencias de BD ni frameworks
    │   │   ├── models/             # Entidades: User, Account, Transaction, Category
    │   │   ├── errors/             # Jerarquía de errores (DomainError, NotFound, etc.)
    │   │   ├── repositories/       # Contratos / Interfaces de repositorios
    │   │   └── services/           # Calculadora financiera, huellas y redondeo
    │   ├── application/            # CASOS DE USO / SERVICIOS DE APLICACIÓN
    │   │   ├── auth/               # AuthService (registro, login, perfiles)
    │   │   ├── accounts/           # AccountService (creación, saldos, archivo)
    │   │   └── transactions/       # TransactionService (movimientos, transferencias)
    │   ├── infrastructure/         # ADAPTADORES TÉCNICOS Y BASE DE DATOS
    │   │   ├── database/           # Pool PostgreSQL 16 + fallback en memoria
    │   │   ├── repositories/       # Repositorios SQL concretos
    │   │   └── security/           # Hasher (bcrypt) y Tokens (JWT)
    │   ├── api/                    # CAPA DE CONTROLADORES Y HTTP REST
    │   │   ├── controllers/        # Controladores Express
    │   │   ├── dtos/               # Esquemas Zod de validación estricta
    │   │   ├── middlewares/        # Auth JWT, validación Zod, manejador de errores
    │   │   └── routes/             # Enrutadores agrupados en /api/v1
    │   ├── app.ts                  # Configuración de Express, CORS y middlewares
    │   └── server.ts               # Servidor HTTP con bootstrap y graceful shutdown
    └── tests/
        └── api.test.ts             # 20 pruebas de integración E2E automatizadas
```

---

## Módulos Principales Implementados

El sistema cuenta con **tres (3) módulos plenamente operativos y testeados** (superando el requisito mínimo de 2):

### 1. Módulo de Autenticación y Gestión de Usuarios (AUT)
- **Registro de usuarios (`POST /api/v1/auth/register`):** Validación de unicidad de email, formato y complejidad de contraseña (mínimo 10 caracteres conforme a **RF-AUT-01**). Hash seguro con sal (bcrypt).
- **Inicio de sesión (`POST /api/v1/auth/login`):** Validación contra ataques de enumeración (mensaje genérico **RF-AUT-03**), bloqueo automático temporal de 15 minutos tras 5 intentos fallidos consecutivos (**RN-SEG-02**) y emisión de token JWT firmado.
- **Perfil de usuario (`GET /api/v1/auth/profile` / `PUT /api/v1/auth/profile`):** Consulta y actualización de datos personales, zona horaria y moneda base (RD$).

### 2. Módulo de Gestión de Cuentas Financieras (CTA)
- **Creación de cuentas (`POST /api/v1/accounts`):** Soporta cuentas en `efectivo`, `bancaria` y `tarjeta` con saldo inicial configurable (**RF-CTA-01**).
- **Cálculo de saldos determinístico (`GET /api/v1/accounts`):** Los balances se calculan mediante la vista SQL `vista_saldo_cuenta`, reflejando:
  $$\text{Saldo Actual} = \text{Saldo Inicial} + \sum \text{Entradas} - \sum \text{Salidas}$$
- **Consolidado patrimonial (`GET /api/v1/accounts/summary/balances`):** Agrupa el patrimonio neto total del usuario desglosado por moneda (**RF-CTA-05**).
- **Archivado lógico de cuentas (`DELETE /api/v1/accounts/:id`):** Las cuentas archivadas no admiten nuevos movimientos pero preservan su historial (**RN-CTA-03**).

### 3. Módulo de Transacciones e Historial Financiero (TRX)
- **Registro de transacciones (`POST /api/v1/transactions`):** Registro de ingresos, gastos y ajustes con categorías, notas y fecha (**RF-TRX-01**).
- **Transferencias atómicas entre cuentas (`POST /api/v1/transactions/transfer`):** Transacción SQL ACID que genera un par de movimientos sincronizados (salida en origen y entrada en destino) vinculados mediante `transferencia_vinculada_id` (**RF-TRX-02**).
- **Detección de duplicados mediante huella digital:** Cálculo de hash SHA-256 basado en `cuenta + fecha + monto + descripción` para alertar posibles duplicados accidentales (**RN-TRX-01**).
- **Historial inmutable y auditoría de ediciones (`PUT /api/v1/transactions/:id`):** Al modificar una transacción, los valores previos se respaldan en `transaccion_historial` (**RF-TRX-03**).
- **Baja lógica segura (`DELETE /api/v1/transactions/:id`):** Los movimientos eliminados marcan `eliminada = TRUE` para no romper la auditoría contable (**RN-DAT-04**).
- **Resumen mensual de flujo de caja (`GET /api/v1/transactions/summary/monthly`):** Cálculo instantáneo de ingresos vs. egresos y balance neto del periodo.

### 4. Módulo de Monitoreo y Salud de Base de Datos (Health)
- **`GET /api/v1/health`:** Ejecuta un `SELECT 1` activo contra el motor relacional, reportando latencia en milisegundos, uptime y estado del motor.

### 5. Módulos completados en el Entregable 5

Además de los módulos anteriores, la API y la app móvil incluyen todos los módulos del SRS (niveles 1 a 3):

| Módulo | Qué incluye | Requisitos |
| :--- | :--- | :--- |
| **Seguridad de la cuenta** | Cierre de sesión que invalida el token, recuperar y cambiar contraseña, política de claves comunes, verificación en dos pasos (TOTP), verificación de correo opcional, descarga de datos y baja de la cuenta | RF-AUT-01 a 10 |
| **Deudas** | Calendario de cuotas (sistema francés), pagos atómicos que generan un gasto, estado y calendario de obligaciones a 60 días | RF-CTA-06 a 09 |
| **Recurrentes** | Renta, suscripciones y nómina; generación idempotente, pausa y finalización | RF-TRX-06 |
| **Categorización** | Asignación automática por reglas del usuario, correcciones previas y palabras clave; bandeja de revisión por baja confianza; categorías propias | RF-CAT-01 a 06 |
| **Presupuestos y metas** | Presupuesto mensual por categoría con alertas (umbral y 100 %), metas con aportes, monto mensual necesario y fecha estimada | RF-PRE-01 a 06 |
| **Simulador** | Gasto hipotético, ahorro para una meta y compra a cuotas, con supuestos, alternativas, historial y comparación de hasta tres escenarios | RF-SIM-01 a 08 |
| **Asistente (IA)** | Chat en español con Gemini (capa gratuita) o Claude: entiende la pregunta, pide los datos que faltan, mantiene el contexto y rechaza lo ajeno a las finanzas. Las cifras no las inventa el modelo: salen de herramientas (consultas y motor de simulación) y cada respuesta indica su origen. Solo registra movimientos con confirmación. Sin `ANTHROPIC_API_KEY` responde un motor de reglas local | RF-ASI-01 a 08 |
| **Importación** | CSV, XLSX y PDF; mapeo de columnas guardable; duplicados por huella; revisión previa; confirmación atómica; deshacer en 30 días | RF-IMP-01 a 08 |
| **Dashboard y reportes** | Balance sin transferencias, posición financiera con desglose, distribución del gasto, tendencia de 6 meses y exportación CSV/Excel/PDF | RF-DAS-01 a 05 |
| **Notificaciones y auditoría** | Avisos dentro de la app con preferencias, vencimientos con 3 días de anticipación y bitácora de auditoría de solo lectura | RF-NOT-01 a 03, RF-AUD-01/02 |

---

## Conexión con Base de Datos Operativa

El sistema cuenta con un esquema de **24 tablas relacionales**, restricciones de integridad referencial, checks y 2 vistas determinísticas definidas en [`app/db/schema.sql`](app/db/schema.sql).

### Flexibilidad de Entornos de Ejecución:
- **Modo Producción / Docker:** Conexión nativa a **PostgreSQL 16** mediante pool de conexiones `pg.Pool`.
- **Modo Evaluación Inmediata (Zero-Config):** Si el evaluador no tiene un servidor PostgreSQL levantado en su máquina local, el sistema detecta la ausencia del servicio y automáticamente inicializa el motor relacional PostgreSQL en memoria (`pg-mem`), cargando el esquema completo y semillas en milisegundos sin requerir instalaciones pesadas.

---

## Instrucciones de Instalación y Ejecución

### Prerrequisitos
- [Node.js](https://nodejs.org/) v18 o superior (v20+ recomendado)
- `npm` v9 o superior
- [Docker](https://www.docker.com/) y Docker Compose (opcional para levantar con contenedor PostgreSQL)

---

### Opción A: Ejecución Local Rápida (Recomendada)

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/bradez-rd/nexofin.git
   cd nexofin
   ```

2. **Instalar dependencias:**
   ```bash
   cd app
   npm install
   ```

3. **Configurar variables de entorno:**
   ```bash
   cp .env.example .env
   ```
   *(El archivo `.env` por defecto viene preconfigurado con fallback automático para correr al instante).*

4. **Ejecutar las pruebas unitarias e integración:**
   ```bash
   npm test
   ```

5. **Iniciar el servidor en modo desarrollo (con recarga en vivo):**
   ```bash
   npm run dev
   ```
   El servidor estará escuchando en `http://localhost:3000`.

---

### Opción B: Ejecución con Docker Compose (PostgreSQL 16)

Para ejecutar la API conectada al contenedor oficial de **PostgreSQL 16**:

```bash
docker compose up -d --build
```

Esto levantará:
- **PostgreSQL 16** en el puerto `5432` con volumen persistente y esquema inicializado.
- **NexoFin API** en el puerto `3000`.

Para detener los servicios:
```bash
docker compose down
```

---

## Ejecutar la aplicación móvil (Flutter)

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.x. Con la API corriendo en `http://localhost:3000`:

```bash
cd movil
flutter pub get
flutter run            # en un emulador Android la URL por defecto es http://10.0.2.2:3000/api/v1
```

La URL del servidor se puede cambiar desde el engranaje de la pantalla de inicio de sesión. Las herramientas
(presupuestos, metas, deudas, recurrentes, asistente, reportes, importación y seguridad) están en la pestaña **Perfil**.

### Asistente con IA (Gemini gratis o Claude)
El asistente funciona sin clave con un motor de reglas local. Para que lo respalde un modelo de lenguaje, defina **una** de estas claves
en `app/.env` y reinicie la API:

```bash
# Opción gratuita: Gemini (Google AI Studio). Clave en https://aistudio.google.com/apikey
GEMINI_API_KEY=su-clave
GEMINI_MODEL=gemini-3.6-flash      # opcional

# Opción de pago: Claude (Anthropic). Clave en https://console.anthropic.com
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_MODEL=claude-sonnet-5-5  # opcional

LLM_PROVIDER=auto                  # auto | gemini | claude | reglas
```

Con `auto` se usa Gemini si hay clave de Gemini, si no Claude, y si no el motor de reglas. El modelo solo entiende la pregunta y redacta:
las cifras salen siempre de las consultas y del motor de simulación, y registrar un movimiento exige confirmación del usuario.
El usuario debe aceptar el permiso del asistente en la app (se envían sus mensajes y los resúmenes de datos necesarios, nunca su contraseña).
Si el modelo principal está saturado o sin cuota se prueba `GEMINI_FALLBACK_MODEL`, y si el proveedor falla del todo (sin conexión,
cuota agotada) el asistente cae automáticamente al motor de reglas. La capa gratuita de Gemini tiene límites por minuto y por día; cada pregunta
usa de 1 a 3 llamadas.

### Conectar a PostgreSQL real
Por defecto, si no hay un PostgreSQL accesible la API usa `pg-mem`. Para forzar PostgreSQL real defina en `app/.env`
(la contraseña de desarrollo del proyecto es `SOYLAMEJOR`):

```bash
DATABASE_URL=postgresql://postgres:SOYLAMEJOR@localhost:5432/nexofin_db
USE_MEMORY_DB_FALLBACK=false
```

- **Con Docker:** `docker compose up -d postgres` crea la base y aplica `app/db/schema.sql` y `seeds.sql`.
- **Sin Docker (PostgreSQL instalado):** cree la base `nexofin_db` y arranque la API: aplica el esquema solo. El esquema incluye
  una migración (`ALTER TABLE ... IF NOT EXISTS`), así que también actualiza bases creadas antes del Entregable 5.
- Toda la suite de la API (147 pruebas) se ejecutó contra PostgreSQL 18 real y contra `pg-mem` con el mismo resultado.

---

## Catálogo de Endpoints de la API REST

Base URL: `http://localhost:3000/api/v1`

### Salud y Estado del Sistema
| Método | Endpoint | Descripción | Requiere Auth |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | Verificación de conexión a BD y latencia | No |
| `GET` | `/` | Metadatos y directorio de la API | No |

---

### Autenticación y Perfil (`/auth`)
| Método | Endpoint | Descripción | Requiere Auth |
| :--- | :--- | :--- | :--- |
| `POST` | `/auth/register` | Registrar nuevo usuario (clave $\ge$ 10 chars) | No |
| `POST` | `/auth/login` | Iniciar sesión y obtener token JWT | No |
| `GET` | `/auth/profile` | Obtener datos del usuario autenticado | Sí (Bearer) |
| `PUT` | `/auth/profile` | Actualizar nombre, moneda o zona horaria | Sí (Bearer) |

#### Ejemplo de Petición - Registro de Usuario:
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Brailin Mendez",
    "email": "brailin@nexofin.com",
    "password": "PasswordSegura2026!",
    "moneda_predeterminada": "DOP"
  }'
```

#### Respuesta Exitosa (201 Created):
```json
{
  "success": true,
  "message": "Usuario registrado exitosamente",
  "data": {
    "user": {
      "id": "e4f8d220-7b9e-4c7b-99f8-d4bc16b80123",
      "nombre": "Brailin Mendez",
      "email": "brailin@nexofin.com",
      "moneda_predeterminada": "DOP",
      "zona_horaria": "America/Santo_Domingo",
      "email_verificado": false,
      "dos_factores_activo": false,
      "intentos_fallidos": 0,
      "creado_en": "2026-10-26T20:30:00.000Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

---

### Cuentas Financieras (`/accounts`)
*Todos los endpoints de cuentas requieren cabecera `Authorization: Bearer <TOKEN>`.*

| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `POST` | `/accounts` | Crear cuenta (`efectivo`, `bancaria`, `tarjeta`) |
| `GET` | `/accounts` | Listar cuentas activas con saldo real derivado |
| `GET` | `/accounts/summary/balances` | Total de patrimonio neto agrupado por moneda |
| `GET` | `/accounts/:id` | Detalle de una cuenta específica |
| `PUT` | `/accounts/:id` | Editar nombre o saldo inicial |
| `DELETE` | `/accounts/:id` | Archivar cuenta lógicamente |

#### Ejemplo de Petición - Crear Cuenta:
```bash
curl -X POST http://localhost:3000/api/v1/accounts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{
    "nombre": "Cuenta Nómina Banreservas",
    "tipo": "bancaria",
    "moneda": "DOP",
    "saldo_inicial": 45000.00
  }'
```

---

### Transacciones Financieras (`/transactions`)
*Todos los endpoints de transacciones requieren cabecera `Authorization: Bearer <TOKEN>`.*

| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `POST` | `/transactions` | Registrar ingreso, gasto o ajuste |
| `POST` | `/transactions/transfer` | Registrar transferencia atómica entre cuentas |
| `GET` | `/transactions` | Listar transacciones con filtros (cuenta, fechas, tipo) |
| `GET` | `/transactions/summary/monthly` | Resumen de ingresos, gastos y balance neto mensual |
| `GET` | `/transactions/:id` | Consultar detalle de una transacción |
| `PUT` | `/transactions/:id` | Editar transacción (guarda historial previo) |
| `DELETE` | `/transactions/:id` | Baja lógica de la transacción |

#### Ejemplo de Petición - Transferencia Atómica:
```bash
curl -X POST http://localhost:3000/api/v1/transactions/transfer \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{
    "cuenta_origen_id": "ID_CUENTA_ORIGEN",
    "cuenta_destino_id": "ID_CUENTA_DESTINO",
    "monto": 3500.00,
    "fecha": "2026-10-26",
    "descripcion": "Retiro cajero para efectivo"
  }'
```

---

### Módulos del Entregable 5
*Todos requieren `Authorization: Bearer <TOKEN>`, salvo los marcados.*

| Grupo | Endpoints |
| :--- | :--- |
| **Sesión y seguridad** | `POST /auth/logout` · `POST /auth/forgot-password` y `POST /auth/reset-password` (sin token) · `POST /auth/change-password` · `POST /auth/verify-email/request` y `POST /auth/verify-email` · `POST /auth/2fa/setup`, `/2fa/enable`, `/2fa/disable` · `PUT /auth/consent-ai` · `GET /auth/export` · `DELETE /auth/account` |
| **Deudas** | `POST/GET /debts` · `GET /debts/:id` · `POST /debts/:id/payments` · `GET /debts/calendar` |
| **Recurrentes** | `POST/GET /recurring` · `PUT/DELETE /recurring/:id` · `POST /recurring/generate` |
| **Categorías** | `GET/POST /categories` · `PUT/DELETE /categories/:id` · `GET/POST /categories/rules` · `PUT/DELETE /categories/rules/:id` · `GET /categories/review` · `POST /categories/reprocess` · `POST /categories/transactions/:id` |
| **Presupuestos** | `GET/POST /budgets` · `PUT/DELETE /budgets/:id` |
| **Metas** | `GET/POST /goals` · `GET/PUT /goals/:id` · `GET/POST /goals/:id/contributions` |
| **Simulador** | `POST /simulations/expense`, `/saving`, `/installments`, `/compare` · `GET /simulations` · `GET /simulations/:id` · `POST /simulations/:id/save`, `/recalculate` · `DELETE /simulations/:id` |
| **Asistente** | `POST /assistant/messages` · `GET /assistant/conversations` · `GET /assistant/conversations/:id/messages` · `DELETE /assistant/conversations/:id` |
| **Importación** | `POST/GET /imports` · `GET /imports/:id` · `PUT /imports/:id/movements/:movementId` · `POST /imports/:id/confirm`, `/cancel`, `/revert` |
| **Reportes** | `GET /dashboard/summary`, `/position`, `/spending`, `/trend`, `/export?formato=csv\|xlsx\|pdf` |
| **Notificaciones y auditoría** | `GET /notifications` · `POST /notifications/read-all`, `/:id/read` · `GET/PUT /notifications/preferences` · `GET /audit/activity` |

---

## Pruebas Automatizadas

```bash
# API (Jest + Supertest, base de datos pg-mem)
cd app
npm test

# Aplicación móvil (flutter_test)
cd movil
flutter test
```

| Suite | Pruebas | Qué cubre |
| :--- | :---: | :--- |
| `app/tests/api.test.ts` | 20 | Salud, autenticación, cuentas y transacciones (flujo base) |
| `app/tests/unit/*` | 38 | Calculadora financiera, reglas de fecha, DTO, seguridad y limitador |
| `app/tests/integration/flujos.test.ts` | 22 | Procesos completos: transferencias, edición, borrado, saldos |
| `app/tests/integration/modulos.test.ts` | 19 | Deudas, recurrentes, presupuestos, metas, categorización, auditoría |
| `app/tests/integration/simulador_asistente.test.ts` | 25 | Simulador, asistente (motor de reglas) y seguridad de la cuenta |
| `app/tests/integration/asistente_claude.test.ts` | 8 | Asistente con Claude (cliente simulado): herramientas, confirmación, historial y respaldo |
| `app/tests/integration/asistente_gemini.test.ts` | 7 | Asistente con Gemini (cliente simulado y cliente HTTP con `fetch` interceptado) |
| `app/tests/integration/panel_importacion.test.ts` | 15 | Reportes, exportación e importación CSV/XLSX/PDF |
| `movil/test/*` | 71 | Modelos, providers, pantallas y módulos nuevos con la API simulada |

El reporte completo de pruebas (plan, resultados, incidencias y evidencias) está en el Entregable 4.

---

## Enlaces y Documentación Adicional

- [Especificación de Requisitos de Software (SRS v2.0)](docs/NexoFin_AI_SRS_v2.0.md)
- [Documento de Diseño del Sistema (Arquitectura, DER, Secuencia)](docs/NexoFin_AI_Documento_de_Diseno.md)
- [Diagramas de Arquitectura y Casos de Uso](docs/images/)
