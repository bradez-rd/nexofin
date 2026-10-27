-- ============================================================================
-- NexoFin AI - Datos de Prueba (Demo)
-- SOLO para desarrollo y presentación. Todos los datos son inventados (riesgo R7).
-- Requiere haber ejecutado antes: schema.sql y seeds.sql
--
-- Usuario demo:  demo@nexofin.test  /  contraseña: Demo12345!
-- (en la tabla solo se guarda el hash bcrypt, nunca la contraseña)
--
-- Se puede ejecutar varias veces sin duplicar nada: cada INSERT usa un id
-- fijo con ON CONFLICT (id) DO NOTHING, igual que seeds.sql.
-- Todos los ids de este archivo empiezan por "de" (de "demo").
--
-- Resultado esperado (para comprobar que todo cuadra):
--   Banco Popular = 25,000 + 45,000 - 4,500 - 5,000 - 2,000 - 3,000 = 55,500.00
--   Efectivo      =  3,000 -  2,000 + 5,000                         =  6,000.00
--   Deuda         = 12,000 - 2,000 (cuota 1 pagada)                  = 10,000.00
-- ============================================================================

SET client_encoding = 'UTF8';   -- para que tildes y ñ se lean bien en Windows

BEGIN;  -- todo o nada: si una línea falla, no se guarda ninguna

-- ---------------------------------------------------------------------------
-- Usuario
-- ---------------------------------------------------------------------------
INSERT INTO usuario (id, nombre, email, password_hash, consentimiento_ia_en)
VALUES ('de000000-0000-4000-8000-000000000001', 'Usuario Demo', 'demo@nexofin.test',
        '$2b$10$FAooFdlrp7hjftvSSQMxFuc8ModeOeyXMyWHhK2T6Ni1cwGg7Dr/q', now())
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Cuentas
-- ---------------------------------------------------------------------------
INSERT INTO cuenta (id, usuario_id, nombre, tipo, saldo_inicial) VALUES
    ('de000000-0000-4000-8000-0000000000a1', 'de000000-0000-4000-8000-000000000001', 'Banco Popular', 'bancaria', 25000.00),
    ('de000000-0000-4000-8000-0000000000a2', 'de000000-0000-4000-8000-000000000001', 'Efectivo',      'efectivo',  3000.00)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Recurrente: nómina mensual (categoría "Salario / Nómina" de seeds.sql)
-- ---------------------------------------------------------------------------
INSERT INTO transaccion_recurrente
    (id, usuario_id, cuenta_id, categoria_id, tipo, monto, descripcion, frecuencia, fecha_inicio, ultima_generada)
VALUES ('de000000-0000-4000-8000-0000000000b1', 'de000000-0000-4000-8000-000000000001',
        'de000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-000000000001',
        'ingreso', 45000.00, 'Nómina mensual', 'mensual', '2026-10-01', '2026-10-01')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Transacciones normales
-- ---------------------------------------------------------------------------
INSERT INTO transaccion (id, usuario_id, cuenta_id, categoria_id, tipo, sentido, monto, fecha, descripcion, recurrente_id) VALUES
    -- Ingreso generado por la recurrente  -> Salario / Nómina
    ('de000000-0000-4000-8000-000000000101', 'de000000-0000-4000-8000-000000000001', 'de000000-0000-4000-8000-0000000000a1',
     'a0000000-0000-4000-8000-000000000001', 'ingreso', 'entrada', 45000.00, '2026-10-01', 'Nómina mensual',
     'de000000-0000-4000-8000-0000000000b1'),
    -- Súper -> Alimentación y Supermercado
    ('de000000-0000-4000-8000-000000000102', 'de000000-0000-4000-8000-000000000001', 'de000000-0000-4000-8000-0000000000a1',
     'b0000000-0000-4000-8000-000000000002', 'gasto', 'salida', 4500.00, '2026-10-05', 'Supermercado Nacional', NULL),
    -- Gasolina en efectivo -> Transporte y Combustible
    ('de000000-0000-4000-8000-000000000103', 'de000000-0000-4000-8000-000000000001', 'de000000-0000-4000-8000-0000000000a2',
     'b0000000-0000-4000-8000-000000000003', 'gasto', 'salida', 2000.00, '2026-10-08', 'Gasolina', NULL)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Transferencia Banco -> Efectivo (RD$5,000)
-- Dos filas (salida y entrada) que se apuntan entre sí. Sin categoría.
-- ---------------------------------------------------------------------------
INSERT INTO transaccion (id, usuario_id, cuenta_id, tipo, sentido, monto, fecha, descripcion) VALUES
    ('de000000-0000-4000-8000-0000000000c1', 'de000000-0000-4000-8000-000000000001', 'de000000-0000-4000-8000-0000000000a1',
     'transferencia', 'salida',  5000.00, '2026-10-10', 'Retiro para efectivo'),
    ('de000000-0000-4000-8000-0000000000c2', 'de000000-0000-4000-8000-000000000001', 'de000000-0000-4000-8000-0000000000a2',
     'transferencia', 'entrada', 5000.00, '2026-10-10', 'Retiro para efectivo')
ON CONFLICT (id) DO NOTHING;

UPDATE transaccion SET transferencia_vinculada_id = 'de000000-0000-4000-8000-0000000000c2'
 WHERE id = 'de000000-0000-4000-8000-0000000000c1';
UPDATE transaccion SET transferencia_vinculada_id = 'de000000-0000-4000-8000-0000000000c1'
 WHERE id = 'de000000-0000-4000-8000-0000000000c2';

-- ---------------------------------------------------------------------------
-- Deuda: préstamo de RD$12,000 en 6 cuotas, sin interés
-- Con tasa 0, cuota = P ÷ n = 12,000 ÷ 6 = 2,000 (RN-DEU-01)
-- ---------------------------------------------------------------------------
INSERT INTO deuda (id, usuario_id, acreedor, monto_original, tasa_anual, num_cuotas, fecha_primera_cuota)
VALUES ('de000000-0000-4000-8000-0000000000d1', 'de000000-0000-4000-8000-000000000001',
        'Préstamo familiar', 12000.00, 0, 6, '2026-10-15')
ON CONFLICT (id) DO NOTHING;

-- Las 6 cuotas, una por mes. generate_series(1, 6) produce los números 1..6.
-- El id de cada cuota termina en su número (...d101, ...d102, ...).
INSERT INTO cuota_deuda (id, deuda_id, numero, vencimiento, monto, capital, interes)
SELECT ('de000000-0000-4000-8000-0000000d' || lpad(n::text, 4, '0'))::uuid,
       'de000000-0000-4000-8000-0000000000d1',
       n,
       DATE '2026-10-15' + (n - 1) * INTERVAL '1 month',
       2000.00, 2000.00, 0
FROM generate_series(1, 6) AS n
ON CONFLICT (id) DO NOTHING;

-- Pago de la cuota 1: gasto + pago + aplicación a la cuota (RF-CTA-07)
-- -> categoría "Pago de Deuda y Préstamos"
INSERT INTO transaccion (id, usuario_id, cuenta_id, categoria_id, tipo, sentido, monto, fecha, descripcion)
VALUES ('de000000-0000-4000-8000-0000000000e1', 'de000000-0000-4000-8000-000000000001',
        'de000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-000000000009',
        'gasto', 'salida', 2000.00, '2026-10-15', 'Cuota 1 préstamo familiar')
ON CONFLICT (id) DO NOTHING;

INSERT INTO pago_deuda (id, deuda_id, cuenta_id, transaccion_id, monto, fecha)
VALUES ('de000000-0000-4000-8000-0000000000e2', 'de000000-0000-4000-8000-0000000000d1',
        'de000000-0000-4000-8000-0000000000a1', 'de000000-0000-4000-8000-0000000000e1', 2000.00, '2026-10-15')
ON CONFLICT (id) DO NOTHING;

INSERT INTO aplicacion_pago (pago_id, cuota_id, monto_aplicado)
VALUES ('de000000-0000-4000-8000-0000000000e2', 'de000000-0000-4000-8000-0000000d0001', 2000.00)
ON CONFLICT (pago_id, cuota_id) DO NOTHING;

UPDATE cuota_deuda SET monto_pagado = 2000.00, estado = 'pagada'
 WHERE id = 'de000000-0000-4000-8000-0000000d0001';

-- ---------------------------------------------------------------------------
-- Presupuesto de octubre para "Alimentación y Supermercado"
-- (mes siempre es el día 1; la tabla ya impide repetir usuario+categoría+mes)
-- ---------------------------------------------------------------------------
INSERT INTO presupuesto (id, usuario_id, categoria_id, mes, monto_limite)
VALUES ('de000000-0000-4000-8000-0000000000f0', 'de000000-0000-4000-8000-000000000001',
        'b0000000-0000-4000-8000-000000000002', '2026-10-01', 10000.00)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Meta de ahorro con un aporte
-- El aporte es tipo 'aporte_meta': saca dinero del banco pero NO es un gasto
-- (no cuenta en presupuestos ni balances, RN-MET-03).
-- ---------------------------------------------------------------------------
INSERT INTO meta_ahorro (id, usuario_id, cuenta_id, nombre, monto_objetivo, fecha_limite)
VALUES ('de000000-0000-4000-8000-0000000000f1', 'de000000-0000-4000-8000-000000000001',
        'de000000-0000-4000-8000-0000000000a1', 'Laptop nueva', 60000.00, '2026-12-31')
ON CONFLICT (id) DO NOTHING;

INSERT INTO transaccion (id, usuario_id, cuenta_id, tipo, sentido, monto, fecha, descripcion)
VALUES ('de000000-0000-4000-8000-0000000000f2', 'de000000-0000-4000-8000-000000000001',
        'de000000-0000-4000-8000-0000000000a1', 'aporte_meta', 'salida', 3000.00, '2026-10-20', 'Aporte laptop')
ON CONFLICT (id) DO NOTHING;

INSERT INTO aporte_meta (id, meta_id, transaccion_id, monto, fecha)
VALUES ('de000000-0000-4000-8000-0000000000f3', 'de000000-0000-4000-8000-0000000000f1',
        'de000000-0000-4000-8000-0000000000f2', 3000.00, '2026-10-20')
ON CONFLICT (id) DO NOTHING;

COMMIT;
