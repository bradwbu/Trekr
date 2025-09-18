# Trekr API Backend

Backend API for the Trekr location tracking iOS app, designed for deployment on Liquid Web hosting with yondr.me domain.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ 
- MongoDB Atlas account (recommended) or local MongoDB
- Liquid Web VPS/Dedicated server
- Domain: yondr.me configured

### Local Development
```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
nano .env

# Start development server
npm run dev
```

## 🌐 Production Deployment on Liquid Web

### 1. Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Install Nginx (if not already installed)
sudo apt install nginx -y

# Install Git
sudo apt install git -y
```

### 2. Database Setup (MongoDB Atlas - Recommended)
1. Create account at [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Create a new cluster
3. Create database user
4. Whitelist your server IP
5. Get connection string and update `.env.production`

### 3. Deploy Application
```bash
# Clone repository to your server
git clone https://github.com/bradwbu/Trekr /var/www/trekr-api
cd /var/www/trekr-api/backend

# Make deploy script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh production
```

### 4. Domain Configuration
Configure your DNS at your domain registrar:
```
A Record: api.yondr.me → Your Server IP
```

### 5. SSL Certificate Setup
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d api.yondr.me

# Auto-renewal (already configured by certbot)
sudo crontab -l | grep certbot
```

## 📡 API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `GET /api/auth/me` - Get current user
- `POST /api/auth/refresh` - Refresh token

### Locations
- `POST /api/locations/update` - Update user location
- `GET /api/locations/shared` - Get shared locations
- `POST /api/locations/share` - Share/unshare location
- `GET /api/locations/history` - Get location history

### Health Check
- `GET /api/health` - Server health status

## 🔧 Configuration

### Environment Variables (.env.production)
```bash
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/trekr
JWT_SECRET=your-super-secure-secret
ALLOWED_ORIGINS=https://yondr.me,https://api.yondr.me
```

### PM2 Configuration
The app uses PM2 for process management with clustering enabled for better performance.

```bash
# View running processes
pm2 list

# Monitor performance
pm2 monit

# View logs
pm2 logs trekr-api

# Restart app
pm2 restart trekr-api
```

## 🔒 Security Features

- JWT authentication with secure tokens
- Rate limiting (100 requests per 15 minutes)
- CORS protection
- Helmet.js security headers
- Input validation with express-validator
- Password hashing with bcrypt
- HTTPS enforcement

## 📊 Monitoring & Logs

### Application Logs
- Location: `/var/log/trekr/`
- Rotation: Daily, kept for 52 days
- Access via: `pm2 logs trekr-api`

### Health Monitoring
- Endpoint: `https://api.yondr.me/api/health`
- PM2 monitoring: `pm2 monit`

## 🔄 Updates & Maintenance

### Deploying Updates
```bash
# Pull latest changes
git pull origin main

# Redeploy
./deploy.sh production
```

### Database Backup (MongoDB Atlas)
MongoDB Atlas provides automatic backups. For manual backups:
```bash
# Using mongodump (if needed)
mongodump --uri="your-mongodb-uri" --out=/backup/$(date +%Y%m%d)
```

## 🆘 Troubleshooting

### Common Issues

1. **App won't start**
   ```bash
   pm2 logs trekr-api
   # Check for missing environment variables or database connection issues
   ```

2. **SSL Certificate Issues**
   ```bash
   sudo certbot renew --dry-run
   sudo nginx -t
   ```

3. **Database Connection**
   ```bash
   # Test MongoDB connection
   node -e "require('mongoose').connect(process.env.MONGODB_URI).then(() => console.log('Connected')).catch(console.error)"
   ```

4. **Port Already in Use**
   ```bash
   sudo lsof -i :3000
   pm2 kill
   pm2 start ecosystem.config.js --env production
   ```

## 📞 Support

For deployment issues specific to Liquid Web, contact their support team. For application issues, check the logs and ensure all environment variables are properly configured.

## 🔐 Security Checklist

- [ ] SSL certificate installed and auto-renewing
- [ ] Firewall configured (only ports 22, 80, 443 open)
- [ ] Strong JWT secret in production
- [ ] MongoDB Atlas IP whitelist configured
- [ ] Regular security updates scheduled
- [ ] Log monitoring set up
- [ ] Backup strategy implemented