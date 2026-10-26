# NexoFin AI

> **Plataforma integral de gestión financiera personal, proyección determinística y asesor inteligente.**  
> Proyecto desarrollado para **Programación III** — **Instituto Tecnológico de las Américas (ITLA)**.

[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-blue.svg)](https://www.typescriptlang.org/)
[![Node.js](https://img.shields.io/badge/Node.js-20%2B-green.svg)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-5.x-lightgrey.svg)](https://expressjs.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![Tests Passing](https://img.shields.io/badge/Tests-20%2F20%20Passing-brightgreen.svg)]()
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
└── backend/                        # API REST en Node.js + TypeScript
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

---

## Conexión con Base de Datos Operativa

El sistema cuenta con un esquema de **24 tablas relacionales**, restricciones de integridad referencial, checks y 2 vistas determinísticas definidas en [`backend/db/schema.sql`](backend/db/schema.sql).

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
   cd backend
   npm install
   ```

3. **Configurar variables de entorno:**
   ```bash
   cp .env.example .env
   ```
   *(El archivo `.env` por defecto viene preconfigurado con fallback automático para correr al instante).*

4. **Ejecutar las pruebas unitarias e integración (20 tests):**
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

## Pruebas Automatizadas

La suite de pruebas automatizadas en Jest cubre todos los flujos de integración, casos borde y validaciones de seguridad:

```bash
cd backend
npm test
```

### Resultados de la Suite de Pruebas:
```text
PASS tests/api.test.ts
  NexoFin AI API - Integration Tests
    1. Health & Database Connectivity
      GET /api/v1/health debería responder 200 y confirmar base de datos operativa (28 ms)
      GET / debería devolver metadatos del servicio (5 ms)
    2. Módulo de Autenticación y Usuarios (AUT)
      POST /api/v1/auth/register debería registrar un nuevo usuario con contraseña >= 10 caracteres (114 ms)
      POST /api/v1/auth/register debería rechazar contraseñas de menos de 10 caracteres (RF-AUT-01) (5 ms)
      POST /api/v1/auth/register debería rechazar correos duplicados (4 ms)
      POST /api/v1/auth/login debería permitir iniciar sesión con credenciales correctas (73 ms)
      POST /api/v1/auth/login debería rechazar credenciales incorrectas con error 401 (75 ms)
      GET /api/v1/auth/profile debería devolver el perfil del usuario autenticado (5 ms)
      GET /api/v1/auth/profile sin token debería fallar con 401 Unauthorized (3 ms)
    3. Módulo de Cuentas Financieras (CTA)
      POST /api/v1/accounts debería crear una cuenta bancaria con saldo inicial (8 ms)
      POST /api/v1/accounts debería crear una segunda cuenta de efectivo (6 ms)
      GET /api/v1/accounts debería listar todas las cuentas activas del usuario (11 ms)
      GET /api/v1/accounts/summary/balances debería consolidar los saldos totales por moneda (9 ms)
    4. Módulo de Transacciones e Historial (TRX)
      POST /api/v1/transactions debería registrar un ingreso con categoría del sistema (17 ms)
      POST /api/v1/transactions debería registrar un gasto en efectivo (14 ms)
      POST /api/v1/transactions/transfer debería transferir fondos atómicamente entre cuentas (RF-TRX-02) (25 ms)
      GET /api/v1/accounts debería verificar los saldos matemáticamente exactos tras transacciones (7 ms)
      GET /api/v1/transactions/summary/monthly debería calcular balance neto del mes (19 ms)
      PUT /api/v1/transactions/:id debería actualizar una transacción y respaldar historial (13 ms)
      DELETE /api/v1/transactions/:id debería realizar baja lógica (eliminada = true) (11 ms)

Test Suites: 1 passed, 1 total
Tests:       20 passed, 20 total
```

---

## Enlaces y Documentación Adicional

- [Especificación de Requisitos de Software (SRS v2.0)](docs/NexoFin_AI_SRS_v2.0.md)
- [Documento de Diseño del Sistema (Arquitectura, DER, Secuencia)](docs/NexoFin_AI_Documento_de_Diseno.md)
- [Diagramas de Arquitectura y Casos de Uso](docs/images/)
