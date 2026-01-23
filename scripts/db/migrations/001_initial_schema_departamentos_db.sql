-- =============================================================================
-- MIGRACIÓN 001: Esquema Inicial para departamentos_db
-- Base de datos: departamentos_db
-- Fecha de creación: 2024
-- Descripción: Este archivo define el esquema inicial para la base de datos 
--              de departamentos y personal de UNEG
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tabla: departamentos
-- Descripción: Departamentos y unidades organizacionales de UNEG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departamentos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL UNIQUE,
    codigo VARCHAR(50),
    descripcion TEXT,
    departamento_padre_id INTEGER REFERENCES departamentos(id) ON DELETE SET NULL,
    responsable VARCHAR(255),
    email VARCHAR(255),
    telefono VARCHAR(50),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_departamentos_nombre ON departamentos(nombre);
CREATE INDEX IF NOT EXISTS idx_departamentos_codigo ON departamentos(codigo);
CREATE INDEX IF NOT EXISTS idx_departamentos_activo ON departamentos(activo);
CREATE INDEX IF NOT EXISTS idx_departamentos_padre ON departamentos(departamento_padre_id);

-- -----------------------------------------------------------------------------
-- Tabla: personal
-- Descripción: Personal asociado a cada departamento
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS personal (
    id SERIAL PRIMARY KEY,
    cedula VARCHAR(20) NOT NULL UNIQUE,
    nombres VARCHAR(255) NOT NULL,
    apellidos VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    telefono VARCHAR(50),
    departamento_id INTEGER REFERENCES departamentos(id) ON DELETE SET NULL,
    cargo VARCHAR(255),
    activo BOOLEAN DEFAULT TRUE,
    fecha_ingreso DATE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_personal_cedula ON personal(cedula);
CREATE INDEX IF NOT EXISTS idx_personal_departamento ON personal(departamento_id);
CREATE INDEX IF NOT EXISTS idx_personal_activo ON personal(activo);
CREATE INDEX IF NOT EXISTS idx_personal_nombres ON personal(nombres);
CREATE INDEX IF NOT EXISTS idx_personal_apellidos ON personal(apellidos);

-- -----------------------------------------------------------------------------
-- Tabla: asignaciones_reportes
-- Descripción: Relación entre personal y reportes asignados
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS asignaciones_reportes (
    id SERIAL PRIMARY KEY,
    personal_id INTEGER REFERENCES personal(id) ON DELETE CASCADE,
    reporte_id INTEGER,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_completado TIMESTAMP,
    estado VARCHAR(50) DEFAULT 'asignado',
    notas TEXT,
    CONSTRAINT unique_asignacion UNIQUE (personal_id, reporte_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_asignaciones_personal ON asignaciones_reportes(personal_id);
CREATE INDEX IF NOT EXISTS idx_asignaciones_reporte ON asignaciones_reportes(reporte_id);
CREATE INDEX IF NOT EXISTS idx_asignaciones_estado ON asignaciones_reportes(estado);
CREATE INDEX IF NOT EXISTS idx_asignaciones_fecha ON asignaciones_reportes(fecha_asignacion DESC);

-- -----------------------------------------------------------------------------
-- EJEMPLO: Vista jerárquica de departamentos
-- -----------------------------------------------------------------------------
-- CREATE OR REPLACE VIEW vista_departamentos_jerarquia AS
-- WITH RECURSIVE jerarquia AS (
--     SELECT id, nombre, codigo, departamento_padre_id, 1 AS nivel
--     FROM departamentos
--     WHERE departamento_padre_id IS NULL
--     UNION ALL
--     SELECT d.id, d.nombre, d.codigo, d.departamento_padre_id, j.nivel + 1
--     FROM departamentos d
--     INNER JOIN jerarquia j ON d.departamento_padre_id = j.id
-- )
-- SELECT * FROM jerarquia ORDER BY nivel, nombre;

-- =============================================================================
-- FIN DE MIGRACIÓN 001
-- =============================================================================
