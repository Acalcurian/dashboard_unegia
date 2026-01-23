-- =============================================================================
-- MIGRACIÓN 001: Esquema Inicial para sedes_uneg
-- Base de datos: sedes_uneg
-- Fecha de creación: 2024
-- Descripción: Este archivo define el esquema inicial para la base de datos 
--              de sedes de UNEG
-- =============================================================================

-- INSTRUCCIONES:
-- 1. Los archivos de migración deben nombrarse con el formato: XXX_descripcion.sql
--    donde XXX es un número secuencial de 3 dígitos (001, 002, 003, etc.)
-- 2. Las migraciones se ejecutan en orden numérico ascendente
-- 3. Cada migración debe ser idempotente cuando sea posible (usar IF NOT EXISTS)
-- 4. Incluir comentarios explicativos para cambios complejos
-- 5. Separar cada base de datos en su propio archivo de migración
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tabla: sedes
-- Descripción: Almacena información de las sedes/campus de UNEG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sedes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL UNIQUE,
    ubicacion VARCHAR(500),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para mejorar rendimiento de consultas
CREATE INDEX IF NOT EXISTS idx_sedes_nombre ON sedes(nombre);
CREATE INDEX IF NOT EXISTS idx_sedes_activo ON sedes(activo);

-- Datos iniciales de ejemplo (opcional)
-- INSERT INTO sedes (nombre, ubicacion) VALUES 
--     ('Campus Principal', 'Ciudad Bolívar'),
--     ('Campus Puerto Ordaz', 'Puerto Ordaz')
-- ON CONFLICT (nombre) DO NOTHING;

-- -----------------------------------------------------------------------------
-- EJEMPLO: Crear tabla adicional
-- -----------------------------------------------------------------------------
-- CREATE TABLE IF NOT EXISTS edificios (
--     id SERIAL PRIMARY KEY,
--     nombre VARCHAR(255) NOT NULL,
--     sede_id INTEGER REFERENCES sedes(id) ON DELETE CASCADE,
--     numero_pisos INTEGER DEFAULT 1,
--     activo BOOLEAN DEFAULT TRUE,
--     fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- -----------------------------------------------------------------------------
-- EJEMPLO: Agregar columna a tabla existente (para futuras migraciones)
-- -----------------------------------------------------------------------------
-- ALTER TABLE sedes ADD COLUMN IF NOT EXISTS codigo VARCHAR(10);

-- -----------------------------------------------------------------------------
-- EJEMPLO: Modificar tipo de columna (para futuras migraciones)
-- -----------------------------------------------------------------------------
-- ALTER TABLE sedes ALTER COLUMN ubicacion TYPE TEXT;

-- -----------------------------------------------------------------------------
-- EJEMPLO: Crear índice compuesto (para futuras migraciones)
-- -----------------------------------------------------------------------------
-- CREATE INDEX IF NOT EXISTS idx_sedes_nombre_activo ON sedes(nombre, activo);

-- =============================================================================
-- FIN DE MIGRACIÓN 001
-- =============================================================================
