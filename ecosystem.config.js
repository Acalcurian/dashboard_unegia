module.exports = {
  apps: [{
    name: 'dashboard-unegia',
    script: 'gunicorn',
    args: '-w 4 -b 127.0.0.1:5000 app:app',
    interpreter: 'venv/bin/python',
    cwd: '/path/to/your/dashboard_unegia',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true
  }]
};
