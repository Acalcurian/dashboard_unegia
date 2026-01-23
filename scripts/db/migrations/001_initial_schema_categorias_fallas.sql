-- =============================================================================
-- MIGRACIÓN 001: Esquema Inicial para categorias_fallas
-- Base de datos: categorias_fallas
-- Fecha de creación: 2024
-- Descripción: Este archivo define el esquema inicial para la base de datos 
--              de categorías y tipos de fallas
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tabla: categorias
-- Descripción: Categorías principales de fallas (eléctrico, plomería, etc.)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL UNIQUE,
    descripcion TEXT,
    icono VARCHAR(100),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_categorias_nombre ON categorias(nombre);
CREATE INDEX IF NOT EXISTS idx_categorias_activo ON categorias(activo);

-- Datos iniciales de categorías
-- INSERT INTO categorias (nombre, descripcion) VALUES 
--     ('Eléctrico', 'Fallas relacionadas con sistema eléctrico'),
--     ('Plomería', 'Fallas en sistemas de agua y desagüe'),
--     ('Refrigeración', 'Problemas con sistemas de aire acondicionado'),
--     ('Seguridad', 'Problemas relacionados con seguridad física'),
--     ('Infraestructura', 'Fallas en estructura de edificios'),
--     ('Mobiliario', 'Daños en muebles y equipamiento'),
--     ('Suministros', 'Falta de suministros esenciales'),
--     ('Tecnología', 'Problemas con equipos tecnológicos')
-- ON CONFLICT (nombre) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Tabla: tipos_fallas
-- Descripción: Tipos específicos de fallas dentro de cada categoría
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tipos_fallas (
    id SERIAL PRIMARY KEY,
    categoria_id INTEGER REFERENCES categorias(id) ON DELETE CASCADE,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    prioridad INTEGER DEFAULT 1,
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_tipo_por_categoria UNIQUE (categoria_id, nombre)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_tipos_fallas_categoria ON tipos_fallas(categoria_id);
CREATE INDEX IF NOT EXISTS idx_tipos_fallas_activo ON tipos_fallas(activo);
CREATE INDEX IF NOT EXISTS idx_tipos_fallas_prioridad ON tipos_fallas(prioridad);

-- -----------------------------------------------------------------------------
-- EJEMPLO: Agregar tabla de subcategorías (para futuras migraciones)
-- -----------------------------------------------------------------------------
-- CREATE TABLE IF NOT EXISTS subcategorias (
--     id SERIAL PRIMARY KEY,
--     tipo_falla_id INTEGER REFERENCES tipos_fallas(id) ON DELETE CASCADE,
--     nombre VARCHAR(255) NOT NULL,
--     descripcion TEXT,
--     fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- =============================================================================
-- FIN DE MIGRACIÓN 001
-- =============================================================================
