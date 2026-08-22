#!/bin/bash
# ==========================================================
# RADIUS-UI SECURE INSTALLER SCRIPT
# Run this on a fresh Ubuntu 22.04 / 20.04 server as root
# ==========================================================

INSTALL_DIR=$(pwd)
set -e

echo "=========================================================="
echo "RADIUS-UI SECURE AUTOMATED INSTALLER"
echo "=========================================================="

echo "[1/8] Updating system and installing basic dependencies..."
apt-get update && apt-get upgrade -y
apt-get install -y curl wget git build-essential unzip

echo "[2/8] Installing MariaDB and configuring database..."
apt-get install -y mariadb-server
systemctl start mariadb
systemctl enable mariadb

mysql -e "CREATE DATABASE IF NOT EXISTS radius_db;"
mysql -e "CREATE USER IF NOT EXISTS 'radius_user'@'localhost' IDENTIFIED BY 'radius_password_123';"
mysql -e "GRANT ALL PRIVILEGES ON radius_db.* TO 'radius_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

mysql radius_db -e "CREATE TABLE IF NOT EXISTS app_fup_policies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    groupname VARCHAR(64) NOT NULL,
    quota_bytes BIGINT NOT NULL,
    address_list_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

echo "[3/8] Installing Node.js 20 LTS and PM2..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pm2

echo "[4/8] Installing Nginx and FreeRADIUS..."
apt-get install -y nginx freeradius freeradius-mysql freeradius-utils

umask 022

echo "[*] Continuing with FreeRADIUS database configuration..."
if [ -f /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql ]; then
    mysql radius_db < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
    # schema.sql creates radcheck, radreply, radusergroup and radacct.
    # Do not run the vendor setup.sql: it targets an example database named `radius`.
fi

cd /etc/freeradius/3.0/mods-enabled/
ln -sf ../mods-available/sql sql
sed -i 's/^.*driver = "rlm_sql_null".*/\tdriver = "rlm_sql_mysql"/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^.*dialect = "sqlite".*/\tdialect = "mysql"/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^.*server = "localhost".*/\tserver = "localhost"/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^.*port = 3306.*/\tport = 3306/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^.*password = "radpass".*/\tpassword = "radius_password_123"/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^.*login = "radius".*/\tlogin = "radius_user"/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^.*radius_db = "radius".*/\tradius_db = "radius_db"/' /etc/freeradius/3.0/mods-available/sql

sed -i '/^.*tls {/,/^.*}/ s/^/#/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/^#\s*read_clients = yes/read_clients = yes/' /etc/freeradius/3.0/mods-available/sql

# Ensure the SQL module handles authorization and every accounting packet
# (Start, Interim-Update, Stop) before FreeRADIUS is started.
bash "$INSTALL_DIR/scripts/fix-freeradius.sh"

# Fail installation instead of silently leaving a non-accounting server.
freeradius -XC
chown -R freerad:freerad /etc/freeradius/3.0/

systemctl enable nginx
systemctl enable freeradius
systemctl restart freeradius

echo "[*] Setting up Logrotate for FreeRADIUS Radacct..."
cat << 'EOF_LOG' > /etc/logrotate.d/freeradius-radacct
/var/log/freeradius/radacct/*/detail-* {
    su freerad freerad
    daily
    rotate 2
    missingok
    compress
    notifempty
    nocreate
    sharedscripts
    postrotate
        find /var/log/freeradius/radacct -name 'detail-*' -mtime +2 -delete 2>/dev/null || true
    endscript
}
EOF_LOG

echo "[5/8] Moving Radius-UI files to /var/www/radius-ui..."
APP_DIR="/var/www/radius-ui"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$INSTALL_DIR/"* "$APP_DIR/"

echo "[*] Using uploaded source files (no remote fetch)..."
chown -R www-data:www-data "$APP_DIR"

echo "[*] Running FreeRADIUS fixes from local source..."
bash "$APP_DIR/scripts/fix-freeradius.sh"

echo "[6/8] Setting up Node.js Backend..."
cd "$APP_DIR/server"
npm install --omit=dev

cat << 'EOF' > .env
PORT=3000
DB_HOST=localhost
DB_USER=radius_user
DB_PASSWORD=radius_password_123
DB_NAME=radius_db
API_TOKEN=rahasia_bebas_123
SERVER_IDENTITY=Radius-Core
SERVER_DESCRIPTION=Main Radius Server
EOF

pm2 start index.js --name radius-api
pm2 save
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u root --hp /root || true

echo "[7/8] Skipping React compilation (already bundled)..."

echo "[8/8] Setting up Nginx Web Server..."
cat << 'EOF' > /etc/nginx/sites-available/radius-ui
server {
    listen 80;
    server_name _;

    root /var/www/radius-ui/client-dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/radius-ui /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "[9/9] Configuring UFW Firewall..."
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP Web UI
ufw allow 443/tcp     # HTTPS
ufw allow 3000/tcp    # API / Web App
ufw allow 3000/udp    # API / Web App
ufw allow 1812/udp    # FreeRADIUS Auth
ufw allow 1813/udp    # FreeRADIUS Acct
ufw allow 3799/udp    # FreeRADIUS CoA

ufw --force enable

echo "=========================================================="
echo "âœ… SECURE INSTALLATION COMPLETE!"
echo "You can now access Radius-UI at: http://$(hostname -I | awk '{print $1}')"
echo "Default Username: superadmin"
echo "Default Password: admin123"
echo "=========================================================="
