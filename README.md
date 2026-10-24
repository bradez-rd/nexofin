# NexoFin AI 

**NexoFin AI** es una plataforma integral de gestión financiera personal, proyección de ahorros, control de presupuestos y simulación inteligente de escenarios financieros, asistida por IA.

---

## Resumen Rápido

NexoFin AI permite a los usuarios centralizar sus finanzas personales de forma determinística y segura, ofreciendo:
- **Gestión de Cuentas y Deudas:** Seguimiento de cuentas bancarias, tarjetas de crédito, préstamos y amortizaciones.
- **Control de Transacciones y Presupuestos:** Registro manual y categorización inteligente de ingresos y egresos, junto a metas de ahorro con límites automáticos.
- **Motor de Simulación Financiera:** Proyección de saldo libre, cálculo de capacidad de endeudamiento e impacto de decisiones económicas futuras.
- **Asistente Financiero Inteligente:** Consultas en lenguaje natural apoyadas por un motor financiero que garantiza precisión monetaria en moneda local (RD$).
- **Dashboard y Analítica:** Indicadores visuales de salud financiera, desglose de gastos y métricas de progreso.

---

## Stack Tecnológico Principal

- **Frontend:** [Flutter](https://flutter.dev/) (Dart)
  - Cliente multiplataforma (Móvil y Web) con interfaz moderna basada en **Material 3**.
  - Manejo de estado escalable y consumo de API REST.
- **Base de Datos:** [PostgreSQL](https://www.postgresql.org/)
  - Base de datos relacional robusta con soporte para transacciones ACID.
  - Precisión monetaria exacta mediante tipos `NUMERIC(14,2)` y vistas dinámicas para el cálculo en tiempo real de saldos.
- **Backend / API:** API REST modular sin estado con autenticación segura por JWT.

---

## Documentación del Proyecto

Los detalles completos de requisitos y arquitectura se encuentran en la carpeta [docs/](file:///c:/Users/Administrator/Desktop/nexofin/docs):
- [Especificación de Requisitos de Software (SRS v2.0)](file:///c:/Users/Administrator/Desktop/nexofin/docs/NexoFin_AI_SRS_v2.0.md)
- [Documento de Diseño del Sistema](file:///c:/Users/Administrator/Desktop/nexofin/docs/NexoFin_AI_Documento_de_Diseno.md)
- [Diagramas y Recursos Visuales](file:///c:/Users/Administrator/Desktop/nexofin/docs/images)
