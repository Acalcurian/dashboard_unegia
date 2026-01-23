-- =============================================================================
-- MIGRACIÓN 001: Esquema Inicial para reportes_generales
-- Base de datos: reportes_generales
-- Fecha de creación: 2024
-- Descripción: Este archivo define el esquema inicial para la base de datos 
--              de reportes generales del sistema
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tabla: reportes
-- Descripción: Almacena todos los reportes de fallas del sistema
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reportes (
    id SERIAL PRIMARY KEY,
    cedula VARCHAR(20),
    categoria INTEGER,
    tipo_falla INTEGER,
    fallas_otros TEXT,
    sede INTEGER,
    foto_path VARCHAR(255),
    descripcion TEXT,
    lat_foto DECIMAL(10, 8),
    lon_foto DECIMAL(11, 8),
    fecha_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(50) DEFAULT 'pendiente',
    prioridad INTEGER DEFAULT 1,
    asignado_a VARCHAR(100),
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_resolucion TIMESTAMP,
    notas_resolucion TEXT
);

-- Índices para optimizar consultas comunes
CREATE INDEX IF NOT EXISTS idx_reportes_cedula ON reportes(cedula);
CREATE INDEX IF NOT EXISTS idx_reportes_categoria ON reportes(categoria);
CREATE INDEX IF NOT EXISTS idx_reportes_tipo_falla ON reportes(tipo_falla);
CREATE INDEX IF NOT EXISTS idx_reportes_sede ON reportes(sede);
CREATE INDEX IF NOT EXISTS idx_reportes_fecha ON reportes(fecha_reporte DESC);
CREATE INDEX IF NOT EXISTS idx_reportes_estado ON reportes(estado);
CREATE INDEX IF NOT EXISTS idx_reportes_prioridad ON reportes(prioridad);

-- Índice compuesto para dashboard
CREATE INDEX IF NOT EXISTS idx_reportes_estado_fecha ON reportes(estado, fecha_reporte DESC);

-- -----------------------------------------------------------------------------
-- Tabla: historial_reportes
-- Descripción: Rastrea cambios de estado y actualizaciones de reportes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS historial_reportes (
    id SERIAL PRIMARY KEY,
    reporte_id INTEGER REFERENCES reportes(id) ON DELETE CASCADE,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    usuario VARCHAR(100),
    comentario TEXT,
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_historial_reporte ON historial_reportes(reporte_id);
CREATE INDEX IF NOT EXISTS idx_historial_fecha ON historial_reportes(fecha_cambio DESC);

-- -----------------------------------------------------------------------------
-- Tabla: notificaciones_email
-- Descripción: Registro de notificaciones enviadas por email
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notificaciones_email (
    id SERIAL PRIMARY KEY,
    reporte_id INTEGER REFERENCES reportes(id) ON DELETE CASCADE,
    email_destinatario VARCHAR(255),
    asunto VARCHAR(500),
    estado VARCHAR(50) DEFAULT 'enviado',
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    error_mensaje TEXT
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_notificaciones_reporte ON notificaciones_email(reporte_id);
CREATE INDEX IF NOT EXISTS idx_notificaciones_estado ON notificaciones_email(estado);
CREATE INDEX IF NOT EXISTS idx_notificaciones_fecha ON notificaciones_email(fecha_envio DESC);

-- -----------------------------------------------------------------------------
-- EJEMPLO: Vista para reportes con información completa
-- -----------------------------------------------------------------------------
-- CREATE OR REPLACE VIEW vista_reportes_completa AS
-- SELECT 
--     r.id,
--     r.cedula,
--     r.categoria,
--     r.tipo_falla,
--     r.sede,
--     r.descripcion,
--     r.estado,
--     r.prioridad,
--     r.fecha_reporte,
--     r.fecha_resolucion,
--     EXTRACT(EPOCH FROM (COALESCE(r.fecha_resolucion, NOW()) - r.fecha_reporte))/3600 AS horas_transcurridas
-- FROM reportes r;

-- =============================================================================
-- FIN DE MIGRACIÓN 001
-- =============================================================================
