# YallaNhjez — Deployment Guide

## Prerequisites
- VPS with Ubuntu 22.04+ (1 vCPU, 1GB RAM minimum)
- Domain: `yallanhjez.com` with DNS A records:
  - `api.yallanhjez.com` -> server IP
  - `admin.yallanhjez.com` -> server IP

---

## Step 1: Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change

# Install Docker Compose (if not included)
sudo apt install -y docker-compose-plugin

# Install Nginx + Certbot
sudo apt install -y nginx certbot python3-certbot-nginx
```

---

## Step 2: Clone and Configure

```bash
# Clone the repo
cd /opt
sudo git clone https://github.com/YOUR_USERNAME/YallaNhjez.git yallanhjez
cd yallanhjez

# Create .env from template
cp .env.example .env

# Generate secure values and edit .env
openssl rand -base64 32   # Use output for MYSQL_ROOT_PASSWORD
openssl rand -base64 48   # Use output for JWT_SECRET_KEY
nano .env
```

**.env** should look like:
```env
MYSQL_ROOT_PASSWORD=<your-generated-password>
JWT_SECRET_KEY=<your-generated-key>
UPLOADS_BASE_URL=https://api.yallanhjez.com
CORS_ORIGINS=https://admin.yallanhjez.com
```

---

## Step 3: Firebase Credentials

```bash
# Copy firebase-credentials.json to the API directory
scp firebase-credentials.json user@server:/opt/yallanhjez/sports-venue-api/SportsVenueApi/firebase-credentials.json
```

---

## Step 4: Nginx + SSL

```bash
# Copy Nginx config
sudo cp nginx-server.conf /etc/nginx/sites-available/yallanhjez
sudo ln -sf /etc/nginx/sites-available/yallanhjez /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificates (after DNS is pointing to server)
sudo certbot --nginx -d api.yallanhjez.com -d admin.yallanhjez.com
```

---

## Step 5: Deploy

```bash
cd /opt/yallanhjez

# Build and start all services
docker compose up -d --build

# Check all services are running
docker compose ps

# View logs
docker compose logs -f api       # API logs
docker compose logs -f mysql     # MySQL logs
docker compose logs -f dashboard # Dashboard logs

# Seed the database (first time only)
docker compose exec api dotnet SportsVenueApi.dll --seed
```

---

## Step 6: Verify

1. **API Health**: `curl https://api.yallanhjez.com/health`
2. **Dashboard**: Open `https://admin.yallanhjez.com` in browser
3. **Login**: Use admin credentials on the dashboard
4. **Mobile**: Build APK and test on mobile data:
   ```bash
   cd yalla-nhjez-app
   flutter build apk --release --dart-define=API_BASE_URL=https://api.yallanhjez.com/api/v1
   ```

---

## Step 7: Backups (optional)

```bash
# Make backup script executable
chmod +x /opt/yallanhjez/backup-db.sh

# Test it
export MYSQL_ROOT_PASSWORD=<your-password>
/opt/yallanhjez/backup-db.sh

# Add to cron (daily at 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * * MYSQL_ROOT_PASSWORD=<your-password> /opt/yallanhjez/backup-db.sh >> /var/log/yallanhjez-backup.log 2>&1") | crontab -
```

---

## Common Operations

```bash
# Restart all services
docker compose restart

# Restart just the API
docker compose restart api

# Update code and redeploy
git pull
docker compose up -d --build

# View real-time API logs
docker compose logs -f api

# Access MySQL shell
docker compose exec mysql mysql -u root -p sportsvenue

# Restore from backup
gunzip < backups/sportsvenue_2026-04-15_0300.sql.gz | docker compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" sportsvenue
```

---

## Monitoring

Set up **UptimeRobot** (free):
1. Go to https://uptimerobot.com
2. Add monitor: `https://api.yallanhjez.com/health` (HTTP, 5 min interval)
3. Add alert contact: your email/phone
