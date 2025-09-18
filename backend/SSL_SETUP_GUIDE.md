# SSL/HTTPS Setup Guide for yondr.me API

This guide covers setting up SSL/HTTPS certificates for the Trekr API on your Liquid Web VPS.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Option 1: Let's Encrypt (Free SSL)](#option-1-lets-encrypt-free-ssl)
3. [Option 2: Commercial SSL Certificate](#option-2-commercial-ssl-certificate)
4. [Nginx SSL Configuration](#nginx-ssl-configuration)
5. [SSL Security Best Practices](#ssl-security-best-practices)
6. [Testing SSL Configuration](#testing-ssl-configuration)
7. [Automatic Certificate Renewal](#automatic-certificate-renewal)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

- Domain `yondr.me` pointing to your Liquid Web VPS IP
- Nginx installed and configured
- Root or sudo access to the server
- Port 80 and 443 open in firewall

## Option 1: Let's Encrypt (Free SSL)

### Step 1: Install Certbot

```bash
# Update system packages
sudo apt update

# Install snapd (if not already installed)
sudo apt install snapd

# Install certbot via snap
sudo snap install --classic certbot

# Create symlink for certbot command
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

### Step 2: Obtain SSL Certificate

```bash
# Stop nginx temporarily
sudo systemctl stop nginx

# Obtain certificate for yondr.me and www.yondr.me
sudo certbot certonly --standalone -d yondr.me -d www.yondr.me

# Follow the prompts:
# - Enter email address for notifications
# - Agree to terms of service
# - Choose whether to share email with EFF
```

### Step 3: Verify Certificate Installation

```bash
# Check certificate files
sudo ls -la /etc/letsencrypt/live/yondr.me/

# You should see:
# - cert.pem (certificate)
# - chain.pem (intermediate certificate)
# - fullchain.pem (certificate + chain)
# - privkey.pem (private key)
```

## Option 2: Commercial SSL Certificate

### Step 1: Generate Certificate Signing Request (CSR)

```bash
# Create directory for SSL files
sudo mkdir -p /etc/ssl/yondr.me

# Generate private key
sudo openssl genrsa -out /etc/ssl/yondr.me/yondr.me.key 2048

# Generate CSR
sudo openssl req -new -key /etc/ssl/yondr.me/yondr.me.key -out /etc/ssl/yondr.me/yondr.me.csr

# Fill in the details:
# Country Name: US
# State: Your State
# City: Your City
# Organization: Your Organization
# Organizational Unit: IT Department
# Common Name: yondr.me
# Email: your-email@domain.com
# Challenge password: (leave blank)
# Optional company name: (leave blank)
```

### Step 2: Purchase and Install Certificate

1. Purchase SSL certificate from a trusted CA (Comodo, DigiCert, etc.)
2. Submit the CSR content to the CA
3. Complete domain validation
4. Download the certificate files
5. Upload certificate files to server:

```bash
# Upload certificate files to server
sudo cp your-certificate.crt /etc/ssl/yondr.me/yondr.me.crt
sudo cp intermediate.crt /etc/ssl/yondr.me/intermediate.crt

# Create full chain certificate
sudo cat /etc/ssl/yondr.me/yondr.me.crt /etc/ssl/yondr.me/intermediate.crt > /etc/ssl/yondr.me/fullchain.crt
```

## Nginx SSL Configuration

### Update Nginx Configuration

Replace the existing nginx.conf with SSL-enabled configuration:

```nginx
# /etc/nginx/sites-available/yondr.me

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name yondr.me www.yondr.me;
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS Server Configuration
server {
    listen 443 ssl http2;
    server_name yondr.me www.yondr.me;
    
    # SSL Certificate Configuration
    # For Let's Encrypt:
    ssl_certificate /etc/letsencrypt/live/yondr.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yondr.me/privkey.pem;
    
    # For Commercial SSL:
    # ssl_certificate /etc/ssl/yondr.me/fullchain.crt;
    # ssl_certificate_key /etc/ssl/yondr.me/yondr.me.key;
    
    # SSL Security Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Security Headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # CORS Headers for API
    add_header Access-Control-Allow-Origin "https://apps.apple.com" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-Requested-With" always;
    add_header Access-Control-Allow-Credentials true always;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;
    
    # API Routes
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health Check
    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }
    
    # WebSocket Support
    location /ws {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Root redirect to App Store
    location = / {
        return 302 https://apps.apple.com/app/trekr/id123456789;
    }
    
    # Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

### Apply Configuration

```bash
# Test nginx configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx

# Enable nginx to start on boot
sudo systemctl enable nginx
```

## SSL Security Best Practices

### 1. Strong SSL Configuration

```bash
# Generate strong DH parameters (this may take a while)
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# Add to nginx configuration:
# ssl_dhparam /etc/ssl/certs/dhparam.pem;
```

### 2. OCSP Stapling

Add to your nginx SSL server block:

```nginx
# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/yondr.me/chain.pem;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
```

### 3. Security Headers

Already included in the configuration above:
- HSTS (HTTP Strict Transport Security)
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer-Policy

## Testing SSL Configuration

### 1. Basic SSL Test

```bash
# Test SSL certificate
openssl s_client -connect yondr.me:443 -servername yondr.me

# Check certificate expiration
openssl s_client -connect yondr.me:443 -servername yondr.me 2>/dev/null | openssl x509 -noout -dates
```

### 2. Online SSL Tests

- **SSL Labs Test**: https://www.ssllabs.com/ssltest/
- **Security Headers**: https://securityheaders.com/
- **Mozilla Observatory**: https://observatory.mozilla.org/

### 3. API Endpoint Tests

```bash
# Test API over HTTPS
curl -X GET https://yondr.me/api/health

# Test with authentication
curl -X POST https://yondr.me/api/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

## Automatic Certificate Renewal

### Let's Encrypt Auto-Renewal

```bash
# Test renewal process
sudo certbot renew --dry-run

# Set up automatic renewal (crontab)
sudo crontab -e

# Add this line to run renewal check twice daily:
0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

### Commercial Certificate Renewal

Set up monitoring for certificate expiration:

```bash
# Create renewal reminder script
sudo nano /usr/local/bin/ssl-check.sh
```

```bash
#!/bin/bash
# SSL Certificate Expiration Check

DOMAIN="yondr.me"
CERT_FILE="/etc/ssl/yondr.me/yondr.me.crt"
DAYS_WARNING=30

if [ -f "$CERT_FILE" ]; then
    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -le $DAYS_WARNING ]; then
        echo "WARNING: SSL certificate for $DOMAIN expires in $DAYS_LEFT days!"
        # Send email notification here if configured
    fi
fi
```

```bash
# Make script executable
sudo chmod +x /usr/local/bin/ssl-check.sh

# Add to crontab to run daily
sudo crontab -e
# Add: 0 9 * * * /usr/local/bin/ssl-check.sh
```

## Troubleshooting

### Common Issues

1. **Certificate not found**
   ```bash
   # Check certificate files exist
   sudo ls -la /etc/letsencrypt/live/yondr.me/
   ```

2. **Permission denied**
   ```bash
   # Fix certificate permissions
   sudo chmod 644 /etc/letsencrypt/live/yondr.me/fullchain.pem
   sudo chmod 600 /etc/letsencrypt/live/yondr.me/privkey.pem
   ```

3. **Nginx fails to start**
   ```bash
   # Check nginx error logs
   sudo tail -f /var/log/nginx/error.log
   
   # Test configuration
   sudo nginx -t
   ```

4. **Certificate validation fails**
   ```bash
   # Ensure domain points to server
   dig yondr.me
   
   # Check firewall
   sudo ufw status
   ```

### Log Files

- Nginx error log: `/var/log/nginx/error.log`
- Nginx access log: `/var/log/nginx/access.log`
- Let's Encrypt log: `/var/log/letsencrypt/letsencrypt.log`
- System log: `/var/log/syslog`

## Security Checklist

- [ ] SSL certificate installed and valid
- [ ] HTTP redirects to HTTPS
- [ ] Strong SSL ciphers configured
- [ ] HSTS header enabled
- [ ] Security headers configured
- [ ] OCSP stapling enabled (optional)
- [ ] Certificate auto-renewal configured
- [ ] Firewall configured (ports 80, 443 open)
- [ ] Regular security updates scheduled
- [ ] SSL configuration tested with SSL Labs

## Next Steps

After SSL is configured:

1. Update iOS app to use HTTPS endpoints
2. Test all API functionality over HTTPS
3. Monitor SSL certificate expiration
4. Set up monitoring and alerting
5. Consider implementing additional security measures

## Support

For issues with SSL setup:
- Check Liquid Web documentation
- Contact Liquid Web support
- Review Let's Encrypt documentation
- Check nginx SSL documentation