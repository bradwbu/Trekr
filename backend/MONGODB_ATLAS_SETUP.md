# MongoDB Atlas Setup Guide for Trekr App

This guide will walk you through setting up MongoDB Atlas for your Trekr app's cloud database.

## 1. Create MongoDB Atlas Account

1. Go to [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Click "Try Free" or "Sign Up"
3. Create your account with email/password or Google/GitHub

## 2. Create a New Cluster

### Step 1: Choose Deployment Type
- Select **"Shared"** for free tier (M0 Sandbox)
- Or **"Dedicated"** for production (M10+ recommended)

### Step 2: Cloud Provider & Region
- **Provider**: AWS (recommended for Liquid Web compatibility)
- **Region**: Choose closest to your Liquid Web server location
  - US East (N. Virginia) - `us-east-1`
  - US West (Oregon) - `us-west-2`
  - Europe (Ireland) - `eu-west-1`

### Step 3: Cluster Configuration
- **Cluster Name**: `trekr-production`
- **MongoDB Version**: 7.0 (latest stable)
- **Storage**: Auto-scaling enabled (for paid tiers)

## 3. Configure Database Security

### Step 1: Create Database User
1. Go to **Database Access** in left sidebar
2. Click **"Add New Database User"**
3. Authentication Method: **Password**
4. Username: `trekr-api`
5. Password: Generate a strong password (save this!)
6. Database User Privileges: **"Read and write to any database"**
7. Click **"Add User"**

### Step 2: Configure Network Access
1. Go to **Network Access** in left sidebar
2. Click **"Add IP Address"**
3. For development: **"Add Current IP Address"**
4. For production: Add your Liquid Web server IP
   - Get your server IP from Liquid Web control panel
   - Add IP with description: "Liquid Web Server"
5. Click **"Confirm"**

## 4. Get Connection String

1. Go to **Database** in left sidebar
2. Click **"Connect"** on your cluster
3. Choose **"Connect your application"**
4. Driver: **Node.js**
5. Version: **4.1 or later**
6. Copy the connection string (looks like):
   ```
   mongodb+srv://trekr-api:<password>@trekr-production.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```

## 5. Configure Environment Variables

### For Development (.env)
Create a `.env` file in your backend directory:
```bash
# Database
MONGODB_URI=mongodb+srv://trekr-api:<password>@trekr-production.xxxxx.mongodb.net/trekr-dev?retryWrites=true&w=majority
DB_NAME=trekr-dev
```

### For Production (.env.production)
Update your existing `.env.production` file:
```bash
# Database
MONGODB_URI=mongodb+srv://trekr-api:<password>@trekr-production.xxxxx.mongodb.net/trekr-prod?retryWrites=true&w=majority
DB_NAME=trekr-prod
```

**Important**: Replace `<password>` with your actual database user password!

## 6. Database Structure

Your app will automatically create these collections:
- `users` - User accounts and preferences
- `routes` - Saved location routes and tracking data
- `sessions` - User authentication sessions (optional)

## 7. Test Connection

Run this command in your backend directory to test the connection:

```bash
# Install dependencies first
npm install

# Test connection
node -e "
const mongoose = require('mongoose');
require('dotenv').config();
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('✅ MongoDB Atlas connected successfully!'))
  .catch(err => console.error('❌ Connection failed:', err))
  .finally(() => process.exit());
"
```

## 8. Production Recommendations

### Security
- **Enable Authentication**: Always use database users with strong passwords
- **IP Whitelist**: Only allow your server IPs
- **Connection Encryption**: Always use SSL (enabled by default)
- **Regular Backups**: Enable automated backups

### Performance
- **Indexes**: The app will create necessary indexes automatically
- **Connection Pooling**: Configured in server.js
- **Monitoring**: Enable MongoDB Atlas monitoring

### Scaling
- **Cluster Tier**: Start with M10 for production
- **Auto-scaling**: Enable storage and compute auto-scaling
- **Read Replicas**: Add for high-traffic applications

## 9. Monitoring & Alerts

1. Go to **Alerts** in MongoDB Atlas
2. Set up alerts for:
   - High CPU usage (>80%)
   - High memory usage (>80%)
   - Connection count (>80% of limit)
   - Slow queries (>100ms)

## 10. Backup Configuration

1. Go to **Backup** tab in your cluster
2. Enable **Continuous Backup** (recommended)
3. Set retention period (7 days minimum)
4. Configure backup schedule

## Troubleshooting

### Common Issues

**Connection Timeout**
- Check IP whitelist in Network Access
- Verify connection string format
- Ensure firewall allows outbound connections on port 27017

**Authentication Failed**
- Verify username/password in connection string
- Check database user permissions
- Ensure special characters in password are URL-encoded

**DNS Resolution**
- Use connection string with `+srv` format
- Check if your server can resolve MongoDB Atlas hostnames

### Support Resources
- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [Connection Troubleshooting](https://docs.atlas.mongodb.com/troubleshoot-connection/)
- [MongoDB University](https://university.mongodb.com/) - Free courses

## Next Steps

After completing this setup:
1. ✅ MongoDB Atlas configured
2. 🔄 Update iOS app to use yondr.me API
3. 🚀 Deploy to Liquid Web server
4. 🔒 Configure SSL certificates
5. 📱 Test end-to-end functionality

---

**Security Note**: Never commit your actual MongoDB connection string or passwords to version control. Always use environment variables!