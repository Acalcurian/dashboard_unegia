#!/bin/bash
# =============================================================================
# Script: import_data.sh
# Descripción: Importa datos a las bases de datos del proyecto desde archivos SQL
# Uso: ./import_data.sh [opciones]
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
IMPORT_DIR=""
CLEAN_TABLES=false
TARGET_DB=""
FORCE=false
PRODUCTION=false

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
${GREEN}import_data.sh${NC} - Importador de datos para dashboard UNEGIA

${YELLOW}USO:${NC}
    ./import_data.sh [opciones]

${YELLOW}OPCIONES:${NC}
    -h, --help              Mostrar esta ayuda
    -H, --host HOST         Host de PostgreSQL (default: localhost)
    -p, --port PORT         Puerto de PostgreSQL (default: 5432)
    -u, --user USER         Usuario de PostgreSQL (default: postgres)
    -P, --password PASS     Contraseña de PostgreSQL
    -d, --database DB       Base de datos específica a importar
                            Opciones: sedes_uneg, categorias_fallas, 
                                     reportes_generales, departamentos_db, all
    -i, --import-dir DIR    Directorio con archivos SQL a importar (requerido)
    --clean                 Limpiar tablas antes de importar (DROP CASCADE)
    --force                 No solicitar confirmación
    --production            Marcar como entorno de producción (requiere confirmación extra)

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
    # Importar todas las bases de datos desde un directorio
    ./import_data.sh -d all -i ./exports/20240101_120000/ -u postgres -P your_secure_password

    # Importar solo sedes_uneg
    ./import_data.sh -d sedes_uneg -i ./exports/20240101_120000/

    # Importar limpiando tablas existentes
    ./import_data.sh -d all -i ./exports/20240101_120000/ --clean

    # Importar en producción (con confirmación)
    ./import_data.sh -d all -i ./exports/20240101_120000/ --production

    # Usar variables de entorno (recomendado para seguridad)
    export DB_USER=postgres
    export DB_PASSWORD=your_secure_password
    ./import_data.sh -d all -i ./exports/20240101_120000/

${YELLOW}FORMATOS SOPORTADOS:${NC}
    - Archivos .sql (sin comprimir)
    - Archivos .sql.gz (comprimidos con gzip)

${YELLOW}IMPORTANTE:${NC}
    - Use --clean con precaución ya que eliminará datos existentes
    - En producción siempre se solicita confirmación adicional
    - Realice backups antes de importar en producción

EOF
}

check_requirements() {
    print_info "Verificando requisitos..."
    
    if ! command -v psql &> /dev/null; then
        print_error "psql no está instalado"
        print_info "Instalar con: sudo apt install postgresql-client"
        exit 1
    fi
    
    if ! command -v gunzip &> /dev/null; then
        print_error "gunzip no está instalado"
        print_info "Instalar con: sudo apt install gzip"
        exit 1
    fi
    
    if [ ! -d "$IMPORT_DIR" ]; then
        print_error "Directorio de importación no existe: $IMPORT_DIR"
        exit 1
    fi
    
    print_success "Requisitos verificados"
}

confirm_action() {
    local message=$1
    
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    print_warning "$message"
    read -p "¿Desea continuar? (escriba 'SI' para confirmar): " confirmation
    
    if [ "$confirmation" != "SI" ]; then
        print_info "Operación cancelada por el usuario"
        exit 0
    fi
}

confirm_production() {
    if [ "$PRODUCTION" = false ]; then
        return 0
    fi
    
    print_error "═══════════════════════════════════════════════════════"
    print_error "  ¡ADVERTENCIA! MODO PRODUCCIÓN ACTIVADO"
    print_error "═══════════════════════════════════════════════════════"
    print_warning "Está a punto de importar datos en un entorno de PRODUCCIÓN"
    print_warning "Esta operación puede sobrescribir datos críticos"
    echo ""
    read -p "Escriba 'CONFIRMO PRODUCCION' para continuar: " confirmation
    
    if [ "$confirmation" != "CONFIRMO PRODUCCION" ]; then
        print_info "Operación cancelada"
        exit 0
    fi
    
    # Segunda confirmación
    print_warning "Confirmación adicional requerida"
    read -p "Escriba el nombre de la base de datos ($TARGET_DB) para confirmar: " db_confirmation
    
    if [ "$db_confirmation" != "$TARGET_DB" ] && [ "$db_confirmation" != "all" ]; then
        print_info "Confirmación incorrecta. Operación cancelada"
        exit 0
    fi
}

clean_database() {
    local db_name=$1
    
    print_warning "Limpiando base de datos: $db_name"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    # Obtener lista de tablas
    local tables=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -t -c \
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public';" 2>/dev/null | tr -d ' ')
    
    if [ -z "$tables" ]; then
        print_info "No hay tablas para limpiar en $db_name"
        return 0
    fi
    
    for table in $tables; do
        if [ ! -z "$table" ]; then
            print_info "Eliminando tabla: $table"
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -c \
                "DROP TABLE IF EXISTS $table CASCADE;" > /dev/null 2>&1 || true
        fi
    done
    
    print_success "Base de datos limpiada: $db_name"
}

import_database() {
    local db_name=$1
    local sql_file="$IMPORT_DIR/${db_name}.sql"
    local sql_gz_file="$IMPORT_DIR/${db_name}.sql.gz"
    local file_to_import=""
    local is_compressed=false
    
    print_info "═══════════════════════════════════════════════════════"
    print_info "Importando: ${GREEN}$db_name${NC}"
    print_info "═══════════════════════════════════════════════════════"
    
    # Determinar qué archivo importar
    if [ -f "$sql_file" ]; then
        file_to_import="$sql_file"
        print_info "Archivo encontrado: $sql_file"
    elif [ -f "$sql_gz_file" ]; then
        file_to_import="$sql_gz_file"
        is_compressed=true
        print_info "Archivo comprimido encontrado: $sql_gz_file"
    else
        print_error "No se encontró archivo SQL para $db_name en $IMPORT_DIR"
        print_info "Se buscó: ${db_name}.sql o ${db_name}.sql.gz"
        return 1
    fi
    
    # Limpiar si está habilitado
    if [ "$CLEAN_TABLES" = true ]; then
        clean_database "$db_name"
    fi
    
    export PGPASSWORD="$DB_PASSWORD"
    
    print_info "Importando datos..."
    
    # Importar según el tipo de archivo
    if [ "$is_compressed" = true ]; then
        if gunzip -c "$file_to_import" | psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" 2>&1 | tee /tmp/import_output.log; then
            print_success "Importación completada para: $db_name"
            return 0
        else
            print_error "Error al importar $db_name"
            print_error "Ver detalles en /tmp/import_output.log"
            return 1
        fi
    else
        if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -f "$file_to_import" 2>&1 | tee /tmp/import_output.log; then
            print_success "Importación completada para: $db_name"
            return 0
        else
            print_error "Error al importar $db_name"
            print_error "Ver detalles en /tmp/import_output.log"
            return 1
        fi
    fi
}

import_all() {
    local databases=("sedes_uneg" "categorias_fallas" "reportes_generales" "departamentos_db")
    local total_success=0
    local total_failed=0
    
    for db in "${databases[@]}"; do
        if import_database "$db"; then
            ((total_success++))
        else
            ((total_failed++))
        fi
        echo ""
    done
    
    print_info "═══════════════════════════════════════════════════════"
    print_info "RESUMEN FINAL"
    print_info "═══════════════════════════════════════════════════════"
    print_info "Bases de datos importadas exitosamente: $total_success"
    print_info "Bases de datos con errores: $total_failed"
    
    if [ $total_failed -gt 0 ]; then
        print_error "Algunas importaciones fallaron"
        return 1
    fi
    
    print_success "¡Todas las importaciones completadas!"
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
        -i|--import-dir)
            IMPORT_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN_TABLES=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --production)
            PRODUCTION=true
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
print_info "  IMPORTADOR DE DATOS - Dashboard UNEGIA"
print_info "═══════════════════════════════════════════════════════"
echo ""

# Validaciones
if [ -z "$TARGET_DB" ]; then
    print_error "Debe especificar una base de datos con -d/--database"
    echo "Usar --help para más información"
    exit 1
fi

if [ -z "$IMPORT_DIR" ]; then
    print_error "Debe especificar directorio de importación con -i/--import-dir"
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
print_info "Configuración:"
print_info "  Host: $DB_HOST"
print_info "  Puerto: $DB_PORT"
print_info "  Usuario: $DB_USER"
print_info "  Directorio: $IMPORT_DIR"
print_info "  Limpiar tablas: $CLEAN_TABLES"
print_info "  Modo producción: $PRODUCTION"
echo ""

# Confirmaciones de seguridad
confirm_production

if [ "$CLEAN_TABLES" = true ]; then
    confirm_action "Se eliminarán todas las tablas existentes antes de importar"
else
    confirm_action "Se importarán datos en las bases de datos especificadas"
fi

# Ejecutar importaciones
case "$TARGET_DB" in
    all)
        import_all
        ;;
    sedes_uneg|categorias_fallas|reportes_generales|departamentos_db)
        import_database "$TARGET_DB"
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
    print_success "Importación completada exitosamente"
else
    print_error "Importación completada con errores"
fi

exit $exit_code
