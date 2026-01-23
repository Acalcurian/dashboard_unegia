#!/bin/bash
# =============================================================================
# Script: export_data.sh
# Descripción: Exporta datos de las bases de datos del proyecto a archivos SQL
# Uso: ./export_data.sh [opciones]
# =============================================================================

set -e  # Terminar en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Variables por defecto
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD}"
EXPORT_DIR=""
COMPRESS=true
DATA_ONLY=false
SCHEMA_ONLY=false
TARGET_DB=""

# =============================================================================
# Funciones auxiliares
# =============================================================================

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

show_help() {
    cat << EOF
${GREEN}export_data.sh${NC} - Exportador de datos para dashboard UNEGIA

${YELLOW}USO:${NC}
    ./export_data.sh [opciones]

${YELLOW}OPCIONES:${NC}
    -h, --help              Mostrar esta ayuda
    -H, --host HOST         Host de PostgreSQL (default: localhost)
    -p, --port PORT         Puerto de PostgreSQL (default: 5432)
    -u, --user USER         Usuario de PostgreSQL (default: postgres)
    -P, --password PASS     Contraseña de PostgreSQL
    -d, --database DB       Base de datos específica a exportar
                            Opciones: sedes_uneg, categorias_fallas, 
                                     reportes_generales, departamentos_db, all
    -o, --output DIR        Directorio de salida (default: ./exports/TIMESTAMP)
    --no-compress           No comprimir archivos de exportación
    --data-only             Exportar solo datos (sin esquema)
    --schema-only           Exportar solo esquema (sin datos)

${YELLOW}VARIABLES DE ENTORNO:${NC}
    DB_HOST                 Host de PostgreSQL
    DB_PORT                 Puerto de PostgreSQL
    DB_USER                 Usuario de PostgreSQL
    DB_PASSWORD             Contraseña de PostgreSQL

${YELLOW}NOTA DE SEGURIDAD:${NC}
    Para mayor seguridad en producción, considere usar archivo .pgpass en lugar
    de pasar contraseñas por línea de comandos o variables de entorno.
    Ver: https://www.postgresql.org/docs/current/libpq-pgpass.html

${YELLOW}EJEMPLOS:${NC}
    # Exportar todas las bases de datos
    ./export_data.sh -d all -u postgres -P your_secure_password

    # Exportar solo sedes_uneg
    ./export_data.sh -d sedes_uneg -u postgres -P your_secure_password

    # Exportar solo datos sin esquema
    ./export_data.sh -d all --data-only

    # Exportar sin comprimir
    ./export_data.sh -d all --no-compress

    # Usar variables de entorno (recomendado para seguridad)
    export DB_USER=postgres
    export DB_PASSWORD=your_secure_password
    ./export_data.sh -d all -o /backup/mibackup

${YELLOW}ARCHIVOS GENERADOS:${NC}
    Por defecto se crean en: exports/YYYYMMDD_HHMMSS/
    - DBNAME.sql (sin comprimir) o DBNAME.sql.gz (comprimido)
    - export_metadata.txt (información de la exportación)

EOF
}

check_requirements() {
    print_info "Verificando requisitos..."
    
    if ! command -v pg_dump &> /dev/null; then
        print_error "pg_dump no está instalado"
        print_info "Instalar con: sudo apt install postgresql-client"
        exit 1
    fi
    
    if [ "$COMPRESS" = true ] && ! command -v gzip &> /dev/null; then
        print_error "gzip no está instalado"
        print_info "Instalar con: sudo apt install gzip"
        exit 1
    fi
    
    print_success "Requisitos verificados"
}

export_database() {
    local db_name=$1
    local output_file="$EXPORT_DIR/${db_name}.sql"
    
    print_info "═══════════════════════════════════════════════════════"
    print_info "Exportando: ${GREEN}$db_name${NC}"
    print_info "═══════════════════════════════════════════════════════"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    # Construir opciones de pg_dump
    local dump_options="-h $DB_HOST -p $DB_PORT -U $DB_USER"
    
    if [ "$DATA_ONLY" = true ]; then
        dump_options="$dump_options --data-only"
        print_info "Modo: Solo datos"
    elif [ "$SCHEMA_ONLY" = true ]; then
        dump_options="$dump_options --schema-only"
        print_info "Modo: Solo esquema"
    else
        print_info "Modo: Esquema y datos completos"
    fi
    
    # Añadir opciones adicionales para mejor portabilidad
    dump_options="$dump_options --no-owner --no-acl --encoding=UTF8"
    
    print_info "Ejecutando pg_dump..."
    
    if pg_dump $dump_options "$db_name" > "$output_file" 2>/tmp/export_error.log; then
        local file_size=$(du -h "$output_file" | cut -f1)
        print_success "Exportación completada: $output_file ($file_size)"
        
        # Comprimir si está habilitado
        if [ "$COMPRESS" = true ]; then
            print_info "Comprimiendo archivo..."
            if gzip -f "$output_file"; then
                local compressed_size=$(du -h "${output_file}.gz" | cut -f1)
                print_success "Archivo comprimido: ${output_file}.gz ($compressed_size)"
            else
                print_error "Error al comprimir archivo"
                return 1
            fi
        fi
        
        return 0
    else
        print_error "Error al exportar $db_name"
        print_error "Ver detalles en /tmp/export_error.log"
        cat /tmp/export_error.log
        return 1
    fi
}

export_all() {
    local databases=("sedes_uneg" "categorias_fallas" "reportes_generales" "departamentos_db")
    local total_success=0
    local total_failed=0
    
    for db in "${databases[@]}"; do
        if export_database "$db"; then
            ((total_success++))
        else
            ((total_failed++))
        fi
        echo ""
    done
    
    print_info "═══════════════════════════════════════════════════════"
    print_info "RESUMEN FINAL"
    print_info "═══════════════════════════════════════════════════════"
    print_info "Bases de datos exportadas exitosamente: $total_success"
    print_info "Bases de datos con errores: $total_failed"
    
    if [ $total_failed -gt 0 ]; then
        print_error "Algunas exportaciones fallaron"
        return 1
    fi
    
    print_success "¡Todas las exportaciones completadas!"
    return 0
}

create_metadata() {
    local metadata_file="$EXPORT_DIR/export_metadata.txt"
    
    cat > "$metadata_file" << EOF
=============================================================================
METADATOS DE EXPORTACIÓN - Dashboard UNEGIA
=============================================================================

Fecha de exportación: $(date '+%Y-%m-%d %H:%M:%S')
Host: $DB_HOST
Puerto: $DB_PORT
Usuario: $DB_USER

Bases de datos: $TARGET_DB

Opciones:
  - Compresión: $COMPRESS
  - Solo datos: $DATA_ONLY
  - Solo esquema: $SCHEMA_ONLY

Sistema operativo: $(uname -a)
Versión de pg_dump: $(pg_dump --version)

Archivos generados:
EOF
    
    ls -lh "$EXPORT_DIR" | tail -n +2 >> "$metadata_file"
    
    print_success "Metadatos guardados: $metadata_file"
}

# =============================================================================
# Parseo de argumentos
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -H|--host)
            DB_HOST="$2"
            shift 2
            ;;
        -p|--port)
            DB_PORT="$2"
            shift 2
            ;;
        -u|--user)
            DB_USER="$2"
            shift 2
            ;;
        -P|--password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        -d|--database)
            TARGET_DB="$2"
            shift 2
            ;;
        -o|--output)
            EXPORT_DIR="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --data-only)
            DATA_ONLY=true
            shift
            ;;
        --schema-only)
            SCHEMA_ONLY=true
            shift
            ;;
        *)
            print_error "Opción desconocida: $1"
            echo "Usar --help para ver opciones disponibles"
            exit 1
            ;;
    esac
done

# =============================================================================
# Main
# =============================================================================

echo ""
print_info "═══════════════════════════════════════════════════════"
print_info "  EXPORTADOR DE DATOS - Dashboard UNEGIA"
print_info "═══════════════════════════════════════════════════════"
echo ""

# Validaciones
if [ -z "$TARGET_DB" ]; then
    print_error "Debe especificar una base de datos con -d/--database"
    echo "Usar --help para más información"
    exit 1
fi

if [ "$DATA_ONLY" = true ] && [ "$SCHEMA_ONLY" = true ]; then
    print_error "No se puede usar --data-only y --schema-only simultáneamente"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    print_warning "No se especificó contraseña"
    read -sp "Ingrese contraseña para PostgreSQL: " DB_PASSWORD
    echo ""
fi

# Crear directorio de exportación si no existe
if [ -z "$EXPORT_DIR" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    EXPORT_DIR="$(dirname "$0")/../../exports/${TIMESTAMP}"
fi

mkdir -p "$EXPORT_DIR"
print_success "Directorio de exportación: $EXPORT_DIR"

check_requirements

# Mostrar configuración
print_info "Configuración:"
print_info "  Host: $DB_HOST"
print_info "  Puerto: $DB_PORT"
print_info "  Usuario: $DB_USER"
print_info "  Compresión: $COMPRESS"
print_info "  Solo datos: $DATA_ONLY"
print_info "  Solo esquema: $SCHEMA_ONLY"
echo ""

# Ejecutar exportaciones
case "$TARGET_DB" in
    all)
        export_all
        ;;
    sedes_uneg|categorias_fallas|reportes_generales|departamentos_db)
        export_database "$TARGET_DB"
        ;;
    *)
        print_error "Base de datos no reconocida: $TARGET_DB"
        print_info "Opciones válidas: sedes_uneg, categorias_fallas, reportes_generales, departamentos_db, all"
        exit 1
        ;;
esac

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    create_metadata
    echo ""
    print_success "Exportación completada exitosamente en:"
    print_info "  $EXPORT_DIR"
else
    print_error "Exportación completada con errores"
fi

exit $exit_code
