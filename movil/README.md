# NexoFin AI — Cliente Móvil Android (Flutter) 📱🇩🇴

Aplicación móvil de finanzas personales desarrollada en **Flutter (Dart) con Material 3**, optimizada para dispositivos Android y totalmente integrada con la **API REST de NexoFin AI**.

Cumple con las especificaciones de diseño y requerimientos del [Documento de Diseño del Sistema](../docs/NexoFin_AI_Documento_de_Diseno.md) y la [Especificación de Requisitos de Software (SRS v2.0)](../docs/NexoFin_AI_SRS_v2.0.md) para el **ITLA (Programación III)**.

---

## 🎨 Sistema de Diseño y Características
- **Paleta de Colores Oficial:**
  - Verde Esmeralda (`#005F49`) como color primario.
  - Índigo (`#4E45D5`) para funcionalidades del Asesor Inteligente / IA.
  - Rojo (`#EF4444`) para egresos y alertas de riesgo.
  - Ámbar (`#F59E0B`) para advertencias presupuestarias.
- **Formato Monetario Exacto:** Moneda local **RD$ #,##0.00** con precisión bancaria y cálculo determinístico derivado en tiempo real desde el motor relacional.
- **Formato de Fechas:** Estándar **DD/MM/AAAA**.
- **Tema Oscuro Premium (Material 3):** Diseñado para pantallas AMOLED/OLED y contraste WCAG AA.

---

## 📂 Arquitectura del Proyecto (`movil/lib/`)

```text
movil/lib/
├── core/
│   ├── constants/       # Endpoints predeterminados, claves y símbolos monetarios
│   ├── theme/           # Tema Material 3 esmeralda oscuro
│   └── utils/           # Formateadores monetarios (RD$) y fechas (DD/MM/AAAA)
├── models/              # Modelos tipados (UserModel, AccountModel, TransactionModel, etc.)
├── services/            # Cliente HTTP ApiService con tokens JWT y timeout
├── providers/           # Gestión de estado reactivo con Provider (Auth, Cuentas, Transacciones)
├── screens/
│   ├── auth/            # P5: Inicio de sesión (RF-AUT-03) y Registro (RF-AUT-01 >= 10 chars)
│   ├── dashboard/       # P1: Dashboard con patrimonio neto y flujo de caja mensual (CU-DAS-01)
│   ├── accounts/        # P4: Cuentas bancarias, efectivo y tarjetas (CU-CTA-01..03)
│   ├── transactions/    # P6: Historial, filtros y P2: Registro de ingresos, gastos y transferencias
│   ├── simulator/       # P3: Simulador what-if y chat interactivo con el Asesor NexoFin AI
│   └── home/            # Contenedor de navegación por pestañas (Material 3)
└── main.dart            # Punto de entrada de la aplicación
```

---

## 🚀 Instrucciones de Ejecución

### Prerrequisitos
- [Flutter SDK](https://flutter.dev/) (3.13+ o 3.47+)
- [Android SDK](https://developer.android.com/studio) (API 21+)
- Dispositivo Android físico o Emulador Android (AVD)

### 1. Iniciar el Servidor Backend NexoFin API
Antes de abrir la app móvil, asegúrate de tener el backend corriendo en el puerto 3000:
```bash
# Desde la raíz del repositorio
cd app
npm run dev
```

### 2. Ejecutar la App en Android
```bash
cd movil
flutter run
```

> **Nota para Emulador Android:**  
> En el emulador oficial de Android Studio, la app se conecta automáticamente a `http://10.0.2.2:3000/api/v1` (el alias que Android asigna al `localhost` de tu computadora).  
> Puedes cambiar o verificar la URL del servidor en cualquier momento tocando el ícono de engranaje ⚙️ en la pantalla de inicio de sesión.

---

## 🧪 Pruebas Automatizadas

Para ejecutar la suite de pruebas unitarias y de widgets de la aplicación móvil:
```bash
cd movil
flutter test
```
