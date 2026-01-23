# Guía de Scripts de Base de Datos - Dashboard UNEGIA

Esta guía documenta el sistema de migraciones y scripts de base de datos para el proyecto Dashboard UNEGIA.

## Tabla de Contenidos

- [Introducción](#introducción)
- [Estructura de Archivos](#estructura-de-archivos)
- [Sistema de Migraciones](#sistema-de-migraciones)
- [Scripts Disponibles](#scripts-disponibles)
- [Guía de Uso](#guía-de-uso)
- [Ejemplos Prácticos](#ejemplos-prácticos)
- [Troubleshooting](#troubleshooting)
- [Mejores Prácticas](#mejores-prácticas)

## Introducción

Este proyecto utiliza PostgreSQL con conexiones directas mediante psycopg2 (sin SQLAlchemy ORM). Por lo tanto, las migraciones de base de datos se manejan mediante scripts SQL manuales en lugar de herramientas como Flask-Migrate o Alembic.

El sistema cuenta con **4 bases de datos separadas**:
- `sedes_uneg` - Información de sedes y campus
- `categorias_fallas` - Categorías y tipos de fallas
- `reportes_generales` - Reportes y seguimiento
- `departamentos_db` - Departamentos y personal

## Estructura de Archivos

```
scripts/
├── db/
│   ├── migrations/                    # Archivos de migración SQL
│   │   ├── 001_initial_schema_sedes_uneg.sql
│   │   ├── 001_initial_schema_categorias_fallas.sql
│   │   ├── 001_initial_schema_reportes_generales.sql
│   │   └── 001_initial_schema_departamentos_db.sql
│   ├── run_migrations.sh             # Ejecutor de migraciones
│   ├── export_data.sh                # Exportador de datos
│   └── import_data.sh                # Importador de datos
└── README_SCRIPTS.md                 # Este archivo

exports/                               # Directorio generado automáticamente
└── YYYYMMDD_HHMMSS/                  # Exportaciones con timestamp
    ├── sedes_uneg.sql.gz
    ├── categorias_fallas.sql.gz
    ├── reportes_generales.sql.gz
    ├── departamentos_db.sql.gz
    └── export_metadata.txt
```

## Sistema de Migraciones

### Convenciones de Nomenclatura

Los archivos de migración siguen una convención estricta:

```
XXX_descripcion_nombre_base_de_datos.sql
```

Donde:
- `XXX` = Número secuencial de 3 dígitos (001, 002, 003, etc.)
- `descripcion` = Breve descripción del cambio (ej: initial_schema, add_user_table)
- `nombre_base_de_datos` = Nombre exacto de la base de datos

**Ejemplos válidos:**
```
001_initial_schema_sedes_uneg.sql
002_add_edificios_table_sedes_uneg.sql
003_alter_reportes_add_status_reportes_generales.sql
004_create_indices_categorias_fallas.sql
```

### Orden de Ejecución

Las migraciones se ejecutan en **orden numérico ascendente** del prefijo XXX. Es importante:

1. **Nunca modificar** archivos de migración ya ejecutados
2. **Siempre crear nuevas migraciones** para cambios adicionales
3. **Usar números consecutivos** para mantener el orden
4. **Documentar cada migración** con comentarios claros

### Idempotencia

Las migraciones deben ser idempotentes cuando sea posible, usando:

```sql
-- Crear tabla solo si no existe
CREATE TABLE IF NOT EXISTS mi_tabla (...);

-- Agregar columna solo si no existe
ALTER TABLE mi_tabla ADD COLUMN IF NOT EXISTS nueva_columna VARCHAR(100);

-- Crear índice solo si no existe
CREATE INDEX IF NOT EXISTS idx_nombre ON tabla(columna);

-- Insertar datos evitando duplicados
INSERT INTO tabla (columna) VALUES ('valor')
ON CONFLICT (columna) DO NOTHING;
```

## Scripts Disponibles

### 1. run_migrations.sh

Ejecuta archivos de migración SQL en las bases de datos.

**Características:**
- Ejecuta migraciones en orden numérico
- Soporta ejecución por base de datos específica o todas
- Modo dry-run para preview sin ejecutar
- Validación de requisitos del sistema
- Logging detallado de errores
- Resumen de éxitos/fallos

**Uso básico:**
```bash
./run_migrations.sh -d all -u postgres -P password
```

### 2. export_data.sh

Exporta datos de las bases de datos a archivos SQL.

**Características:**
- Exporta esquema y datos completos
- Compresión automática con gzip
- Opción solo datos (--data-only) o solo esquema (--schema-only)
- Genera metadatos de la exportación
- Organiza exportaciones por timestamp
- Soporta exportación selectiva por base de datos

**Uso básico:**
```bash
./export_data.sh -d all -u postgres -P password
```

### 3. import_data.sh

Importa datos desde archivos SQL a las bases de datos.

**Características:**
- Soporta archivos .sql y .sql.gz
- Opción --clean para limpiar tablas existentes
- Confirmaciones de seguridad (especialmente en producción)
- Modo --production con confirmación extra
- Validación de archivos antes de importar
- Resumen de operaciones

**Uso básico:**
```bash
./import_data.sh -d all -i ./exports/20240101_120000/ -u postgres -P password
```

## Guía de Uso

### Setup Inicial de Base de Datos

**Paso 1: Crear las bases de datos en PostgreSQL**

```bash
# Conectar a PostgreSQL
sudo -u postgres psql

# Crear las 4 bases de datos
CREATE DATABASE sedes_uneg;
CREATE DATABASE categorias_fallas;
CREATE DATABASE reportes_generales;
CREATE DATABASE departamentos_db;

# Crear usuario (si es necesario)
CREATE USER dashboard_user WITH PASSWORD 'tu_password_seguro';

# Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE sedes_uneg TO dashboard_user;
GRANT ALL PRIVILEGES ON DATABASE categorias_fallas TO dashboard_user;
GRANT ALL PRIVILEGES ON DATABASE reportes_generales TO dashboard_user;
GRANT ALL PRIVILEGES ON DATABASE departamentos_db TO dashboard_user;

# Salir
\q
```

**Paso 2: Ejecutar migraciones iniciales**

```bash
cd scripts/db

# Opción 1: Con parámetros
./run_migrations.sh -d all -H localhost -u dashboard_user -P tu_password

# Opción 2: Con variables de entorno
export DB_HOST=localhost
export DB_USER=dashboard_user
export DB_PASSWORD=tu_password
./run_migrations.sh -d all
```

**Paso 3: Verificar las tablas creadas**

```bash
# Para cada base de datos
psql -h localhost -U dashboard_user -d sedes_uneg -c "\dt"
psql -h localhost -U dashboard_user -d categorias_fallas -c "\dt"
psql -h localhost -U dashboard_user -d reportes_generales -c "\dt"
psql -h localhost -U dashboard_user -d departamentos_db -c "\dt"
```

### Crear una Nueva Migración

**Ejemplo: Agregar tabla de auditoría a reportes_generales**

1. **Crear archivo de migración:**

```bash
cd scripts/db/migrations

# Crear archivo con siguiente número secuencial
nano 002_add_auditoria_table_reportes_generales.sql
```

2. **Contenido del archivo:**

```sql
-- =============================================================================
-- MIGRACIÓN 002: Agregar tabla de auditoría
-- Base de datos: reportes_generales
-- Fecha: 2024-01-23
-- Descripción: Tabla para registrar cambios en reportes con fines de auditoría
-- =============================================================================

CREATE TABLE IF NOT EXISTS auditoria_reportes (
    id SERIAL PRIMARY KEY,
    reporte_id INTEGER,
    usuario VARCHAR(100),
    accion VARCHAR(50),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    ip_address VARCHAR(45),
    fecha_accion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_auditoria_reporte ON auditoria_reportes(reporte_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria_reportes(usuario);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria_reportes(fecha_accion DESC);

-- =============================================================================
-- FIN DE MIGRACIÓN 002
-- =============================================================================
```

3. **Ejecutar la migración:**

```bash
cd ../
./run_migrations.sh -d reportes_generales -u dashboard_user -P password
```

### Exportar Datos (Backup)

**Backup completo de todas las bases de datos:**

```bash
cd scripts/db

# Exportación completa con compresión
./export_data.sh -d all -u postgres -P password

# La exportación se guarda en: ../../exports/YYYYMMDD_HHMMSS/
```

**Backup de una base de datos específica:**

```bash
./export_data.sh -d reportes_generales -u postgres -P password
```

**Solo exportar esquema (sin datos):**

```bash
./export_data.sh -d all --schema-only -u postgres -P password
```

**Solo exportar datos (sin esquema):**

```bash
./export_data.sh -d all --data-only -u postgres -P password
```

**Exportar sin comprimir:**

```bash
./export_data.sh -d all --no-compress -u postgres -P password
```

### Importar Datos (Restore)

**Importar desde backup en servidor nuevo:**

```bash
cd scripts/db

# Ver ayuda primero
./import_data.sh --help

# Importar todas las bases de datos
./import_data.sh -d all -i ../../exports/20240123_153000/ -u postgres -P password
```

**Importar limpiando datos existentes:**

```bash
# ⚠️ PRECAUCIÓN: Esto eliminará todas las tablas existentes
./import_data.sh -d all -i ../../exports/20240123_153000/ --clean -u postgres -P password
```

**Importar en producción (con confirmación extra):**

```bash
# Requiere confirmación explícita
./import_data.sh -d all -i ../../exports/20240123_153000/ --production -u postgres -P password
```

## Ejemplos Prácticos

### Escenario 1: Migración de Desarrollo a Producción

**En servidor de desarrollo:**

```bash
# 1. Exportar datos de desarrollo
cd scripts/db
./export_data.sh -d all -u dev_user -P dev_pass -o /tmp/export_prod

# 2. Copiar archivos a servidor de producción
scp -r /tmp/export_prod usuario@servidor-prod:/home/usuario/
```

**En servidor de producción:**

```bash
# 3. Importar datos (con confirmación)
cd scripts/db
./import_data.sh -d all -i /home/usuario/export_prod --production -u prod_user -P prod_pass
```

### Escenario 2: Agregar Nueva Columna a Tabla Existente

**Crear migración:**

```bash
# Archivo: 005_add_email_to_reportes_reportes_generales.sql
```

```sql
-- =============================================================================
-- MIGRACIÓN 005: Agregar columna email a reportes
-- =============================================================================

ALTER TABLE reportes ADD COLUMN IF NOT EXISTS email_contacto VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_reportes_email ON reportes(email_contacto);

-- =============================================================================
-- FIN DE MIGRACIÓN 005
-- =============================================================================
```

**Ejecutar:**

```bash
./run_migrations.sh -d reportes_generales -u postgres -P password
```

### Escenario 3: Backup Automático Diario

**Crear cron job:**

```bash
crontab -e
```

**Agregar línea:**

```cron
# Backup diario a las 2:00 AM
0 2 * * * cd /ruta/dashboard_unegia/scripts/db && ./export_data.sh -d all -u backup_user -P backup_pass -o /backups/daily
```

### Escenario 4: Testing de Migraciones

**Usar dry-run antes de ejecutar:**

```bash
# Ver qué se ejecutaría sin hacer cambios reales
./run_migrations.sh -d all --dry-run -u postgres -P password
```

## Troubleshooting

### Error: "psql: command not found"

**Solución:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql-client

# CentOS/RHEL
sudo yum install postgresql
```

### Error: "FATAL: password authentication failed"

**Solución:**
1. Verificar usuario y contraseña en config.py
2. Verificar configuración de pg_hba.conf
3. Reiniciar PostgreSQL: `sudo systemctl restart postgresql`

### Error: "permission denied for database"

**Solución:**
```sql
-- Conectar como superusuario
sudo -u postgres psql

-- Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE nombre_db TO usuario;
```

### Error: "relation already exists"

**Causa:** Ejecutando migración que ya fue aplicada.

**Solución:**
- Usar `CREATE TABLE IF NOT EXISTS` en migraciones
- Verificar qué migraciones ya fueron ejecutadas
- No re-ejecutar migraciones viejas

### Archivos de exportación muy grandes

**Solución:**
```bash
# Usar compresión (habilitada por defecto)
./export_data.sh -d all -u postgres -P password

# Exportar solo esquema
./export_data.sh -d all --schema-only -u postgres -P password

# Exportar datos en archivos separados por tabla (manual con pg_dump)
pg_dump -h localhost -U postgres -d nombre_db -t nombre_tabla > tabla.sql
```

### Error al importar: "syntax error at or near"

**Causa:** Archivo SQL corrupto o incompatible.

**Solución:**
1. Verificar integridad del archivo
2. Verificar versión de PostgreSQL compatible
3. Re-exportar datos desde origen

## Mejores Prácticas

### Para Migraciones

1. **Nunca modificar migraciones existentes** - Siempre crear nuevas
2. **Usar transacciones** cuando sea apropiado
3. **Incluir rollback comments** para documentar cómo revertir
4. **Testear en desarrollo** antes de aplicar en producción
5. **Hacer backup** antes de migrar en producción
6. **Documentar cambios** con comentarios detallados
7. **Usar IF NOT EXISTS** para idempotencia

### Para Backups

1. **Automatizar backups diarios** con cron
2. **Mantener múltiples copias** (3-2-1: 3 copias, 2 medios, 1 offsite)
3. **Testear restauración** periódicamente
4. **Rotar backups antiguos** (mantener últimos 30 días + mensuales)
5. **Comprimir backups** para ahorrar espacio
6. **Monitorear espacio en disco**

### Para Importaciones

1. **Siempre hacer backup** antes de importar
2. **Verificar espacio en disco** disponible
3. **Usar --production flag** en producción para confirmación extra
4. **Testear en staging** primero
5. **Tener plan de rollback** preparado
6. **Documentar la importación** (fecha, origen, motivo)

### Seguridad

1. **Nunca commitear contraseñas** a git
2. **Usar variables de entorno** para credenciales
3. **Restringir permisos** de scripts (chmod 700)
4. **Auditar accesos** a bases de datos
5. **Encriptar backups** si contienen datos sensibles
6. **Rotar credenciales** periódicamente
7. **Usar archivo .pgpass** en producción en lugar de PGPASSWORD:
   ```bash
   # Crear archivo .pgpass en directorio home
   echo "localhost:5432:*:your_username:your_password" > ~/.pgpass
   chmod 600 ~/.pgpass
   # Luego ejecutar scripts sin parámetro -P
   ./run_migrations.sh -d all -u your_username
   ```

## Scripts de Ayuda Rápida

### Ver ayuda de cualquier script

```bash
./run_migrations.sh --help
./export_data.sh --help
./import_data.sh --help
```

### Verificar estado de bases de datos

```bash
# Crear script helper
cat > check_databases.sh << 'EOF'
#!/bin/bash
for db in sedes_uneg categorias_fallas reportes_generales departamentos_db; do
    echo "=== $db ==="
    psql -h localhost -U postgres -d $db -c "\dt" 2>/dev/null || echo "Error conectando a $db"
    echo ""
done
EOF

chmod +x check_databases.sh
./check_databases.sh
```

### Listar todas las migraciones disponibles

```bash
ls -1 migrations/*.sql | sort
```

---

## Soporte

Para problemas o preguntas:
- Revisar esta documentación
- Consultar logs en `/tmp/migration_output.log` o `/tmp/import_output.log`
- Contactar al equipo de SISTEMATIZACION-UNEG

## Changelog

- **2024-01-23**: Creación inicial del sistema de scripts y documentación
