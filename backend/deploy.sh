#!/bin/bash

# Trekr API Deployment Script for Liquid Web
# Usage: ./deploy.sh [production|staging]

set -e

ENVIRONMENT=${1:-production}
APP_NAME="trekr-api"
APP_DIR="/var/www/$APP_NAME"
BACKUP_DIR="/var/backups/$APP_NAME"
LOG_DIR="/var/log/trekr"

echo "🚀 Starting deployment for $ENVIRONMENT environment..."

# Create necessary directories
echo "📁 Creating directories..."
sudo mkdir -p $APP_DIR
sudo mkdir -p $BACKUP_DIR
sudo mkdir -p $LOG_DIR
sudo chown -R $USER:$USER $APP_DIR
sudo chown -R $USER:$USER $LOG_DIR

# Backup current deployment if it exists
if [ -d "$APP_DIR/current" ]; then
    echo "💾 Creating backup..."
    sudo cp -r $APP_DIR/current $BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)
fi

# Create new deployment directory
DEPLOY_DIR="$APP_DIR/releases/$(date +%Y%m%d-%H%M%S)"
mkdir -p $DEPLOY_DIR

echo "📦 Copying application files..."
cp -r . $DEPLOY_DIR/
cd $DEPLOY_DIR

# Install dependencies
echo "📚 Installing dependencies..."
npm ci --production

# Copy environment file
echo "⚙️  Setting up environment..."
if [ "$ENVIRONMENT" = "production" ]; then
    cp .env.production .env
else
    cp .env.example .env
fi

# Create symlink to current
echo "🔗 Creating symlink..."
rm -f $APP_DIR/current
ln -sf $DEPLOY_DIR $APP_DIR/current

# Install PM2 if not already installed
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installing PM2..."
    sudo npm install -g pm2
fi

# Start or restart the application
echo "🔄 Starting application..."
cd $APP_DIR/current

if pm2 list | grep -q $APP_NAME; then
    echo "♻️  Restarting existing application..."
    pm2 restart ecosystem.config.js --env $ENVIRONMENT
else
    echo "🆕 Starting new application..."
    pm2 start ecosystem.config.js --env $ENVIRONMENT
fi

# Save PM2 configuration
pm2 save
pm2 startup

# Setup log rotation
echo "📝 Setting up log rotation..."
sudo tee /etc/logrotate.d/trekr > /dev/null <<EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# Clean up old releases (keep last 5)
echo "🧹 Cleaning up old releases..."
cd $APP_DIR/releases
ls -t | tail -n +6 | xargs -r rm -rf

# Setup nginx configuration (if nginx is installed)
if command -v nginx &> /dev/null; then
    echo "🌐 Setting up Nginx configuration..."
    sudo tee /etc/nginx/sites-available/trekr-api > /dev/null <<EOF
server {
    listen 80;
    server_name api.yondr.me;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yondr.me;
    
    # SSL configuration (you'll need to add your SSL certificates)
    ssl_certificate /etc/ssl/certs/yondr.me.crt;
    ssl_certificate_key /etc/ssl/private/yondr.me.key;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Proxy to Node.js app
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /api/health {
        proxy_pass http://localhost:3000/api/health;
        access_log off;
    }
}
EOF
    
    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/trekr-api /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    sudo nginx -t && sudo systemctl reload nginx
fi

echo "✅ Deployment completed successfully!"
echo "🌐 API should be available at: https://api.yondr.me"
echo "📊 Monitor with: pm2 monit"
echo "📋 View logs with: pm2 logs $APP_NAME"