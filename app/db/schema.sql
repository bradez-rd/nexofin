-- ============================================================================
-- NexoFin AI - Esquema Relacional de Base de Datos
-- Motor: PostgreSQL 16
-- Especificación: Documento de Diseño del Sistema v2.0 (Sección 6)
-- Precisión monetaria: NUMERIC(14,2)
-- Claves primarias: UUID (gen_random_uuid())
-- ============================================================================

-- Habilitar extensión criptográfica para UUIDs si es necesario
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Tabla: usuario
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    moneda_predeterminada CHAR(3) NOT NULL DEFAULT 'DOP',
    zona_horaria VARCHAR(40) NOT NULL DEFAULT 'America/Santo_Domingo',
    foto_url VARCHAR(500),
    email_verificado BOOLEAN NOT NULL DEFAULT FALSE,
    dos_factores_activo BOOLEAN NOT NULL DEFAULT FALSE,
    intentos_fallidos SMALLINT NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ,
    consentimiento_ia_en TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 2. Tabla: sesion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sesion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_uso TIMESTAMPTZ NOT NULL DEFAULT now(),
    revocada BOOLEAN NOT NULL DEFAULT FALSE
);

-- ----------------------------------------------------------------------------
-- 3. Tabla: token_verificacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS token_verificacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('verificacion','reset')),
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expira_en TIMESTAMPTZ NOT NULL,
    usado_en TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- 4. Tabla: cuenta
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cuenta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    nombre VARCHAR(80) NOT NULL,
    tipo VARCHAR(15) NOT NULL CHECK (tipo IN ('efectivo','bancaria','tarjeta')),
    moneda CHAR(3) NOT NULL DEFAULT 'DOP',
    saldo_inicial NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    limite_credito NUMERIC(14,2),
    dia_corte SMALLINT CHECK (dia_corte BETWEEN 1 AND 31),
    dia_pago SMALLINT CHECK (dia_pago BETWEEN 1 AND 31),
    archivada BOOLEAN NOT NULL DEFAULT FALSE,
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 5. Tabla: categoria
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categoria (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuario(id) ON DELETE CASCADE,
    nombre VARCHAR(60) NOT NULL,
    tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('ingreso','gasto')),
    icono VARCHAR(50),
    color VARCHAR(20),
    es_sistema BOOLEAN NOT NULL DEFAULT FALSE,
    archivada BOOLEAN NOT NULL DEFAULT FALSE
);

-- ----------------------------------------------------------------------------
-- 6. Tabla: transaccion_recurrente
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transaccion_recurrente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    cuenta_id UUID NOT NULL REFERENCES cuenta(id),
    categoria_id UUID REFERENCES categoria(id),
    tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('ingreso','gasto')),
    monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
    descripcion VARCHAR(200) NOT NULL,
    frecuencia VARCHAR(12) NOT NULL CHECK (frecuencia IN ('semanal','quincenal','mensual','anual')),
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    ultima_generada DATE,
    estado VARCHAR(12) NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','pausada','finalizada'))
);

-- ----------------------------------------------------------------------------
-- 7. Tabla: importacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS importacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    cuenta_id UUID NOT NULL REFERENCES cuenta(id),
    nombre_archivo VARCHAR(255) NOT NULL,
    tipo_archivo VARCHAR(10) NOT NULL CHECK (tipo_archivo IN ('csv','xls','xlsx','pdf')),
    estado VARCHAR(20) NOT NULL DEFAULT 'en_cola' CHECK (estado IN ('en_cola','procesando','lista_revision','fallida','confirmada','cancelada','revertida')),
    motivo_fallo VARCHAR(300),
    mapeo_columnas JSONB,
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmada_en TIMESTAMPTZ,
    eliminar_documento_en TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- 8. Tabla: transaccion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transaccion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    cuenta_id UUID NOT NULL REFERENCES cuenta(id),
    categoria_id UUID REFERENCES categoria(id),
    tipo VARCHAR(15) NOT NULL CHECK (tipo IN ('ingreso','gasto','transferencia','ajuste','aporte_meta')),
    sentido VARCHAR(7) NOT NULL CHECK (sentido IN ('entrada','salida')),
    monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
    fecha DATE NOT NULL,
    descripcion VARCHAR(200),
    nota VARCHAR(500),
    estado_categoria VARCHAR(20) NOT NULL DEFAULT 'categorizada' CHECK (estado_categoria IN ('categorizada','pendiente_revision','sin_categoria')),
    confianza NUMERIC(4,3),
    categoria_manual BOOLEAN NOT NULL DEFAULT FALSE,
    transferencia_vinculada_id UUID REFERENCES transaccion(id),
    recurrente_id UUID REFERENCES transaccion_recurrente(id),
    importacion_id UUID REFERENCES importacion(id),
    huella VARCHAR(64),
    eliminada BOOLEAN NOT NULL DEFAULT FALSE,
    eliminada_en TIMESTAMPTZ,
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 9. Tabla: transaccion_historial
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transaccion_historial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaccion_id UUID NOT NULL REFERENCES transaccion(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuario(id),
    valores_anteriores JSONB NOT NULL,
    cambiado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 10. Tabla: movimiento_importado
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS movimiento_importado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    importacion_id UUID NOT NULL REFERENCES importacion(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
    sentido VARCHAR(7) NOT NULL CHECK (sentido IN ('entrada','salida')),
    descripcion VARCHAR(300) NOT NULL,
    huella VARCHAR(64) NOT NULL,
    duplicado_potencial BOOLEAN NOT NULL DEFAULT FALSE,
    categoria_sugerida_id UUID REFERENCES categoria(id),
    confianza NUMERIC(4,3),
    decision VARCHAR(10) NOT NULL DEFAULT 'pendiente' CHECK (decision IN ('pendiente','aprobado','excluido')),
    transaccion_id UUID REFERENCES transaccion(id)
);

-- ----------------------------------------------------------------------------
-- 11. Tabla: regla_categorizacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS regla_categorizacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    categoria_id UUID NOT NULL REFERENCES categoria(id),
    texto_contiene VARCHAR(100) NOT NULL,
    prioridad SMALLINT NOT NULL DEFAULT 0,
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 12. Tabla: deuda
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS deuda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    acreedor VARCHAR(100) NOT NULL,
    monto_original NUMERIC(14,2) NOT NULL CHECK (monto_original > 0),
    tasa_anual NUMERIC(6,3) NOT NULL DEFAULT 0 CHECK (tasa_anual >= 0),
    num_cuotas SMALLINT NOT NULL CHECK (num_cuotas > 0),
    fecha_primera_cuota DATE NOT NULL,
    estado VARCHAR(10) NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','saldada')),
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 13. Tabla: cuota_deuda
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cuota_deuda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deuda_id UUID NOT NULL REFERENCES deuda(id) ON DELETE CASCADE,
    numero SMALLINT NOT NULL,
    vencimiento DATE NOT NULL,
    monto NUMERIC(14,2) NOT NULL,
    capital NUMERIC(14,2) NOT NULL,
    interes NUMERIC(14,2) NOT NULL,
    monto_pagado NUMERIC(14,2) NOT NULL DEFAULT 0,
    estado VARCHAR(10) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','parcial','pagada'))
);

-- ----------------------------------------------------------------------------
-- 14. Tabla: pago_deuda
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pago_deuda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deuda_id UUID NOT NULL REFERENCES deuda(id),
    cuenta_id UUID NOT NULL REFERENCES cuenta(id),
    transaccion_id UUID NOT NULL UNIQUE REFERENCES transaccion(id),
    monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
    fecha DATE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 15. Tabla: aplicacion_pago
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aplicacion_pago (
    pago_id UUID NOT NULL REFERENCES pago_deuda(id) ON DELETE CASCADE,
    cuota_id UUID NOT NULL REFERENCES cuota_deuda(id),
    monto_aplicado NUMERIC(14,2) NOT NULL CHECK (monto_aplicado > 0),
    PRIMARY KEY (pago_id, cuota_id)
);

-- ----------------------------------------------------------------------------
-- 16. Tabla: presupuesto
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS presupuesto (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    categoria_id UUID NOT NULL REFERENCES categoria(id),
    mes DATE NOT NULL,
    monto_limite NUMERIC(14,2) NOT NULL CHECK (monto_limite > 0),
    umbral_alerta NUMERIC(3,2) NOT NULL DEFAULT 0.80,
    UNIQUE (usuario_id, categoria_id, mes)
);

-- ----------------------------------------------------------------------------
-- 17. Tabla: meta_ahorro
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta_ahorro (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    cuenta_id UUID REFERENCES cuenta(id),
    nombre VARCHAR(100) NOT NULL,
    monto_objetivo NUMERIC(14,2) NOT NULL CHECK (monto_objetivo > 0),
    fecha_limite DATE NOT NULL,
    estado VARCHAR(10) NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','pausada','cerrada','alcanzada')),
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 18. Tabla: aporte_meta
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aporte_meta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meta_id UUID NOT NULL REFERENCES meta_ahorro(id),
    transaccion_id UUID NOT NULL UNIQUE REFERENCES transaccion(id),
    monto NUMERIC(14,2) NOT NULL CHECK (monto > 0),
    fecha DATE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 19. Tabla: simulacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS simulacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo VARCHAR(15) NOT NULL CHECK (tipo IN ('gasto','ahorro_meta','compra_cuotas')),
    parametros JSONB NOT NULL,
    datos_usados JSONB NOT NULL,
    resultado JSONB NOT NULL,
    concluyente BOOLEAN NOT NULL,
    guardada BOOLEAN NOT NULL DEFAULT FALSE,
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 20. Tabla: conversacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    titulo VARCHAR(120),
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 21. Tabla: mensaje
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mensaje (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversacion_id UUID NOT NULL REFERENCES conversacion(id) ON DELETE CASCADE,
    simulacion_id UUID REFERENCES simulacion(id),
    rol VARCHAR(10) NOT NULL CHECK (rol IN ('usuario','asistente')),
    contenido TEXT NOT NULL,
    tipo_contenido VARCHAR(12) CHECK (tipo_contenido IN ('calculo','estimacion','educativo')),
    detalle_calculo JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 22. Tabla: notificacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notificacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo VARCHAR(30) NOT NULL,
    mensaje VARCHAR(300) NOT NULL,
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 23. Tabla: preferencia_notificacion
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preferencia_notificacion (
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo VARCHAR(30) NOT NULL,
    canal_app BOOLEAN NOT NULL DEFAULT TRUE,
    canal_correo BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (usuario_id, tipo)
);

-- ----------------------------------------------------------------------------
-- 24. Tabla: bitacora_auditoria
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bitacora_auditoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id UUID REFERENCES usuario(id) ON DELETE SET NULL,
    accion VARCHAR(40) NOT NULL,
    resultado VARCHAR(10) NOT NULL CHECK (resultado IN ('exito','fallo')),
    detalle JSONB,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- Índices para optimización de consultas
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_transaccion_usuario_fecha ON transaccion(usuario_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_transaccion_cuenta ON transaccion(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_transaccion_categoria_fecha ON transaccion(categoria_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_transaccion_huella ON transaccion(huella);
CREATE INDEX IF NOT EXISTS idx_cuota_vencimiento ON cuota_deuda(vencimiento);
CREATE INDEX IF NOT EXISTS idx_notificacion_usuario ON notificacion(usuario_id, creada_en DESC);
CREATE INDEX IF NOT EXISTS idx_bitacora_usuario_fecha ON bitacora_auditoria(usuario_id, fecha DESC);

-- ----------------------------------------------------------------------------
-- Vistas Financieras Determinísticas (RNF-CON-05)
-- ----------------------------------------------------------------------------

-- Vista para el cálculo en tiempo real del saldo de cada cuenta
CREATE OR REPLACE VIEW vista_saldo_cuenta AS
SELECT 
    c.id AS cuenta_id,
    c.usuario_id,
    c.nombre,
    c.tipo,
    c.moneda,
    c.saldo_inicial,
    c.archivada,
    COALESCE(SUM(CASE WHEN t.sentido = 'entrada' AND t.eliminada = FALSE THEN t.monto ELSE 0 END), 0.00) AS total_entradas,
    COALESCE(SUM(CASE WHEN t.sentido = 'salida' AND t.eliminada = FALSE THEN t.monto ELSE 0 END), 0.00) AS total_salidas,
    (c.saldo_inicial 
      + COALESCE(SUM(CASE WHEN t.sentido = 'entrada' AND t.eliminada = FALSE THEN t.monto ELSE 0 END), 0.00) 
      - COALESCE(SUM(CASE WHEN t.sentido = 'salida' AND t.eliminada = FALSE THEN t.monto ELSE 0 END), 0.00)
    ) AS saldo_actual
FROM cuenta c
LEFT JOIN transaccion t ON t.cuenta_id = c.id
GROUP BY c.id, c.usuario_id, c.nombre, c.tipo, c.moneda, c.saldo_inicial, c.archivada;

-- Vista para el cálculo en tiempo real del saldo pendiente de deudas
CREATE OR REPLACE VIEW vista_saldo_deuda AS
SELECT
    d.id AS deuda_id,
    d.usuario_id,
    d.acreedor,
    d.monto_original,
    d.tasa_anual,
    d.num_cuotas,
    d.estado,
    COALESCE(SUM(cd.capital - cd.monto_pagado), 0.00) AS saldo_pendiente_capital,
    COUNT(CASE WHEN cd.estado != 'pagada' THEN 1 END) AS cuotas_restantes
FROM deuda d
LEFT JOIN cuota_deuda cd ON cd.deuda_id = d.id
GROUP BY d.id, d.usuario_id, d.acreedor, d.monto_original, d.tasa_anual, d.num_cuotas, d.estado;
