# Dashboard UNEGIA

Flask-based dashboard application for managing infrastructure reports at Universidad Nacional Experimental de Guayana (UNEG).

## Project Overview

This web application allows users to:
- Report infrastructure issues across different categories (electrical, plumbing, refrigeration, security, infrastructure, furniture, supplies, and technology)
- Upload photos and descriptions of issues
- Track report status via email notifications
- View admin dashboards with comprehensive reporting analytics
- Manage reports across multiple campus locations

## Features

- **Multi-category reporting system**: 8 categories for different types of infrastructure issues
- **Photo upload support**: Upload images up to 500MB
- **Email notifications**: Automated email notifications with confirmation tracking
- **Admin dashboard**: Comprehensive analytics and reporting views
- **Multi-database architecture**: Separate databases for sedes, categories, reports, and departments

## Prerequisites

Before deploying this application, ensure you have the following installed on your server:

- **Python**: 3.8 or higher
- **PostgreSQL**: 12 or higher (with 4 separate databases configured)
- **PM2**: Process manager for Node.js applications
- **Nginx**: Web server and reverse proxy
- **Git**: For cloning the repository
- **pip**: Python package manager

### System Setup

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Python and pip
sudo apt install python3 python3-pip python3-venv -y

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Install Nginx
sudo apt install nginx -y

# Install Node.js and PM2
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install nodejs -y
sudo npm install -g pm2
```

## Installation & Deployment

### 1. Clone the Repository

```bash
cd /path/to/your/projects
git clone https://github.com/SISTEMATIZACION-UNEG/dashboard_unegia.git
cd dashboard_unegia
```

### 2. Create and Activate Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Verify activation (should show path to venv/bin/python)
which python
```

### 3. Install Dependencies

```bash
# Install all required packages
pip install -r requirements.txt

# Verify installation
pip list
```

### 4. Configure Environment Variables

Create a `.env` file in the project root with your configuration:

```bash
# Copy the example file if available, or create new
touch .env
```

Add the following variables to your `.env` file:

```env
# Email Configuration
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=True
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-specific-password

# Flask Configuration
FLASK_ENV=production
SECRET_KEY=your-secret-key-here-change-this
```

### 5. Configure Database Connection

Create a `config.py` file with your database credentials:

```python
DATABASES = {
    "sedes_uneg": {
        "host": "localhost",
        "database": "sedes_uneg",
        "user": "your_db_user",
        "password": "your_db_password",
        "port": 5432
    },
    "categorias_fallas": {
        "host": "localhost",
        "database": "categorias_fallas",
        "user": "your_db_user",
        "password": "your_db_password",
        "port": 5432
    },
    "reportes_generales": {
        "host": "localhost",
        "database": "reportes_generales",
        "user": "your_db_user",
        "password": "your_db_password",
        "port": 5432
    },
    "departamentos_db": {
        "host": "localhost",
        "database": "departamentos_db",
        "user": "your_db_user",
        "password": "your_db_password",
        "port": 5432
    }
}
```

**Important**: Never commit this file to version control. It's already listed in `.gitignore`.

### 6. Set Up Database Tables

Ensure your PostgreSQL databases have the required tables. Connect to each database and create necessary tables:

```sql
-- Example for reportes_generales database
CREATE TABLE reportes (
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
    fecha_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Additional tables for other databases...
```

### 7. Create Logs Directory

```bash
# Create directory for PM2 logs
mkdir -p logs
```

### 8. Configure PM2

The `ecosystem.config.js` file is already configured. Update the `cwd` path if your installation directory differs:

```bash
# Edit ecosystem.config.js and update the cwd path to match your installation
nano ecosystem.config.js
```

Start the application with PM2:

```bash
# Start the application
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Set PM2 to start on system boot
pm2 startup
# Follow the instructions provided by the command above
```

### 9. Configure Nginx

Copy the example Nginx configuration:

```bash
# Copy the example configuration
sudo cp nginx.conf.example /etc/nginx/sites-available/dashboard-unegia

# Edit the configuration file
sudo nano /etc/nginx/sites-available/dashboard-unegia
```

Update the following in the Nginx configuration:
- `server_name`: Replace with your domain or server IP
- Static files path: Ensure it matches your installation directory
- Proxy settings: Verify the port matches your Gunicorn configuration (default: 5000)

Enable the site:

```bash
# Create symbolic link to enable the site
sudo ln -s /etc/nginx/sites-available/dashboard-unegia /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### 10. Configure Firewall (if applicable)

```bash
# Allow HTTP and HTTPS traffic
sudo ufw allow 'Nginx Full'

# Check firewall status
sudo ufw status
```

## Managing the Application

### PM2 Commands

```bash
# View application status
pm2 status

# View application logs
pm2 logs dashboard-unegia

# View only error logs
pm2 logs dashboard-unegia --err

# View only output logs
pm2 logs dashboard-unegia --out

# Restart the application
pm2 restart dashboard-unegia

# Stop the application
pm2 stop dashboard-unegia

# Start the application
pm2 start dashboard-unegia

# Delete the application from PM2
pm2 delete dashboard-unegia

# Monitor application in real-time
pm2 monit
```

### Nginx Commands

```bash
# Check Nginx status
sudo systemctl status nginx

# Start Nginx
sudo systemctl start nginx

# Stop Nginx
sudo systemctl stop nginx

# Restart Nginx
sudo systemctl restart nginx

# Reload Nginx configuration
sudo systemctl reload nginx

# Test Nginx configuration
sudo nginx -t
```

### Application Updates

To deploy updates:

```bash
# Navigate to project directory
cd /path/to/your/dashboard_unegia

# Pull latest changes
git pull origin main

# Activate virtual environment
source venv/bin/activate

# Install any new dependencies
pip install -r requirements.txt

# Restart the application
pm2 restart dashboard-unegia

# Monitor for any issues
pm2 logs dashboard-unegia
```

## Project Structure

```
dashboard_unegia/
├── app.py                    # Main Flask application
├── conexion.py              # Database connection handlers
├── dashboard_router.py      # Dashboard blueprint and routes
├── config.py               # Database configuration (not in repo)
├── .env                    # Environment variables (not in repo)
├── requirements.txt        # Python dependencies
├── ecosystem.config.js     # PM2 configuration
├── nginx.conf.example      # Nginx configuration example
├── static/                 # Static files (CSS, JS, images)
│   ├── dashboard/         # Dashboard assets
│   └── uploads/           # User-uploaded files
├── templates/             # HTML templates
│   └── paginas/          # Application pages
├── logs/                 # Application logs (created at runtime)
└── venv/                # Virtual environment (not in repo)
```

## Troubleshooting

### Application won't start

1. **Check PM2 logs**:
   ```bash
   pm2 logs dashboard-unegia
   ```

2. **Verify virtual environment**:
   ```bash
   source venv/bin/activate
   which python
   pip list
   ```

3. **Check database connections**:
   - Verify PostgreSQL is running: `sudo systemctl status postgresql`
   - Test database credentials in `config.py`
   - Check if all 4 databases exist and are accessible

4. **Verify environment variables**:
   ```bash
   cat .env
   ```

### 502 Bad Gateway error

1. **Check if Gunicorn is running**:
   ```bash
   pm2 status
   ps aux | grep gunicorn
   ```

2. **Check Nginx configuration**:
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   ```

3. **Verify port configuration**:
   - Ensure Gunicorn is listening on the correct port (default: 5000)
   - Ensure Nginx proxy_pass matches the Gunicorn port

### File upload issues

1. **Check upload directory permissions**:
   ```bash
   ls -la static/uploads/
   chmod 755 static/uploads/
   ```

2. **Verify Nginx client_max_body_size**:
   - Should be set to at least 500M to match Flask configuration

3. **Check disk space**:
   ```bash
   df -h
   ```

### Database connection errors

1. **Verify PostgreSQL is running**:
   ```bash
   sudo systemctl status postgresql
   ```

2. **Test database connection**:
   ```bash
   psql -h localhost -U your_db_user -d sedes_uneg
   ```

3. **Check config.py credentials**:
   - Ensure all database names, users, and passwords are correct

### Email not sending

1. **Check email configuration in .env**:
   - Verify SMTP server settings
   - For Gmail, ensure "App Passwords" are configured

2. **Check application logs**:
   ```bash
   pm2 logs dashboard-unegia | grep -i mail
   ```

3. **Test email connectivity**:
   ```bash
   telnet smtp.gmail.com 587
   ```

## Security Recommendations

1. **Never commit sensitive files**:
   - `.env` (environment variables)
   - `config.py` (database credentials)
   - Files in `static/uploads/` (user data)

2. **Use strong secret keys**:
   - Update `SECRET_KEY` in `.env`
   - Use a random string generator for production

3. **Set up SSL/HTTPS**:
   - Use Let's Encrypt for free SSL certificates
   - Uncomment HTTPS section in nginx.conf.example

4. **Regular backups**:
   - Back up PostgreSQL databases regularly
   - Back up user uploads in `static/uploads/`

5. **Keep dependencies updated**:
   ```bash
   pip list --outdated
   pip install --upgrade package-name
   ```

## Support

For issues or questions:
- Check the troubleshooting section above
- Review PM2 and application logs
- Contact the development team at SISTEMATIZACION-UNEG

## License

This project is maintained by UNEG (Universidad Nacional Experimental de Guayana).
