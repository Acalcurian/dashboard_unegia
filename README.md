# Dashboard UNEGIA

Aplicación web basada en Flask para gestionar reportes de infraestructura en la Universidad Nacional Experimental de Guayana (UNEG).

## Descripción del Proyecto

Esta aplicación web permite a los usuarios:
- Reportar problemas de infraestructura en diferentes categorías (eléctrico, plomería, refrigeración, seguridad, infraestructura, mobiliario, suministros y tecnología)
- Subir fotos y descripciones de los problemas
- Rastrear el estado de los reportes mediante notificaciones por correo electrónico
- Ver paneles de administración con análisis completos de reportes
- Gestionar reportes en múltiples sedes del campus

## Características

- **Sistema de reportes multi-categoría**: 8 categorías para diferentes tipos de problemas de infraestructura
- **Soporte para carga de fotos**: Subida de imágenes de hasta 500MB
- **Notificaciones por correo**: Notificaciones automáticas por email con seguimiento de confirmación
- **Panel de administración**: Vistas completas de análisis y reportes
- **Arquitectura multi-base de datos**: Bases de datos separadas para sedes, categorías, reportes y departamentos

## Requisitos Previos

Antes de desplegar esta aplicación, asegúrese de tener instalado lo siguiente en su servidor:

- **Python**: 3.8 o superior
- **PostgreSQL**: 12 o superior (con 4 bases de datos separadas configuradas)
- **PM2**: Gestor de procesos para aplicaciones Node.js
- **Nginx**: Servidor web y proxy inverso
- **Git**: Para clonar el repositorio
- **pip**: Gestor de paquetes de Python

### Configuración del Sistema

```bash
# Actualizar paquetes del sistema
sudo apt update && sudo apt upgrade -y

# Instalar Python y pip
sudo apt install python3 python3-pip python3-venv -y

# Instalar PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Instalar Nginx
sudo apt install nginx -y

# Instalar Node.js y PM2
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install nodejs -y
sudo npm install -g pm2
```

## Instalación y Despliegue

### 1. Clonar el Repositorio

```bash
cd /ruta/a/sus/proyectos
git clone https://github.com/SISTEMATIZACION-UNEG/dashboard_unegia.git
cd dashboard_unegia
```

### 2. Crear y Activar Entorno Virtual

```bash
# Crear entorno virtual
python3 -m venv venv

# Activar entorno virtual
source venv/bin/activate

# Verificar activación (debería mostrar la ruta a venv/bin/python)
which python
```

### 3. Instalar Dependencias

```bash
# Instalar todos los paquetes requeridos
pip install -r requirements.txt

# Verificar instalación
pip list
```

### 4. Configurar Variables de Entorno

Crear un archivo `.env` en la raíz del proyecto con su configuración:

```bash
# Copiar el archivo de ejemplo si está disponible, o crear uno nuevo
touch .env
```

Agregar las siguientes variables a su archivo `.env`:

```env
# Configuración de Email
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=True
MAIL_USERNAME=su-email@gmail.com
MAIL_PASSWORD=su-contraseña-de-aplicación

# Configuración de Flask
FLASK_ENV=production
SECRET_KEY=su-clave-secreta-aquí-cámbiela
```

### 5. Configurar Conexión a Base de Datos

Crear un archivo `config.py` con sus credenciales de base de datos:

```python
DATABASES = {
    "sedes_uneg": {
        "host": "localhost",
        "database": "sedes_uneg",
        "user": "su_usuario_db",
        "password": "su_contraseña_db",
        "port": 5432
    },
    "categorias_fallas": {
        "host": "localhost",
        "database": "categorias_fallas",
        "user": "su_usuario_db",
        "password": "su_contraseña_db",
        "port": 5432
    },
    "reportes_generales": {
        "host": "localhost",
        "database": "reportes_generales",
        "user": "su_usuario_db",
        "password": "su_contraseña_db",
        "port": 5432
    },
    "departamentos_db": {
        "host": "localhost",
        "database": "departamentos_db",
        "user": "su_usuario_db",
        "password": "su_contraseña_db",
        "port": 5432
    }
}
```

**Importante**: Nunca haga commit de este archivo al control de versiones. Ya está listado en `.gitignore`.

### 6. Configurar Bases de Datos y Ejecutar Migraciones

Este proyecto utiliza **migraciones SQL manuales** en lugar de Flask-Migrate/Alembic, ya que usa conexiones directas con psycopg2 (no SQLAlchemy ORM).

#### Crear las Bases de Datos

```bash
# Conectar a PostgreSQL
sudo -u postgres psql

# Crear las 4 bases de datos
CREATE DATABASE sedes_uneg;
CREATE DATABASE categorias_fallas;
CREATE DATABASE reportes_generales;
CREATE DATABASE departamentos_db;

# Crear usuario (si es necesario)
CREATE USER dashboard_user WITH PASSWORD 'su_contraseña_segura';

# Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE sedes_uneg TO dashboard_user;
GRANT ALL PRIVILEGES ON DATABASE categorias_fallas TO dashboard_user;
GRANT ALL PRIVILEGES ON DATABASE reportes_generales TO dashboard_user;
GRANT ALL PRIVILEGES ON DATABASE departamentos_db TO dashboard_user;

# Salir
\q
```

#### Ejecutar Migraciones Iniciales

El proyecto incluye scripts automatizados para gestionar las migraciones de base de datos:

```bash
# Navegar al directorio de scripts
cd scripts/db

# Ejecutar migraciones en todas las bases de datos
./run_migrations.sh -d all -u dashboard_user -P su_contraseña

# O usar variables de entorno
export DB_USER=dashboard_user
export DB_PASSWORD=su_contraseña
./run_migrations.sh -d all
```

Para más información sobre el sistema de migraciones, consulte la [Guía de Scripts de Base de Datos](scripts/README_SCRIPTS.md).

### 7. Crear Directorio de Logs

```bash
# Crear directorio para logs de PM2
mkdir -p logs
```

### 8. Configurar PM2

El archivo `ecosystem.config.js` ya está configurado. Actualice la ruta `cwd` si su directorio de instalación es diferente:

```bash
# Editar ecosystem.config.js y actualizar la ruta cwd para que coincida con su instalación
nano ecosystem.config.js
```

Iniciar la aplicación con PM2:

```bash
# Iniciar la aplicación
pm2 start ecosystem.config.js

# Guardar configuración de PM2
pm2 save

# Configurar PM2 para iniciar al arranque del sistema
pm2 startup
# Seguir las instrucciones proporcionadas por el comando anterior
```

### 9. Configurar Nginx

Copiar la configuración de ejemplo de Nginx:

```bash
# Copiar la configuración de ejemplo
sudo cp nginx.conf.example /etc/nginx/sites-available/dashboard-unegia

# Editar el archivo de configuración
sudo nano /etc/nginx/sites-available/dashboard-unegia
```

Actualizar lo siguiente en la configuración de Nginx:
- `server_name`: Reemplazar con su dominio o IP del servidor
- Ruta de archivos estáticos: Asegurar que coincida con su directorio de instalación
- Configuración del proxy: Verificar que el puerto coincida con su configuración de Gunicorn (por defecto: 5000)

Habilitar el sitio:

```bash
# Crear enlace simbólico para habilitar el sitio
sudo ln -s /etc/nginx/sites-available/dashboard-unegia /etc/nginx/sites-enabled/

# Probar configuración de Nginx
sudo nginx -t

# Recargar Nginx
sudo systemctl reload nginx
```

### 10. Configurar Firewall (si aplica)

```bash
# Permitir tráfico HTTP y HTTPS
sudo ufw allow 'Nginx Full'

# Verificar estado del firewall
sudo ufw status
```

## Gestión de la Aplicación

### Comandos de PM2

```bash
# Ver estado de la aplicación
pm2 status

# Ver logs de la aplicación
pm2 logs dashboard-unegia

# Ver solo logs de errores
pm2 logs dashboard-unegia --err

# Ver solo logs de salida
pm2 logs dashboard-unegia --out

# Reiniciar la aplicación
pm2 restart dashboard-unegia

# Detener la aplicación
pm2 stop dashboard-unegia

# Iniciar la aplicación
pm2 start dashboard-unegia

# Eliminar la aplicación de PM2
pm2 delete dashboard-unegia

# Monitorear aplicación en tiempo real
pm2 monit
```

### Comandos de Nginx

```bash
# Verificar estado de Nginx
sudo systemctl status nginx

# Iniciar Nginx
sudo systemctl start nginx

# Detener Nginx
sudo systemctl stop nginx

# Reiniciar Nginx
sudo systemctl restart nginx

# Recargar configuración de Nginx
sudo systemctl reload nginx

# Probar configuración de Nginx
sudo nginx -t
```

### Actualizaciones de la Aplicación

Para desplegar actualizaciones:

```bash
# Navegar al directorio del proyecto
cd /ruta/a/su/dashboard_unegia

# Obtener últimos cambios
git pull origin main

# Activar entorno virtual
source venv/bin/activate

# Instalar nuevas dependencias
pip install -r requirements.txt

# Ejecutar nuevas migraciones (si hay)
cd scripts/db
./run_migrations.sh -d all -u dashboard_user -P su_contraseña
cd ../..

# Reiniciar la aplicación
pm2 restart dashboard-unegia

# Monitorear posibles problemas
pm2 logs dashboard-unegia
```

## Gestión de Base de Datos

### Sistema de Migraciones

Este proyecto utiliza un sistema de migraciones SQL manuales. Para información detallada:

- **Guía completa**: Ver [scripts/README_SCRIPTS.md](scripts/README_SCRIPTS.md)
- **Archivos de migración**: `scripts/db/migrations/`
- **Scripts disponibles**:
  - `run_migrations.sh` - Ejecutar migraciones
  - `export_data.sh` - Exportar/respaldar datos
  - `import_data.sh` - Importar/restaurar datos

### Ejemplos Rápidos

**Crear respaldo de todas las bases de datos:**
```bash
cd scripts/db
./export_data.sh -d all -u postgres -P contraseña
```

**Restaurar desde respaldo:**
```bash
cd scripts/db
./import_data.sh -d all -i ../../exports/20240123_120000/ -u postgres -P contraseña
```

**Ejecutar una nueva migración:**
```bash
cd scripts/db
./run_migrations.sh -d nombre_base_datos -u postgres -P contraseña
```

Para más detalles, consulte la [Guía de Scripts de Base de Datos](scripts/README_SCRIPTS.md).

## Estructura del Proyecto

```
dashboard_unegia/
├── app.py                    # Aplicación principal de Flask
├── conexion.py              # Manejadores de conexión a base de datos
├── dashboard_router.py      # Blueprint y rutas del dashboard
├── config.py               # Configuración de base de datos (no en repo)
├── .env                    # Variables de entorno (no en repo)
├── requirements.txt        # Dependencias de Python
├── ecosystem.config.js     # Configuración de PM2
├── nginx.conf.example      # Ejemplo de configuración de Nginx
├── static/                 # Archivos estáticos (CSS, JS, imágenes)
│   ├── dashboard/         # Assets del dashboard
│   └── uploads/           # Archivos subidos por usuarios
├── templates/             # Plantillas HTML
│   └── paginas/          # Páginas de la aplicación
├── scripts/              # Scripts de base de datos y utilidades
│   ├── db/              # Scripts de base de datos
│   │   ├── migrations/  # Archivos de migración SQL
│   │   ├── run_migrations.sh
│   │   ├── export_data.sh
│   │   └── import_data.sh
│   └── README_SCRIPTS.md # Guía de scripts
├── exports/              # Respaldos de base de datos (generado)
├── logs/                 # Logs de aplicación (creado en tiempo de ejecución)
└── venv/                # Entorno virtual (no en repo)
```

## Solución de Problemas

### La aplicación no inicia

1. **Verificar logs de PM2**:
   ```bash
   pm2 logs dashboard-unegia
   ```

2. **Verificar entorno virtual**:
   ```bash
   source venv/bin/activate
   which python
   pip list
   ```

3. **Verificar conexiones a base de datos**:
   - Verificar que PostgreSQL esté corriendo: `sudo systemctl status postgresql`
   - Probar credenciales de base de datos en `config.py`
   - Verificar que las 4 bases de datos existan y sean accesibles

4. **Verificar variables de entorno**:
   ```bash
   cat .env
   ```

### Error 502 Bad Gateway

1. **Verificar si Gunicorn está corriendo**:
   ```bash
   pm2 status
   ps aux | grep gunicorn
   ```

2. **Verificar configuración de Nginx**:
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   ```

3. **Verificar configuración de puerto**:
   - Asegurar que Gunicorn esté escuchando en el puerto correcto (por defecto: 5000)
   - Asegurar que proxy_pass de Nginx coincida con el puerto de Gunicorn

### Problemas con carga de archivos

1. **Verificar permisos del directorio de carga**:
   ```bash
   ls -la static/uploads/
   chmod 755 static/uploads/
   ```

2. **Verificar client_max_body_size de Nginx**:
   - Debe estar configurado a al menos 500M para coincidir con la configuración de Flask

3. **Verificar espacio en disco**:
   ```bash
   df -h
   ```

### Errores de conexión a base de datos

1. **Verificar que PostgreSQL esté corriendo**:
   ```bash
   sudo systemctl status postgresql
   ```

2. **Probar conexión a base de datos**:
   ```bash
   psql -h localhost -U su_usuario_db -d sedes_uneg
   ```

3. **Verificar credenciales en config.py**:
   - Asegurar que todos los nombres de bases de datos, usuarios y contraseñas sean correctos

### Email no se envía

1. **Verificar configuración de email en .env**:
   - Verificar configuración del servidor SMTP
   - Para Gmail, asegurar que las "Contraseñas de Aplicación" estén configuradas

2. **Verificar logs de aplicación**:
   ```bash
   pm2 logs dashboard-unegia | grep -i mail
   ```

3. **Probar conectividad de email**:
   ```bash
   telnet smtp.gmail.com 587
   ```

## Recomendaciones de Seguridad

1. **Nunca hacer commit de archivos sensibles**:
   - `.env` (variables de entorno)
   - `config.py` (credenciales de base de datos)
   - Archivos en `static/uploads/` (datos de usuarios)

2. **Usar claves secretas fuertes**:
   - Actualizar `SECRET_KEY` en `.env`
   - Usar un generador de cadenas aleatorias para producción

3. **Configurar SSL/HTTPS**:
   - Usar Let's Encrypt para certificados SSL gratuitos
   - Descomentar sección HTTPS en nginx.conf.example

4. **Respaldos regulares**:
   - Respaldar bases de datos PostgreSQL regularmente
   - Respaldar archivos subidos por usuarios en `static/uploads/`
   - Usar los scripts automatizados de respaldo (ver [scripts/README_SCRIPTS.md](scripts/README_SCRIPTS.md))

5. **Mantener dependencias actualizadas**:
   ```bash
   pip list --outdated
   pip install --upgrade nombre-paquete
   ```

## Soporte

Para problemas o preguntas:
- Verificar la sección de solución de problemas anterior
- Revisar logs de PM2 y de la aplicación
- Consultar la [Guía de Scripts de Base de Datos](scripts/README_SCRIPTS.md) para problemas relacionados con base de datos
- Contactar al equipo de desarrollo en SISTEMATIZACION-UNEG

## Licencia

Este proyecto es mantenido por UNEG (Universidad Nacional Experimental de Guayana).
