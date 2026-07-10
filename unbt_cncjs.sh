#!/usr/bin/env bash
# ==============================================================================
# Repository: universalbit-dev/cnc-router-machines
# Module: unbt_cncjs.sh
# Version: Pure Node.js 22 LTS - Nginx Safe Coexistence Profile (Hardened)
# Description: Automated headless installation with graceful termination, PM2
#              lifecycle setup, UFW isolation, and uncollidable Nginx proxying.
# ==============================================================================

set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_NAME="$(basename "$0")"
INTERNAL_PORT="${INTERNAL_PORT:-8000}"
PROXY_PORT="${PROXY_PORT:-8443}"
PM2_APP_NAME="${PM2_APP_NAME:-unbt-cncjs-simulator}"

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

cleanup_on_error() {
  error "Deployment failed at line $1 while running: ${2:-unknown command}"
  exit 1
}
trap 'cleanup_on_error "$LINENO" "$BASH_COMMAND"' ERR

echo -e "${GREEN}=== [UniversalBit CNC Lab] Enforcing Node 22 LTS, PM2 & Nginx Proxy ===${NC}"

# ------------------------------------------------------------------------------
# 1) Root enforcement
# ------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  error "This deployment script must be executed via sudo or root context."
  exit 1
fi

# Determine real user context
REAL_USER="${SUDO_USER:-${USER:-root}}"
if [[ "$REAL_USER" == "root" ]]; then
  # Prefer the owner of /home if available
  CANDIDATE_USER="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd || true)"
  if [[ -n "${CANDIDATE_USER:-}" ]]; then
    REAL_USER="$CANDIDATE_USER"
  fi
fi

USER_HOME="$(eval echo "~$REAL_USER")"
if [[ -z "${USER_HOME:-}" || ! -d "$USER_HOME" ]]; then
  error "Unable to resolve a valid home directory for user: $REAL_USER"
  exit 1
fi

# ------------------------------------------------------------------------------
# 2) Apt/dpkg readiness checks (no broad killall)
# ------------------------------------------------------------------------------
wait_for_apt_locks() {
  local max_wait=120
  local waited=0
  local lock_files=(
    /var/lib/dpkg/lock-frontend
    /var/lib/dpkg/lock
    /var/cache/apt/archives/lock
    /var/lib/apt/lists/lock
  )

  while :; do
    local locked=0
    for lf in "${lock_files[@]}"; do
      if fuser "$lf" >/dev/null 2>&1; then
        locked=1
        break
      fi
    done

    if [[ "$locked" -eq 0 ]]; then
      return 0
    fi

    if (( waited >= max_wait )); then
      error "Timed out waiting for apt/dpkg locks after ${max_wait}s."
      return 1
    fi

    warn "apt/dpkg is busy, waiting... (${waited}s/${max_wait}s)"
    sleep 3
    ((waited+=3))
  done
}

log "Checking package manager readiness..."
wait_for_apt_locks

# Attempt to recover interrupted dpkg state (safe no-op when clean)
dpkg --configure -a || true

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release software-properties-common

# ------------------------------------------------------------------------------
# 3) Enforce Node.js 22 LTS and required packages
# ------------------------------------------------------------------------------
log "Configuring official repository for Node.js 22 LTS..."
rm -f /etc/apt/sources.list.d/nodesource.list || true
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

apt-get update -y
apt-get install -y --no-install-recommends nodejs build-essential nginx openssl iproute2

# Validate Node major version
NODE_MAJOR="$(node -v | sed -E 's/^v([0-9]+).*/\1/' || echo "0")"
if [[ "$NODE_MAJOR" != "22" ]]; then
  error "Node.js 22.x expected, detected: $(node -v 2>/dev/null || echo 'unknown')"
  exit 1
fi
log "Node.js version validated: $(node -v)"

# ------------------------------------------------------------------------------
# 4) Install CNCjs + PM2 globally
# ------------------------------------------------------------------------------
log "Installing headless CNCjs and PM2..."
npm install -g cncjs pm2@latest --quiet

# ------------------------------------------------------------------------------
# 5) Graceful stop for existing app and targeted port reclaim
# ------------------------------------------------------------------------------
log "Preparing PM2 lifecycle and clearing only target port conflicts..."
sudo -u "$REAL_USER" env PM2_HOME="$USER_HOME/.pm2" pm2 delete "$PM2_APP_NAME" >/dev/null 2>&1 || true

# Gracefully stop process holding INTERNAL_PORT, if any
if ss -tlnp "( sport = :${INTERNAL_PORT} )" 2>/dev/null | grep -q ":${INTERNAL_PORT}"; then
  PID_CLEAN="$(
    ss -tlnp "( sport = :${INTERNAL_PORT} )" 2>/dev/null \
      | awk -F'pid=' 'NF>1{print $2}' \
      | awk -F',' 'NF>0{print $1}' \
      | head -n1
  )"
  if [[ -n "${PID_CLEAN:-}" && "$PID_CLEAN" =~ ^[0-9]+$ ]]; then
    warn "Port ${INTERNAL_PORT} in use by PID ${PID_CLEAN}; sending SIGTERM..."
    kill -15 "$PID_CLEAN" 2>/dev/null || true
    sleep 2
    if ss -tlnp "( sport = :${INTERNAL_PORT} )" 2>/dev/null | grep -q ":${INTERNAL_PORT}"; then
      warn "PID ${PID_CLEAN} still active; sending SIGKILL..."
      kill -9 "$PID_CLEAN" 2>/dev/null || true
      sleep 1
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 6) Configuration and local TLS material
# ------------------------------------------------------------------------------
CNCJS_CONFIG_DIR="$USER_HOME/.cncjs"
mkdir -p "$CNCJS_CONFIG_DIR"
chown -R "$REAL_USER:$REAL_USER" "$CNCJS_CONFIG_DIR"
chmod 700 "$CNCJS_CONFIG_DIR"

CERT_FILE="$CNCJS_CONFIG_DIR/server.crt"
KEY_FILE="$CNCJS_CONFIG_DIR/server.key"

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
  log "TLS certificate/key detected."
else
  warn "Generating local self-signed TLS certificate..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=localhost"
fi

chown "$REAL_USER:$REAL_USER" "$CERT_FILE" "$KEY_FILE"
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

CONFIG_JSON="$CNCJS_CONFIG_DIR/cncjs.json"
cat > "$CONFIG_JSON" <<EOF
{
  "port": ${INTERNAL_PORT},
  "host": "127.0.0.1",
  "allowRemoteAccess": false
}
EOF
chown "$REAL_USER:$REAL_USER" "$CONFIG_JSON"
chmod 640 "$CONFIG_JSON"

# ------------------------------------------------------------------------------
# 7) Firewall isolation
# ------------------------------------------------------------------------------
log "Applying UFW policy (if available)..."
if command -v ufw >/dev/null 2>&1; then
  # Add rules idempotently; ignore if already present
  ufw deny "${INTERNAL_PORT}/tcp" comment 'Block direct CNCjs local port exposure' >/dev/null 2>&1 || true
  ufw allow "${PROXY_PORT}/tcp" comment 'Allow CNCjs TLS reverse proxy' >/dev/null 2>&1 || true

  if ufw status 2>/dev/null | grep -qi "Status: active"; then
    ufw reload >/dev/null 2>&1 || true
    log "UFW rules applied and firewall reloaded."
  else
    warn "UFW is installed but inactive; rules were added but firewall not reloaded."
  fi
else
  warn "UFW not installed; skipping firewall hardening."
fi

# ------------------------------------------------------------------------------
# 8) Nginx reverse proxy
# ------------------------------------------------------------------------------
log "Deploying Nginx reverse proxy on port ${PROXY_PORT}..."
rm -f /etc/nginx/sites-enabled/default || true

cat > /etc/nginx/sites-available/unbt-cncjs <<EOF
server {
    listen ${PROXY_PORT} ssl;
    server_name _;

    ssl_certificate ${CERT_FILE};
    ssl_certificate_key ${KEY_FILE};

    # Conservative TLS baseline (self-signed cert is for local/private trusted use)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://127.0.0.1:${INTERNAL_PORT};
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

ln -sfn /etc/nginx/sites-available/unbt-cncjs /etc/nginx/sites-enabled/unbt-cncjs

# Validate config before restart
nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx
log "Nginx reverse proxy is active."

# ------------------------------------------------------------------------------
# 9) Start CNCjs via PM2
# ------------------------------------------------------------------------------
log "Starting CNCjs in PM2..."
sudo -u "$REAL_USER" env PM2_HOME="$USER_HOME/.pm2" pm2 start cncjs \
  --name "$PM2_APP_NAME" \
  -- --config "$CONFIG_JSON"

sudo -u "$REAL_USER" env PM2_HOME="$USER_HOME/.pm2" pm2 save

# Try to enable PM2 startup (best effort)
if command -v systemctl >/dev/null 2>&1; then
  sudo -u "$REAL_USER" env PM2_HOME="$USER_HOME/.pm2" pm2 startup systemd -u "$REAL_USER" --hp "$USER_HOME" >/tmp/pm2-startup.log 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 10) Post-checks and privacy-safe output
# ------------------------------------------------------------------------------
if ! sudo -u "$REAL_USER" env PM2_HOME="$USER_HOME/.pm2" pm2 describe "$PM2_APP_NAME" | grep -qi "online"; then
  warn "PM2 app '$PM2_APP_NAME' may not be online yet. Check: pm2 logs $PM2_APP_NAME"
fi

if ss -tln "( sport = :${PROXY_PORT} )" 2>/dev/null | grep -q ":${PROXY_PORT}"; then
  log "Proxy port ${PROXY_PORT} is listening."
else
  warn "Proxy port ${PROXY_PORT} is not listening as expected."
fi

PUBLIC_HINT_HOST="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "your-hostname")"
PRIMARY_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)"

echo -e "${GREEN}=== [UniversalBit] Automated Deployment Complete ===${NC}"
echo -e "${YELLOW}Access locally:${NC} https://localhost:${PROXY_PORT}"
echo -e "${YELLOW}Access by hostname:${NC} https://${PUBLIC_HINT_HOST}:${PROXY_PORT}"

if [[ -n "${PRIMARY_IP:-}" ]]; then
  echo -e "${YELLOW}Access by detected primary IP:${NC} https://${PRIMARY_IP}:${PROXY_PORT}"
fi

echo -e "${YELLOW}Note:${NC} Certificate is self-signed unless replaced with trusted certs."
