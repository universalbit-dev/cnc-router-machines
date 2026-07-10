#!/usr/bin/env bash
# ==============================================================================
# Repository: universalbit-dev/cnc-router-machines
# Module: unbt_cncjs.sh
# Version: Pure Node.js 22 LTS - Nginx Safe Coexistence Profile
# Description: Automated headless installation with graceful termination, PM2
#              lifecycle setups, UFW isolation, and uncollidable Nginx proxying.
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== [UniversalBit CNC Lab] Enforcing Node 22 LTS, PM2 & Nginx Proxy ===${NC}"

# 1. Root Enforcement Boundary Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This deployment script must be executed via sudo or root context.${NC}"
   exit 1
fi

# 2. Preventative Package Manager Lock Cleanup
echo -e "${YELLOW}--> Cleaning up any stale package manager locks...${NC}"
killall apt apt-get dpkg npm 2>/dev/null || true
dpkg --configure -a

# 3. Force Upgrade to Node.js 22 LTS System-Wide
echo -e "${YELLOW}--> Configuring official repositories for Node.js 22 LTS...${NC}"
rm -f /etc/apt/sources.list.d/nodesource.list
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs build-essential nginx

# 4. Install Headless CNCjs & PM2 via Global NPM Registry
echo -e "${YELLOW}--> Installing headless CNCjs and PM2 ecosystem package tools...${NC}"
npm install -g cncjs pm2@latest --quiet

# 5. Graceful Shutdown & Rogue Socket Reclaimer (Prevents EADDRINUSE crashes)
echo -e "${YELLOW}--> Optimizing network port states and purging active locks...${NC}"
INTERNAL_PORT=8000
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")

sudo -u "$REAL_USER" PM2_HOME="$USER_HOME/.pm2" pm2 delete unbt-cncjs-simulator 2>/dev/null || true
if ss -tlnp | grep -q ":${INTERNAL_PORT} "; then
    PID_HOLDING_PORT=$(ss -tlnp | grep ":${INTERNAL_PORT} " | awk '{print $6}' | cut -d, -f2 || echo "")
    PID_CLEAN=$(echo "$PID_HOLDING_PORT" | grep -oE '[0-9]+' | head -n1 || echo "")
    if [ ! -z "$PID_CLEAN" ]; then
        kill -15 "$PID_CLEAN" 2>/dev/null || true
        sleep 2
    fi
fi
if ss -tlnp | grep -q ":${INTERNAL_PORT} "; then
    killall -9 node cncjs 2>/dev/null || true
    sleep 1
fi

# 6. Base Configuration Directory and Cryptographic Certificate Initialization
CNCJS_CONFIG_DIR="$USER_HOME/.cncjs"
mkdir -p "$CNCJS_CONFIG_DIR"
CERT_FILE="$CNCJS_CONFIG_DIR/server.crt"
KEY_FILE="$CNCJS_CONFIG_DIR/server.key"

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    echo -e "${GREEN}✓ Cryptographic keys detected.${NC}"
else
    echo -e "${YELLOW}⚠ Generating local fallback SSL keys...${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$KEY_FILE" \
      -out "$CERT_FILE" \
      -subj "/CN=universalbit.local"
fi
chown -R "$REAL_USER:$REAL_USER" "$CNCJS_CONFIG_DIR"
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

# 7. Write CNCjs JSON Config (Listen locally on localhost loopback)
CONFIG_JSON="$CNCJS_CONFIG_DIR/cncjs.json"
cat <<EOF > "$CONFIG_JSON"
{
  "port": ${INTERNAL_PORT},
  "host": "127.0.0.1",
  "allowRemoteAccess": false
}
EOF
chown "$REAL_USER:$REAL_USER" "$CONFIG_JSON"
chmod 644 "$CONFIG_JSON"

# 8. Network Firewall Isolation (Open Port 8443 / Block Port 8000)
echo -e "${YELLOW}--> Hardening firewall routing parameters via UFW...${NC}"
if command -v ufw &> /dev/null; then
    ufw deny 8000/tcp comment 'Block Direct Unencrypted CNCjs Access' || true
    ufw allow 8443/tcp comment 'UniversalBit CNCjs Secure Proxy' || true
    ufw reload
fi

# 9. Deploy and Activate Nginx Proxy (Bypasses Apache Port Overlap crashes)
echo -e "${YELLOW}--> Deploying and activating Nginx Reverse Proxy configuration on port 8443...${NC}"
# Disable the default site if it overlaps
rm -f /etc/nginx/sites-enabled/default

cat <<EOF > /etc/nginx/sites-available/unbt-cncjs
server {
    listen 8443 ssl;
    server_name _;

    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;

    location / {
        proxy_pass http://127.0.0.1:${INTERNAL_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSockets Upgrade Engine for continuous toolpath updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/unbt-cncjs /etc/nginx/sites-enabled/
systemctl restart nginx
echo -e "${GREEN}✓ Nginx reverse proxy routing configuration is active!${NC}"

# 10. Start Service via PM2
echo -e "${YELLOW}--> Starting CNCjs daemon wrapper inside PM2 lifecycle...${NC}"
sudo -u "$REAL_USER" PM2_HOME="$USER_HOME/.pm2" pm2 start cncjs \
  --name "unbt-cncjs-simulator" \
  -- --config "$CONFIG_JSON"

sudo -u "$REAL_USER" PM2_HOME="$USER_HOME/.pm2" pm2 save

echo -e "${GREEN}=== [UniversalBit] Automated Deployment Complete ===${NC}"
echo -e "Access your interface safely via: ${YELLOW}https://localhost:8443${NC}"
echo -e "Or use your server hostname/IP on port ${YELLOW}8443${NC}"
