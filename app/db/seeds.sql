-- ============================================================================
-- NexoFin AI - Semillas de Datos Iniciales (Seeds)
-- Categorías globales del sistema (usuario_id = NULL, es_sistema = TRUE)
-- ============================================================================

INSERT INTO categoria (id, usuario_id, nombre, tipo, icono, color, es_sistema, archivada)
VALUES
    -- Categorías de Ingreso del Sistema
    ('a0000000-0000-4000-8000-000000000001', NULL, 'Salario / Nómina', 'ingreso', 'payments', '#10B981', TRUE, FALSE),
    ('a0000000-0000-4000-8000-000000000002', NULL, 'Inversiones y Dividendos', 'ingreso', 'trending_up', '#059669', TRUE, FALSE),
    ('a0000000-0000-4000-8000-000000000003', NULL, 'Ventas y Negocio Propio', 'ingreso', 'store', '#34D399', TRUE, FALSE),
    ('a0000000-0000-4000-8000-000000000004', NULL, 'Transferencias Recibidas', 'ingreso', 'swap_horiz', '#6EE7B7', TRUE, FALSE),
    ('a0000000-0000-4000-8000-000000000005', NULL, 'Otros Ingresos', 'ingreso', 'add_circle', '#A7F3D0', TRUE, FALSE),

    -- Categorías de Gasto del Sistema
    ('b0000000-0000-4000-8000-000000000001', NULL, 'Vivienda y Renta', 'gasto', 'home', '#EF4444', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000002', NULL, 'Alimentación y Supermercado', 'gasto', 'shopping_cart', '#F97316', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000003', NULL, 'Transporte y Combustible', 'gasto', 'directions_car', '#F59E0B', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000004', NULL, 'Servicios Públicos (Luz, Agua, Teléfono)', 'gasto', 'flash_on', '#84CC16', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000005', NULL, 'Salud y Farmacia', 'gasto', 'medical_services', '#06B6D4', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000006', NULL, 'Educación y Capacitación', 'gasto', 'school', '#3B82F6', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000007', NULL, 'Entretenimiento y Salidas', 'gasto', 'movie', '#8B5CF6', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000008', NULL, 'Ropa y Cuidado Personal', 'gasto', 'checkroom', '#EC4899', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000009', NULL, 'Pago de Deuda y Préstamos', 'gasto', 'credit_card', '#DC2626', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000010', NULL, 'Aporte a Meta de Ahorro', 'gasto', 'savings', '#047857', TRUE, FALSE),
    ('b0000000-0000-4000-8000-000000000011', NULL, 'Otros Gastos', 'gasto', 'receipt_long', '#6B7280', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;
