#!/usr/bin/env bash
# ==============================================================================
# Repository: universalbit-dev/cnc-router-machines
# Module: unbt_cncjs.sh
# Version: Hardened Node.js + CNCjs + PM2 + Nginx (localhost TLS proxy)
# Description:
#   - Installs/updates Node.js 22, cncjs, pm2, nginx
#   - Resets stale PM2 daemon state safely
#   - Creates local self-signed TLS certs (if missing)
#   - Runs CNCjs on 127.0.0.1:8000
#   - Proxies HTTPS on 8443 via Nginx
#   - Applies optional UFW rules (if ufw is installed)
#
# NOTE:
#   - This script intentionally contains no hardcoded personal/sensitive data.
#   - Replace defaults via env vars if needed.
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== [UniversalBit CNC] CNCjs + PM2 + Nginx secure localhost profile ===${NC}"

# ------------------------------------------------------------------------------
# Configurable defaults (override with environment variables)
# ------------------------------------------------------------------------------
NODE_MAJOR="${NODE_MAJOR:-22}"
INTERNAL_PORT="${INTERNAL_PORT:-8000}"
PUBLIC_TLS_PORT="${PUBLIC_TLS_PORT:-8443}"
CNCJS_HOST="${CNCJS_HOST:-127.0.0.1}"
CERT_CN="${CERT_CN:-localhost}"

APP_NAME="${APP_NAME:-unbt-cnc}"
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo "~$REAL_USER")"

CNCJS_CONFIG_DIR="${CNCJS_CONFIG_DIR:-$USER_HOME/.cncjs}"
CONFIG_JSON="${CONFIG_JSON:-$CNCJS_CONFIG_DIR/cncjs.json}"
CERT_FILE="${CERT_FILE:-$CNCJS_CONFIG_DIR/server.crt}"
KEY_FILE="${KEY_FILE:-$CNCJS_CONFIG_DIR/server.key}"

# ------------------------------------------------------------------------------
# Root enforcement
# ------------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run this script with sudo/root.${NC}"
  exit 1
fi

# ------------------------------------------------------------------------------
# Basic dependencies
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Installing required packages...${NC}"
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release build-essential nginx openssl

# ------------------------------------------------------------------------------
# Node.js repo + install
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Configuring NodeSource Node.js ${NODE_MAJOR}.x...${NC}"
rm -f /etc/apt/sources.list.d/nodesource.list
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
apt-get install -y nodejs

# ------------------------------------------------------------------------------
# Global npm tools
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Installing global npm tools (cncjs, pm2)...${NC}"
npm install -g pm2@latest cncjs

# ------------------------------------------------------------------------------
# PM2 cleanup/mismatch guard (for target user)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Resetting PM2 runtime state for user '${REAL_USER}'...${NC}"
sudo -u "${REAL_USER}" PM2_HOME="${USER_HOME}/.pm2" pm2 kill || true
rm -rf "${USER_HOME}/.pm2"
mkdir -p "${USER_HOME}/.pm2"
chown -R "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.pm2"

# ------------------------------------------------------------------------------
# CNCjs config dir + TLS certs
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Preparing CNCjs config and TLS material...${NC}"
mkdir -p "${CNCJS_CONFIG_DIR}"

if [[ ! -f "${CERT_FILE}" || ! -f "${KEY_FILE}" ]]; then
  echo -e "${YELLOW}--> Generating self-signed certificate (${CERT_CN})...${NC}"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -subj "/CN=${CERT_CN}"
else
  echo -e "${GREEN}✓ Existing TLS certificate/key found.${NC}"
fi

chown -R "${REAL_USER}:${REAL_USER}" "${CNCJS_CONFIG_DIR}"
chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

# ------------------------------------------------------------------------------
# Write CNCjs JSON config (localhost only)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Writing CNCjs config: ${CONFIG_JSON}${NC}"
cat > "${CONFIG_JSON}" <<EOF
{
  "port": ${INTERNAL_PORT},
  "host": "${CNCJS_HOST}",
  "allowRemoteAccess": false
}
EOF
chown "${REAL_USER}:${REAL_USER}" "${CONFIG_JSON}"
chmod 644 "${CONFIG_JSON}"

# ------------------------------------------------------------------------------
# Optional firewall rules
# ------------------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1; then
  echo -e "${YELLOW}--> Applying UFW rules...${NC}"
  ufw deny "${INTERNAL_PORT}/tcp" comment 'Block direct CNCjs HTTP (loopback only intended)' || true
  ufw allow "${PUBLIC_TLS_PORT}/tcp" comment 'Allow CNCjs TLS proxy' || true
  ufw reload || true
fi

# ------------------------------------------------------------------------------
# Nginx reverse proxy (HTTPS :8443 -> http://127.0.0.1:8000)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Configuring Nginx reverse proxy on ${PUBLIC_TLS_PORT}...${NC}"
rm -f /etc/nginx/sites-enabled/default

NGINX_SITE="/etc/nginx/sites-available/${APP_NAME}"
cat > "${NGINX_SITE}" <<EOF
server {
    listen ${PUBLIC_TLS_PORT} ssl;
    server_name _;

    ssl_certificate ${CERT_FILE};
    ssl_certificate_key ${KEY_FILE};

    # Minimal sane TLS defaults
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://${CNCJS_HOST}:${INTERNAL_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOF

ln -sf "${NGINX_SITE}" "/etc/nginx/sites-enabled/${APP_NAME}"
nginx -t
systemctl restart nginx
systemctl enable nginx >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Nginx proxy active.${NC}"

# ------------------------------------------------------------------------------
# Start CNCjs via PM2 (single app, stable name)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--> Starting CNCjs under PM2...${NC}"
CNCJS_BIN="$(command -v cncjs)"
if [[ -z "${CNCJS_BIN}" ]]; then
  echo -e "${RED}Error: cncjs binary not found in PATH.${NC}"
  exit 1
fi

# Remove old app name if exists
sudo -u "${REAL_USER}" PM2_HOME="${USER_HOME}/.pm2" pm2 delete "${APP_NAME}" 2>/dev/null || true
sudo -u "${REAL_USER}" PM2_HOME="${USER_HOME}/.pm2" pm2 start "${CNCJS_BIN}" \
  --name "${APP_NAME}" \
  -- --config "${CONFIG_JSON}"

sudo -u "${REAL_USER}" PM2_HOME="${USER_HOME}/.pm2" pm2 save

echo -e "${GREEN}=== Deployment complete ===${NC}"
echo -e "CNCjs internal:  http://${CNCJS_HOST}:${INTERNAL_PORT} (loopback intended)"
echo -e "CNCjs secure UI: https://localhost:${PUBLIC_TLS_PORT}"
echo -e ""
echo -e "Useful checks:"
echo -e "  pm2 list"
echo -e "  pm2 logs ${APP_NAME} --lines 100"
echo -e "  ss -ltnp | grep ${PUBLIC_TLS_PORT}"
