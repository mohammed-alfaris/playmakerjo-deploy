# PlayMaker JO — Deployment Guide

## Prerequisites
- VPS with Ubuntu 22.04+ (1 vCPU, 1GB RAM minimum)
- Domain: `playmakerjo.com` with DNS A records:
  - `playmakerjo.com` -> server IP
  - `www.playmakerjo.com` -> server IP
  - `api.playmakerjo.com` -> server IP
  - `admin.playmakerjo.com` -> server IP

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

The platform lives in **4 GitHub repos** — one deploy repo + three source repos.
Clone all four side-by-side into `/opt/playmakerjo`:

```bash
sudo mkdir -p /opt/playmakerjo
sudo chown $USER:$USER /opt/playmakerjo
cd /opt/playmakerjo

# 1. Deploy configs (this repo — docker-compose, nginx, .env.example)
git clone https://github.com/mohammed-alfaris/playmakerjo-deploy.git .

# 2. Backend API source
git clone https://github.com/mohammed-alfaris/playmakerjo-api.git playmakerjo-api

# 3. Admin dashboard source
git clone https://github.com/mohammed-alfaris/playmakerjo-dashboard.git playmakerjo-dashboard

# 4. Marketing website source
git clone https://github.com/mohammed-alfaris/playmakerjo-website.git playmakerjo-website

# Final directory structure should be:
#   /opt/playmakerjo/
#   ├── docker-compose.yml
#   ├── nginx-server.conf
#   ├── .env.example
#   ├── playmakerjo-api/         (cloned)
#   ├── playmakerjo-dashboard/   (cloned)
#   └── playmakerjo-website/     (cloned)
# The Flutter app (playmakerjo-app) is NOT deployed on the server —
# users install the APK/IPA on their phones.

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
UPLOADS_BASE_URL=https://api.playmakerjo.com
CORS_ORIGINS=https://admin.playmakerjo.com
```

---

## Step 3: Firebase Credentials

```bash
# Copy firebase-credentials.json to the API directory
# Run this from your LOCAL machine (not the server)
scp firebase-credentials.json user@server:/opt/playmakerjo/playmakerjo-api/SportsVenueApi/firebase-credentials.json
```

> ⚠️ The API container will fail to start without this file. Get it from Firebase Console → Project Settings → Service Accounts → Generate new private key.

---

## Step 4: Nginx + SSL

```bash
# Copy Nginx config
sudo cp nginx-server.conf /etc/nginx/sites-available/playmakerjo
sudo ln -sf /etc/nginx/sites-available/playmakerjo /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
# Existing servers: the file used to be named "yallanhjez" — mv it (and re-link) or remove the old symlink

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificates (after DNS is pointing to server)
sudo certbot --nginx -d playmakerjo.com -d www.playmakerjo.com -d api.playmakerjo.com -d admin.playmakerjo.com
```

---

## Step 5: Deploy

```bash
cd /opt/playmakerjo

# Build and start all services
docker compose up -d --build

# Check all services are running
docker compose ps

# View logs
docker compose logs -f api       # API logs
docker compose logs -f mysql     # MySQL logs
docker compose logs -f dashboard # Dashboard logs

# Seed the database (first time only)
# ⚠️ Seeding creates demo logins with the dev passwords from SECRETS.md —
# change the super_admin password immediately after seeding production.
docker compose exec api dotnet SportsVenueApi.dll --seed
```

---

## Step 6: Verify

1. **API Health**: `curl https://api.playmakerjo.com/health`
2. **Dashboard**: Open `https://admin.playmakerjo.com` in browser
3. **Login**: Use admin credentials on the dashboard
4. **Mobile**: Build APK and test on mobile data:
   ```bash
   cd playmakerjo-app
   flutter build apk --release --dart-define=API_BASE_URL=https://api.playmakerjo.com/api/v1
   ```

---

## Step 7: Backups (required)

```bash
# Make backup script executable
chmod +x /opt/playmakerjo/backup-db.sh

# Test it
export MYSQL_ROOT_PASSWORD=<your-password>
/opt/playmakerjo/backup-db.sh

# Add to cron (daily at 3 AM, with offsite copy — see "Offsite backups" in the hardening runbook)
(crontab -l 2>/dev/null; echo "0 3 * * * MYSQL_ROOT_PASSWORD=<your-password> RCLONE_REMOTE=b2:playmakerjo-backups /opt/playmakerjo/backup-db.sh >> /var/log/playmakerjo-backup.log 2>&1") | crontab -
```

---

## Server hardening (one-time runbook)

Run these once on the production server, in order.

### 1. Swap (2GB)

A 1GB box OOMs during docker builds — add swap first.

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. Firewall (ufw)

> ⚠️ Keep your current SSH session open until you've confirmed a NEW session can connect.

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

> Note: Docker publishes ports via iptables and **bypasses ufw** — ufw alone does NOT block ports published by docker compose. The `127.0.0.1:` bindings in `docker-compose.yml` are what actually closes 3306/8000/3000/3001 to the internet.

### 3. Automatic security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 4. MySQL app user (existing volume)

The `MYSQL_USER`/`MYSQL_PASSWORD` env vars in docker-compose.yml only apply on **first** volume init — on an existing server, create the user manually:

```bash
# Generate a password and save it
openssl rand -base64 32

# Create the user inside the running container (enter the root password when prompted)
docker compose exec mysql mysql -uroot -p
```

```sql
CREATE USER IF NOT EXISTS 'playmaker'@'%' IDENTIFIED BY '<generated-password>';
GRANT ALL PRIVILEGES ON sportsvenue.* TO 'playmaker'@'%';
FLUSH PRIVILEGES;
```

```bash
# Add to /opt/playmakerjo/.env
echo "MYSQL_APP_PASSWORD=<generated-password>" >> /opt/playmakerjo/.env

# Pull the updated compose config and restart
cd /opt/playmakerjo
git pull
docker compose up -d

# Watch the API come back healthy
curl https://api.playmakerjo.com/health
```

> Rollback: if the API can't connect, revert `User=playmaker;Password=${MYSQL_APP_PASSWORD}` in the compose connection string to `User=root;Password=${MYSQL_ROOT_PASSWORD}` and `docker compose up -d` again.

### 5. Verify

```bash
# All port binds should show 127.0.0.1 (and mysql should publish nothing)
docker compose ps

# From an OUTSIDE machine — these must FAIL (timeout / connection refused):
nc -zv <server-ip> 3306
nc -zv <server-ip> 8000

# The https endpoints must still work:
curl https://api.playmakerjo.com/health
curl -I https://admin.playmakerjo.com
curl -I https://playmakerjo.com
```

### 6. Offsite backups (rclone)

```bash
sudo apt install -y rclone

# Configure a remote — for Backblaze B2 follow https://rclone.org/b2/
rclone config

# Test run
export MYSQL_ROOT_PASSWORD=<your-password>
export RCLONE_REMOTE=b2:playmakerjo-backups
/opt/playmakerjo/backup-db.sh
rclone ls b2:playmakerjo-backups/playmakerjo-db
```

Then install the crontab line from Step 7 (it includes `RCLONE_REMOTE`).

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
2. Add monitor: `https://api.playmakerjo.com/health` (HTTP, 5 min interval)
3. Add alert contact: your email/phone
