#!/usr/bin/env bash
# ==============================================================================
# universalbit_grbl_flasher.sh
# Master Edition - AVR + ESP32 + ESP8266 (build + flash)
#
# Sources:
#   AVR      -> gnea/grbl
#   ESP32    -> bdring/Grbl_Esp32
#   ESP8266  -> gcobos/grblesp
# ==============================================================================

set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*" >&2; }
die()  { err "$*"; exit 1; }

SCRIPT_NAME="$(basename "$0")"

# Resolve real user/home even under sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~${REAL_USER}")"

# ------------------------------ Defaults --------------------------------------
PORT=""
CHIP_HINT="auto" # auto|avr|esp32|esp8266
AUTO_YES="false"
USER_BIN=""

# AVR
GRBL_AVR_TAG="v1.1h.20190825"
GRBL_AVR_HEX="grbl_v1.1h.20190825.hex"

# ESP32
BUILD_ESP32_FROM_SOURCE="false"
ESP32_REPO_DIR="${REAL_HOME}/Grbl_Esp32"
ESP32_GIT_URL="https://github.com/bdring/Grbl_Esp32.git"
ESP32_GIT_REF=""
ESP32_PIO_ENV=""
GRBL_ESP32_TAG="v1.3a"
GRBL_ESP32_REL_ASSET="firmware.bin"
GRBL_ESP32_LOCAL="grbl_esp32_firmware.bin"

# ESP8266
BUILD_ESP8266_FROM_SOURCE="false"
ESP8266_REPO_DIR="${REAL_HOME}/grblesp"
ESP8266_GIT_URL="https://github.com/gcobos/grblesp.git"
ESP8266_GIT_REF=""
ESP8266_PIO_ENV=""

# Baud presets
BAUD_ESP=115200
BAUD_AVR_STD=57600
BAUD_AVR_FAST=115200

# ------------------------------ Help ------------------------------------------
usage() {
cat <<EOF
Usage:
  sudo ./${SCRIPT_NAME} [options]

Core:
  --port <device>                 Serial port (e.g. /dev/ttyUSB0)
  --chip <auto|avr|esp32|esp8266>
  --yes                           Non-interactive mode
  --bin <file>                    Custom firmware file (.bin for ESP targets)

ESP32:
  --build-esp32-from-source
  --esp32-repo-dir <path>         Default: ${ESP32_REPO_DIR}
  --esp32-git-url <url>           Default: ${ESP32_GIT_URL}
  --esp32-git-ref <ref>           Tag/branch/commit
  --esp32-pio-env <env>           PlatformIO environment
  --esp32-tag <tag>               Release tag for prebuilt download (default: ${GRBL_ESP32_TAG})

ESP8266:
  --build-esp8266-from-source
  --esp8266-repo-dir <path>       Default: ${ESP8266_REPO_DIR}
  --esp8266-git-url <url>         Default: ${ESP8266_GIT_URL}
  --esp8266-git-ref <ref>         Tag/branch/commit
  --esp8266-pio-env <env>         PlatformIO environment

AVR:
  --avr-tag <tag>                 gnea/grbl release tag (default: ${GRBL_AVR_TAG})

Other:
  -h, --help
EOF
}

# ------------------------------ Utilities -------------------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1; }

install_pkg_if_missing() {
  local cmd="$1" pkg="$2"
  if ! need_cmd "$cmd"; then
    log "Installing missing package: $pkg"
    apt-get update -qq
    apt-get install -y -qq "$pkg"
  fi
}

download_file() {
  local url="$1" out="$2"
  curl -fL --connect-timeout 20 --retry 3 --retry-delay 2 "$url" -o "$out"
}

expand_path_for_user() {
  local p="$1"
  local u="${SUDO_USER:-$USER}"
  local h
  h="$(eval echo "~${u}")"
  [[ "$p" == "~"* ]] && echo "${p/#\~/$h}" || echo "$p"
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run with sudo/root."
}

confirm_or_exit() {
  [[ "$AUTO_YES" == "true" ]] && return 0
  read -rp "Proceed with flash installation? (yes/no): " ans
  [[ "${ans,,}" == "yes" ]] || { warn "Aborted by user."; exit 0; }
}

detect_port() {
  if [[ -n "$PORT" ]]; then
    [[ -e "$PORT" ]] || die "Specified port does not exist: $PORT"
    return
  fi

  local candidates=()
  while IFS= read -r p; do candidates+=("$p"); done < <(compgen -G "/dev/ttyUSB*")
  while IFS= read -r p; do candidates+=("$p"); done < <(compgen -G "/dev/ttyACM*")

  [[ ${#candidates[@]} -gt 0 ]] || die "No serial port found on /dev/ttyUSB* or /dev/ttyACM*"
  PORT="${candidates[0]}"
}

ensure_dialout_group() {
  local u="${SUDO_USER:-$USER}"
  if id -nG "$u" | grep -qw dialout; then
    log "User '$u' already in dialout group."
  else
    log "Adding '$u' to dialout group..."
    usermod -aG dialout "$u"
    warn "Group update may require logout/login."
  fi
}

ensure_platformio_for_user() {
  local u="${SUDO_USER:-$USER}"
  local h
  h="$(eval echo "~${u}")"

  export PATH="$PATH:${h}/.local/bin"

  if sudo -u "$u" -H bash -lc "export PATH=\$PATH:${h}/.local/bin; command -v pio >/dev/null 2>&1"; then
    log "PlatformIO found for user ${u}."
    return
  fi

  warn "PlatformIO not found for ${u}. Installing via pipx..."
  apt-get update -qq
  apt-get install -y -qq pipx python3-venv git

  sudo -u "$u" -H bash -lc 'pipx ensurepath || true'
  sudo -u "$u" -H bash -lc 'pipx install platformio || pipx upgrade platformio || true'

  if ! sudo -u "$u" -H bash -lc "export PATH=\$PATH:${h}/.local/bin; command -v pio >/dev/null 2>&1"; then
    die "pio still unavailable for ${u}. Open a new shell and retry."
  fi
}

chip_probe() {
  local out="/tmp/unbt_chip_probe.log"
  if esptool --port "$PORT" --baud "$BAUD_ESP" chip_id >"$out" 2>&1; then
    if grep -qi "ESP8266" "$out"; then echo "esp8266"; return; fi
    if grep -qi "ESP32" "$out"; then echo "esp32"; return; fi
  fi
  echo "avr"
}

ensure_git_repo() {
  local repo_dir="$1" git_url="$2" git_ref="$3"
  local u="${SUDO_USER:-$USER}"

  install_pkg_if_missing git git
  repo_dir="$(expand_path_for_user "$repo_dir")"

  if [[ -d "${repo_dir}/.git" ]]; then
    log "Repo exists: ${repo_dir}"
    sudo -u "$u" -H bash -lc "cd '${repo_dir}' && git fetch --all --tags --prune"
  else
    log "Cloning ${git_url} -> ${repo_dir}"
    sudo -u "$u" -H bash -lc "git clone '${git_url}' '${repo_dir}'"
  fi

  if [[ -n "$git_ref" ]]; then
    log "Checking out ref: ${git_ref}"
    sudo -u "$u" -H bash -lc "cd '${repo_dir}' && git checkout '${git_ref}'"
  fi
}

build_with_pio() {
  local repo_dir="$1" pio_env="${2:-}"
  local u="${SUDO_USER:-$USER}"
  local h
  h="$(eval echo "~${u}")"
  local build_dir cmd fw

  repo_dir="$(expand_path_for_user "$repo_dir")"

  if [[ -f "${repo_dir}/platformio.ini" ]]; then
    build_dir="${repo_dir}"
  elif [[ -f "${repo_dir}/Grbl_Esp32/platformio.ini" ]]; then
    build_dir="${repo_dir}/Grbl_Esp32"
  else
    die "platformio.ini not found in ${repo_dir} (or ${repo_dir}/Grbl_Esp32)"
  fi

  cmd="pio run"
  [[ -n "$pio_env" ]] && cmd="pio run -e ${pio_env}"

  echo -e "${GREEN}[INFO]${NC} Building with PlatformIO in ${build_dir}" >&2
  sudo -u "$u" -H bash -lc "export PATH=\$PATH:${h}/.local/bin; cd '${build_dir}' && ${cmd}" >&2

  if [[ -n "$pio_env" && -f "${build_dir}/.pio/build/${pio_env}/firmware.bin" ]]; then
    fw="${build_dir}/.pio/build/${pio_env}/firmware.bin"
  else
    fw="$(find "${build_dir}/.pio/build" -maxdepth 3 -type f -name firmware.bin | head -n1 || true)"
  fi

  [[ -f "$fw" ]] || die "Build finished but firmware.bin not found."
  printf '%s\n' "$fw"
}

validate_bin_for_chip() {
  local chip="$1" bin="$2"
  [[ -f "$bin" ]] || die "Binary not found: $bin"

  if [[ "$chip" == "esp8266" && "$bin" == *"Grbl_Esp32"* ]]; then
    die "Refusing to flash ESP32 artifact on ESP8266 target: $bin"
  fi
}

# ------------------------------ Flash flows -----------------------------------
flash_esp32() {
  local bin_file=""
  local build_dir=""
  local rel_url="https://github.com/bdring/Grbl_Esp32/releases/download/${GRBL_ESP32_TAG}/${GRBL_ESP32_REL_ASSET}"

  if [[ -n "$USER_BIN" ]]; then
    USER_BIN="$(expand_path_for_user "$USER_BIN")"
    [[ -f "$USER_BIN" ]] || die "--bin not found: $USER_BIN"
    bin_file="$USER_BIN"
    build_dir="$(dirname "$bin_file")"
  elif [[ "$BUILD_ESP32_FROM_SOURCE" == "true" ]]; then
    ensure_platformio_for_user
    ensure_git_repo "$ESP32_REPO_DIR" "$ESP32_GIT_URL" "$ESP32_GIT_REF"
    bin_file="$(build_with_pio "$ESP32_REPO_DIR" "$ESP32_PIO_ENV")"
    [[ -f "$bin_file" ]] || die "Resolved firmware path is invalid: $bin_file"
    log "Built ESP32 firmware: $bin_file"
    build_dir="$(dirname "$bin_file")"
  else
    bin_file="$GRBL_ESP32_LOCAL"
    if [[ ! -f "$bin_file" ]]; then
      log "Downloading ESP32 release binary: $rel_url"
      download_file "$rel_url" "$bin_file"
    fi
  fi

  [[ -f "$bin_file" ]] || die "Firmware file not found: $bin_file"

  # Fallback logic: If boot files are missing, extract them from the local toolchain packages path cache
  if [[ -n "$build_dir" && (! -f "${build_dir}/bootloader.bin" || ! -f "${build_dir}/partitions.bin") ]]; then
    local pio_sdk="${REAL_HOME}/.platformio/packages/framework-arduinoespressif32/tools/sdk/bin"
    if [[ -d "$pio_sdk" ]]; then
      log "📦 Extracting standard SDK partition and boot blocks from core toolchain package cache..."
      [[ ! -f "${build_dir}/bootloader.bin" ]] && cp "$pio_sdk/bootloader_qio_80m.bin" "${build_dir}/bootloader.bin" || true
      [[ ! -f "${build_dir}/partitions.bin" ]] && cp "$pio_sdk/partitions_singleapp.bin" "${build_dir}/partitions.bin" || true
    fi
  fi

  log "Erasing ESP32 storage matrix completely..."
  esptool --chip esp32 --port "$PORT" erase-flash

  # Enhanced block write routine containing structural target offsets to completely fix the boot loops
  if [[ -n "$build_dir" && -f "${build_dir}/bootloader.bin" && -f "${build_dir}/partitions.bin" ]]; then
    log "🚀 Multi-file structure detected. Deploying structural firmware package offsets..."
    esptool --chip esp32 --port "$PORT" --baud "$BAUD_ESP" \
      --before default_reset --after hard_reset write-flash \
      0x1000 "${build_dir}/bootloader.bin" \
      0x8000 "${build_dir}/partitions.bin" \
      0x10000 "$bin_file"
  else
    warn "⚠️ Core partition assets missing in path. Falling back to direct single-binary mapping..."
    log "Flashing ESP32 firmware: $bin_file"
    esptool --chip esp32 --port "$PORT" --baud "$BAUD_ESP" \
      write-flash --flash-mode dio --flash-size detect 0x0 "$bin_file"
  fi
}

flash_esp8266() {
  local bin_file=""

  if [[ -n "$USER_BIN" ]]; then
    USER_BIN="$(expand_path_for_user "$USER_BIN")"
    validate_bin_for_chip esp8266 "$USER_BIN"
    bin_file="$USER_BIN"
  elif [[ "$BUILD_ESP8266_FROM_SOURCE" == "true" ]]; then
    ensure_platformio_for_user
    ensure_git_repo "$ESP8266_REPO_DIR" "$ESP8266_GIT_URL" "$ESP8266_GIT_REF"
    bin_file="$(build_with_pio "$ESP8266_REPO_DIR" "$ESP8266_PIO_ENV")"
    [[ -f "$bin_file" ]] || die "Resolved firmware path is invalid: $bin_file"
    validate_bin_for_chip esp8266 "$bin_file"
    log "Built ESP8266 firmware: $bin_file"
  else
    log "Erasing ESP8266..."
    esptool --chip esp8266 --port "$PORT" erase-flash
    warn "No --bin and no --build-esp8266-from-source provided. Erase-only complete."
    return
  fi

  [[ -f "$bin_file" ]] || die "Firmware file not found: $bin_file"

  log "Erasing ESP8266..."
  esptool --chip esp8266 --port "$PORT" erase-flash

  log "Flashing ESP8266 firmware: $bin_file"
  esptool --chip esp8266 --port "$PORT" --baud "$BAUD_ESP" \
    write-flash --flash-mode dio --flash-size detect 0x0 "$bin_file"
}

flash_avr() {
  install_pkg_if_missing avrdude avrdude

  local hex_file="$GRBL_AVR_HEX"
  local url="https://github.com/gnea/grbl/releases/download/${GRBL_AVR_TAG}/${GRBL_AVR_HEX}"

  if [[ ! -f "$hex_file" ]]; then
    log "Downloading AVR hex: $url"
    download_file "$url" "$hex_file"
  fi

  log "AVR flash strategy 1: arduino @ ${BAUD_AVR_STD}"
  if avrdude -c arduino -p m328p -P "$PORT" -b "$BAUD_AVR_STD" -U "flash:w:${hex_file}:i"; then return; fi

  warn "Strategy 1 failed. Trying strategy 2..."
  if avrdude -c stk500v1 -p m328p -P "$PORT" -b "$BAUD_AVR_STD" -U "flash:w:${hex_file}:i"; then return; fi

  warn "Strategy 2 failed. Trying strategy 3..."
  if avrdude -c arduino -p m328p -P "$PORT" -b "$BAUD_AVR_FAST" -U "flash:w:${hex_file}:i"; then return; fi

  die "AVR flashing failed with all strategies."
}

# ------------------------------ Parse args ------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="${2:-}"; shift 2 ;;
    --chip) CHIP_HINT="${2:-}"; shift 2 ;;
    --yes) AUTO_YES="true"; shift ;;
    --bin) USER_BIN="${2:-}"; shift 2 ;;

    --build-esp32-from-source) BUILD_ESP32_FROM_SOURCE="true"; shift ;;
    --esp32-repo-dir) ESP32_REPO_DIR="${2:-}"; shift 2 ;;
    --esp32-git-url) ESP32_GIT_URL="${2:-}"; shift 2 ;;
    --esp32-git-ref) ESP32_GIT_REF="${2:-}"; shift 2 ;;
    --esp32-pio-env) ESP32_PIO_ENV="${2:-}"; shift 2 ;;
    --esp32-tag) GRBL_ESP32_TAG="${2:-}"; shift 2 ;;

    --build-esp8266-from-source) BUILD_ESP8266_FROM_SOURCE="true"; shift ;;
    --esp8266-repo-dir) ESP8266_REPO_DIR="${2:-}"; shift 2 ;;
    --esp8266-git-url) ESP8266_GIT_URL="${2:-}"; shift 2 ;;
    --esp8266-git-ref) ESP8266_GIT_REF="${2:-}"; shift 2 ;;
    --esp8266-pio-env) ESP8266_PIO_ENV="${2:-}"; shift 2 ;;

    --avr-tag) GRBL_AVR_TAG="${2:-}"; shift 2 ;;

    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# ------------------------------ Main ------------------------------------------
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}   [UniversalBit CNC] Master Universal Flasher${NC}"
echo -e "${GREEN}========================================================${NC}"

require_root
install_pkg_if_missing curl curl
install_pkg_if_missing esptool esptool
detect_port
ensure_dialout_group

detected_chip="$(chip_probe)"
selected_chip="$detected_chip"
[[ "$CHIP_HINT" != "auto" ]] && selected_chip="$CHIP_HINT"

log "Port: $PORT | detected chip: $detected_chip | selected flow: $selected_chip"

if [[ "$selected_chip" == "esp32" && "$detected_chip" == "esp8266" ]]; then
  die "Detected ESP8266 on ${PORT}, but --chip esp32 was requested."
fi
if [[ "$selected_chip" == "esp8266" && "$detected_chip" == "esp32" ]]; then
  die "Detected ESP32 on ${PORT}, but --chip esp8266 was requested."
fi

confirm_or_exit

case "$selected_chip" in
  esp32)   flash_esp32 ;;
  esp8266) flash_esp8266 ;;
  avr)     flash_avr ;;
  *)       die "Unsupported flow: $selected_chip" ;;
esac

log "=== Firmware Flash Deployment Complete ==="
