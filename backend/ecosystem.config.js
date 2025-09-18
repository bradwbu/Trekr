module.exports = {
  apps: [{
    name: 'trekr-api',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    // Logging
    log_file: '/var/log/trekr/combined.log',
    out_file: '/var/log/trekr/out.log',
    error_file: '/var/log/trekr/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    
    // Auto restart configuration
    watch: false,
    ignore_watch: ['node_modules', 'logs'],
    max_memory_restart: '1G',
    
    // Advanced features
    min_uptime: '10s',
    max_restarts: 10,
    autorestart: true,
    
    // Environment variables file
    env_file: '.env.production'
  }],

  deploy: {
    production: {
      user: 'your-username',
      host: 'your-server-ip-or-domain',
      ref: 'origin/main',
      repo: 'git@github.com:yourusername/trekr-backend.git',
      path: '/var/www/trekr-api',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
      'pre-setup': ''
    }
  }
};