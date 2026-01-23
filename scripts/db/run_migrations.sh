#!/bin/bash
# =============================================================================
# Script: run_migrations.sh
# Descripción: Ejecuta migraciones SQL para las bases de datos del proyecto
# Uso: ./run_migrations.sh [opciones]
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
MIGRATION_DIR="$(dirname "$0")/migrations"
TARGET_DB=""
DRY_RUN=false

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
${GREEN}run_migrations.sh${NC} - Ejecutor de migraciones SQL para dashboard UNEGIA

${YELLOW}USO:${NC}
    ./run_migrations.sh [opciones]

${YELLOW}OPCIONES:${NC}
    -h, --help              Mostrar esta ayuda
    -H, --host HOST         Host de PostgreSQL (default: localhost)
    -p, --port PORT         Puerto de PostgreSQL (default: 5432)
    -u, --user USER         Usuario de PostgreSQL (default: postgres)
    -P, --password PASS     Contraseña de PostgreSQL
    -d, --database DB       Base de datos específica a migrar
                            Opciones: sedes_uneg, categorias_fallas, 
                                     reportes_generales, departamentos_db, all
    -m, --migration-dir DIR Directorio de migraciones (default: ./migrations)
    --dry-run               Mostrar qué se ejecutaría sin ejecutar

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
    # Migrar todas las bases de datos
    ./run_migrations.sh -d all -u postgres -P your_secure_password

    # Migrar solo sedes_uneg
    ./run_migrations.sh -d sedes_uneg -u postgres -P your_secure_password

    # Usar variables de entorno (recomendado para seguridad)
    export DB_USER=postgres
    export DB_PASSWORD=your_secure_password
    ./run_migrations.sh -d all

    # Dry run para ver qué se ejecutaría
    ./run_migrations.sh -d all --dry-run

${YELLOW}BASES DE DATOS SOPORTADAS:${NC}
    - sedes_uneg
    - categorias_fallas
    - reportes_generales
    - departamentos_db
    - all (todas las anteriores)

EOF
}

check_requirements() {
    print_info "Verificando requisitos..."
    
    if ! command -v psql &> /dev/null; then
        print_error "psql no está instalado"
        print_info "Instalar con: sudo apt install postgresql-client"
        exit 1
    fi
    
    if [ ! -d "$MIGRATION_DIR" ]; then
        print_error "Directorio de migraciones no existe: $MIGRATION_DIR"
        exit 1
    fi
    
    print_success "Requisitos verificados"
}

run_migration_file() {
    local db_name=$1
    local migration_file=$2
    local filename=$(basename "$migration_file")
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Se ejecutaría: $filename en $db_name"
        return 0
    fi
    
    print_info "Ejecutando: $filename en $db_name..."
    
    export PGPASSWORD="$DB_PASSWORD"
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -f "$migration_file" 2>&1 | tee /tmp/migration_output.log; then
        print_success "Migración exitosa: $filename"
        return 0
    else
        print_error "Error al ejecutar: $filename"
        print_error "Ver detalles en /tmp/migration_output.log"
        return 1
    fi
}

migrate_database() {
    local db_name=$1
    local pattern="${db_name}.sql"
    
    print_info "═══════════════════════════════════════════════════════"
    print_info "Migrando base de datos: ${GREEN}$db_name${NC}"
    print_info "═══════════════════════════════════════════════════════"
    
    # Buscar archivos de migración para esta base de datos
    local migration_files=$(find "$MIGRATION_DIR" -name "*${pattern}" -type f | sort)
    
    if [ -z "$migration_files" ]; then
        print_warning "No se encontraron migraciones para $db_name"
        return 0
    fi
    
    local count=0
    local success=0
    local failed=0
    
    while IFS= read -r migration_file; do
        ((count++))
        if run_migration_file "$db_name" "$migration_file"; then
            ((success++))
        else
            ((failed++))
        fi
    done <<< "$migration_files"
    
    echo ""
    print_info "Resumen para $db_name:"
    print_info "  Total: $count | Exitosas: $success | Fallidas: $failed"
    echo ""
    
    if [ $failed -gt 0 ]; then
        return 1
    fi
    
    return 0
}

migrate_all() {
    local databases=("sedes_uneg" "categorias_fallas" "reportes_generales" "departamentos_db")
    local total_success=0
    local total_failed=0
    
    for db in "${databases[@]}"; do
        if migrate_database "$db"; then
            ((total_success++))
        else
            ((total_failed++))
        fi
    done
    
    echo ""
    print_info "═══════════════════════════════════════════════════════"
    print_info "RESUMEN FINAL"
    print_info "═══════════════════════════════════════════════════════"
    print_info "Bases de datos migradas exitosamente: $total_success"
    print_info "Bases de datos con errores: $total_failed"
    
    if [ $total_failed -gt 0 ]; then
        print_error "Algunas migraciones fallaron. Revisar logs arriba."
        return 1
    fi
    
    print_success "¡Todas las migraciones completadas exitosamente!"
    return 0
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
        -m|--migration-dir)
            MIGRATION_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
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
print_info "  EJECUTOR DE MIGRACIONES - Dashboard UNEGIA"
print_info "═══════════════════════════════════════════════════════"
echo ""

# Validaciones
if [ -z "$TARGET_DB" ]; then
    print_error "Debe especificar una base de datos con -d/--database"
    echo "Usar --help para más información"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    print_warning "No se especificó contraseña"
    read -sp "Ingrese contraseña para PostgreSQL: " DB_PASSWORD
    echo ""
fi

check_requirements

# Mostrar configuración
if [ "$DRY_RUN" = true ]; then
    print_warning "MODO DRY RUN - No se ejecutarán cambios reales"
fi

print_info "Configuración:"
print_info "  Host: $DB_HOST"
print_info "  Puerto: $DB_PORT"
print_info "  Usuario: $DB_USER"
print_info "  Directorio de migraciones: $MIGRATION_DIR"
echo ""

# Ejecutar migraciones
case "$TARGET_DB" in
    all)
        migrate_all
        ;;
    sedes_uneg|categorias_fallas|reportes_generales|departamentos_db)
        migrate_database "$TARGET_DB"
        ;;
    *)
        print_error "Base de datos no reconocida: $TARGET_DB"
        print_info "Opciones válidas: sedes_uneg, categorias_fallas, reportes_generales, departamentos_db, all"
        exit 1
        ;;
esac

exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_success "Proceso completado exitosamente"
else
    print_error "Proceso completado con errores"
fi

exit $exit_code
