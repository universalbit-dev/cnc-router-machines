#!/usr/bin/env bash
# ==============================================================================
# Repository: universalbit-dev/universalbit-dev/tree/main/cnc
# Module: universalbit_grbl_flasher.sh
# Version: Phase 3.9 - Unified AVR + ESP32 Secure Flasher
# Description:
#   - AVR (Nano/Uno): flashes gnea/grbl .hex
#   - ESP32: flashes bdring/Grbl_Esp32 .bin
#   - ESP8266: erase-only unless --bin is provided
# ==============================================================================

set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_NAME="$(basename "$0")"

# ------------------------------ Defaults --------------------------------------
PORT=""
CHIP_HINT="auto"                 # auto|avr|esp32|esp8266
AUTO_YES="false"
USER_BIN=""

# AVR source (gnea/grbl)
GRBL_AVR_TAG="v1.1h.20190825"
GRBL_AVR_HEX="grbl_v1.1h.20190825.hex"

# ESP32 source (bdring/Grbl_Esp32)
GRBL_ESP32_TAG="v1.3a"
GRBL_ESP32_BIN="firmware.bin"
GRBL_ESP32_LOCAL="grbl_esp32_firmware.bin"

# Baud presets
BAUD_ESP=115200
BAUD_AVR_STD=57600
BAUD_AVR_FAST=115200

# ------------------------------ Logging ---------------------------------------
log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<EOF
Usage:
  sudo ./${SCRIPT_NAME} [options]

Options:
  --port <device>               Serial device (e.g. /dev/ttyUSB0 or /dev/ttyACM0)
  --chip <auto|avr|esp32|esp8266>
                                Force target flow (default: auto)
  --yes                         Non-interactive mode (skip confirmation)
  --bin <path>                  Custom .bin for esp8266 (or custom esp32 override)
  --avr-tag <tag>               gnea/grbl release tag (default: ${GRBL_AVR_TAG})
  --esp32-tag <tag>             bdring/Grbl_Esp32 release tag (default: ${GRBL_ESP32_TAG})
  -h, --help                    Show help

Examples:
  sudo ./${SCRIPT_NAME} --chip avr --port /dev/ttyUSB0
  sudo ./${SCRIPT_NAME} --chip esp32 --yes
  sudo ./${SCRIPT_NAME} --chip esp8266 --bin ./custom_fw.bin
EOF
}

cleanup() {
  rm -f /tmp/unbt_esp_check.log /tmp/unbt_esp_check.err 2>/dev/null || true
}
trap cleanup EXIT

# --------------------------- Preconditions ------------------------------------
require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    die "This script must be run with sudo/root."
  fi
}

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

confirm_or_exit() {
  if [[ "$AUTO_YES" == "true" ]]; then
    return
  fi
  read -rp "Proceed with flash installation? (yes/no): " CONFIRM
  [[ "${CONFIRM,,}" == "yes" ]] || { warn "Aborted by user."; exit 0; }
}

ensure_dialout_group() {
  local real_user="${SUDO_USER:-$USER}"
  if id -nG "$real_user" | grep -qw dialout; then
    log "User '$real_user' already in dialout group."
  else
    log "Adding '$real_user' to dialout group..."
    usermod -aG dialout "$real_user"
    warn "Group change may require logout/login."
  fi
}

# --------------------------- Chip Detection -----------------------------------
detect_chip_flow() {
  local flow="AVR-NANO"
  local desc="8-Bit AVR board (Nano/Uno family)"
  local target=""

  # Forced mode
  if [[ "$CHIP_HINT" != "auto" ]]; then
    case "$CHIP_HINT" in
      avr)      flow="AVR-NANO";      desc="8-Bit AVR board (forced)"; target="" ;;
      esp32)    flow="ESP32-AUTO";    desc="32-Bit ESP32 board (forced)"; target="esp32" ;;
      esp8266)  flow="ESP8266-MANUAL";desc="32-Bit ESP8266 board (forced)"; target="esp8266" ;;
      *) die "Invalid --chip value: $CHIP_HINT" ;;
    esac
    echo "${flow}|${desc}|${target}"
    return
  fi

  # Auto probe with esptool first
  if esptool --port "$PORT" --baud "$BAUD_ESP" chip_id >/tmp/unbt_esp_check.log 2>/tmp/unbt_esp_check.err; then
    if grep -qi "ESP8266" /tmp/unbt_esp_check.log; then
      flow="ESP8266-MANUAL"
      desc="32-Bit ESP8266 board detected"
      target="esp8266"
    else
      flow="ESP32-AUTO"
      desc="32-Bit ESP32 board detected"
      target="esp32"
    fi
  else
    # Keep AVR default
    warn "ESP probe failed; defaulting to AVR flow."
    warn "If this is ESP hardware, check boot mode/cable/permissions."
  fi

  echo "${flow}|${desc}|${target}"
}

# --------------------------- Flash Flows --------------------------------------
flash_esp32() {
  log "ESP32 flow selected (source: bdring/Grbl_Esp32)"

  local bin_file="$GRBL_ESP32_LOCAL"
  local url="https://github.com/bdring/Grbl_Esp32/releases/download/${GRBL_ESP32_TAG}/${GRBL_ESP32_BIN}"

  # Allow override via --bin
  if [[ -n "$USER_BIN" ]]; then
    [[ -f "$USER_BIN" ]] || die "--bin file not found: $USER_BIN"
    bin_file="$USER_BIN"
    log "Using custom ESP32 binary: $bin_file"
  else
    if [[ ! -f "$bin_file" ]]; then
      log "Downloading ESP32 firmware: $url"
      download_file "$url" "$bin_file" || die "Failed to download ESP32 firmware from $url"
    else
      log "Using cached ESP32 binary: $bin_file"
    fi
  fi

  warn "Erasing ESP32 flash..."
  esptool --chip esp32 --port "$PORT" erase_flash

  log "Writing ESP32 firmware to address 0x0..."
  esptool --chip esp32 --port "$PORT" --baud "$BAUD_ESP" \
    write_flash --flash_mode dio --flash_size detect 0x0 "$bin_file"

  log "ESP32 flashing completed."
}

flash_esp8266() {
  log "ESP8266 flow selected."
  warn "gnea/grbl is AVR-only and does not provide ESP8266 .bin artifacts."

  warn "Erasing ESP8266 flash..."
  esptool --chip esp8266 --port "$PORT" erase_flash

  if [[ -z "$USER_BIN" ]]; then
    warn "No --bin provided. Per policy, erase-only completed for ESP8266."
    warn "To flash, rerun with: --chip esp8266 --bin /path/to/firmware.bin"
    return
  fi

  [[ -f "$USER_BIN" ]] || die "--bin file not found: $USER_BIN"
  log "Writing ESP8266 firmware to address 0x0..."
  esptool --chip esp8266 --port "$PORT" --baud "$BAUD_ESP" \
    write_flash --flash_mode dio --flash_size detect 0x0 "$USER_BIN"

  log "ESP8266 flashing completed."
}

flash_avr() {
  log "AVR flow selected (source: gnea/grbl)"
  install_pkg_if_missing avrdude avrdude

  local hex_file="$GRBL_AVR_HEX"
  local url="https://github.com/gnea/grbl/releases/download/${GRBL_AVR_TAG}/${GRBL_AVR_HEX}"

  if [[ ! -f "$hex_file" ]]; then
    log "Downloading AVR GRBL hex: $url"
    download_file "$url" "$hex_file" || {
      err "Failed download: $url"
      err "Check releases: https://github.com/gnea/grbl/releases"
      exit 1
    }
  else
    log "Using cached AVR hex: $hex_file"
  fi

  log "Strategy 1: arduino @ ${BAUD_AVR_STD}"
  if avrdude -c arduino -p m328p -P "$PORT" -b "$BAUD_AVR_STD" -U "flash:w:${hex_file}:i"; then
    log "Flash successful with strategy 1."
    return
  fi

  warn "Strategy 1 failed."
  log "Strategy 2: stk500v1 @ ${BAUD_AVR_STD}"
  if avrdude -c stk500v1 -p m328p -P "$PORT" -b "$BAUD_AVR_STD" -U "flash:w:${hex_file}:i"; then
    log "Flash successful with strategy 2."
    return
  fi

  warn "Strategy 2 failed."
  log "Strategy 3: arduino @ ${BAUD_AVR_FAST}"
  if avrdude -c arduino -p m328p -P "$PORT" -b "$BAUD_AVR_FAST" -U "flash:w:${hex_file}:i"; then
    log "Flash successful with strategy 3."
    return
  fi

  warn "Automated strategies failed."

  if [[ "$AUTO_YES" == "true" ]]; then
    die "Manual reset strategy needed, but running non-interactive (--yes)."
  fi

  echo -e "${BLUE}Press Enter, then press/reset board at flash start...${NC}"
  read -rp "Ready for manual sync? [Enter] "

  if avrdude -c arduino -p m328p -P "$PORT" -b "$BAUD_AVR_STD" -D -U "flash:w:${hex_file}:i"; then
    log "Manual override flash successful."
  else
    die "AVR flash failed after manual override. Check cable/bootloader/port."
  fi
}

# --------------------------- Arg Parsing --------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)       PORT="${2:-}"; shift 2 ;;
    --chip)       CHIP_HINT="${2:-}"; shift 2 ;;
    --yes)        AUTO_YES="true"; shift ;;
    --bin)        USER_BIN="${2:-}"; shift 2 ;;
    --avr-tag)    GRBL_AVR_TAG="${2:-}"; shift 2 ;;
    --esp32-tag)  GRBL_ESP32_TAG="${2:-}"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown argument: $1 (use --help)" ;;
  esac
done

# ------------------------------ Main ------------------------------------------
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}   [UniversalBit CNC] Microcontroller Flashing Suite${NC}"
echo -e "${GREEN}========================================================${NC}"

require_root
install_pkg_if_missing curl curl
install_pkg_if_missing esptool esptool

detect_port
ensure_dialout_group
log "Target serial interface: ${PORT}"

IFS='|' read -r FLASH_FLOW CHIP_TYPE ESP_TARGET < <(detect_chip_flow)

echo -e "■ Fingerprinted Hardware: ${GREEN}${CHIP_TYPE}${NC}"
echo -e "--------------------------------------------------------"

confirm_or_exit

case "$FLASH_FLOW" in
  ESP32-AUTO)      flash_esp32 ;;
  ESP8266-MANUAL)  flash_esp8266 ;;
  AVR-NANO)        flash_avr ;;
  *)               die "Unknown flash flow: $FLASH_FLOW" ;;
esac

echo -e "\n${GREEN}=== [UniversalBit] Firmware Flash Deployment Complete! ===${NC}"
