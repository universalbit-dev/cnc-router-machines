#!/usr/bin/env bash
# ==============================================================================
# Repository: universalbit-dev/universalbit-dev/tree/main/cnc
# Module: universalbit_grbl_flasher.sh
# Version: Phase 3.7 - Ironclad Multi-Platform Flash Matrix
# Description: Automatically manages 8-Bit AVR (Nano) networks or handles
#              32-Bit ESP32 / ESP8266 storage configurations elegantly.
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================================"
echo -e "   [UniversalBit CNC] Microcontroller Flashing Suite"
echo -e "========================================================${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Security Error: This deployment script must be executed via sudo.${NC}" 
   exit 1
fi

REAL_USER=${SUDO_USER:-$USER}

PORT=$(ls /dev/ttyUSB* 2>/dev/null | head -n1 || echo "")
if [ -z "$PORT" ]; then
    echo -e "${RED}❌ Error: No valid hardware interface detected on /dev/ttyUSB*.${NC}"
    exit 1
fi

echo -e "Target link interface locked: ${GREEN}$PORT${NC}"

if ! command -v esptool &> /dev/null; then
    apt-get update -q && apt-get install -y esptool -q
fi
if ! command -v curl &> /dev/null; then
    apt-get install -y curl -q
fi

CHIP_TYPE="Unknown"
FLASH_FLOW=""
ESP_CHIP_TARGET="esp32"

if esptool --port "$PORT" --baud 115200 chip_id &> /tmp/unbt_esp_check.log; then
    if grep -qi "ESP8266" /tmp/unbt_esp_check.log; then
        CHIP_TYPE="32-Bit ESP8266EX Controller (WeMos D1 Uno Footprint Layout)"
        FLASH_FLOW="ESP8266-MANUAL"
        ESP_CHIP_TARGET="esp8266"
    else
        CHIP_TYPE="32-Bit ESP32 Controller Architecture"
        FLASH_FLOW="ESP32-AUTO"
        ESP_CHIP_TARGET="esp32"
    fi
else
    CHIP_TYPE="8-Bit Arduino Nano Core (CH340 Layout / Nano Shield v3 Reference)"
    FLASH_FLOW="AVR-NANO"
fi

echo -e "■ Fingerprinted Hardware: ${GREEN}$CHIP_TYPE${NC}"
echo -e "--------------------------------------------------------"

read -rp "Proceed with flash installation? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}Flashing sequence aborted by user.${NC}"
    exit 0
fi

usermod -aG dialout "$REAL_USER"

case "$FLASH_FLOW" in
    "ESP32-AUTO")
        echo -e "\n${YELLOW}--> Initializing 32-Bit ESP32 Automated Flashing Pipeline...${NC}"
        BINARY_NAME="grbl_esp32_wifi.bin"
        
        if [ ! -f "$BINARY_NAME" ]; then
            echo -e "Downloading pre-compiled CNC firmware build..."
            if ! wget --timeout=15 --tries=2 --no-check-certificate -q --show-progress "https://github.com/bdring/Grbl_ESP32/releases/download/v1.3a/firmware.bin" -O "$BINARY_NAME"; then
                curl -k -L --connect-timeout 15 --retry 2 "https://github.com/bdring/Grbl_ESP32/releases/download/v1.3a/firmware.bin" -o "$BINARY_NAME"
            fi
        fi

        echo -e "${RED}Wiping internal flash memory sectors...${NC}"
        esptool --port "$PORT" erase_flash
        
        echo -e "${GREEN}Writing firmware block to address 0x0...${NC}"
        esptool --chip esp32 --port "$PORT" --baud 115200 write_flash --flash_mode dio --flash_size detect 0x0 "$BINARY_NAME"
        ;;

    "ESP8266-MANUAL")
        echo -e "\n${YELLOW}--> Initializing Custom ESP8266 Extraction Suite...${NC}"
        echo -e "${YELLOW}⚠ Note: Native GRBL requires more GPIO pins than an ESP8266 provides standalone.${NC}"
        echo -e "Please drop your custom binary file path below (e.g. your custom compiled firmware build, or an ESP3D bridge bin)."
        
        read -rp "Enter path to your local .bin file (or press Enter to run a clean memory wipe only): " USER_BIN
        
        echo -e "${RED}Wiping internal flash memory sectors...${NC}"
        esptool --port "$PORT" erase_flash
        
        if [ -n "$USER_BIN" ]; then
            if [ -f "$USER_BIN" ]; then
                echo -e "${GREEN}Writing custom binary $USER_BIN to address 0x0...${NC}"
                esptool --chip esp8266 --port "$PORT" --baud 115200 write_flash --flash_mode dio --flash_size detect 0x0 "$USER_BIN"
            else
                echo -e "${RED}❌ Error: Specified file path '$USER_BIN' does not exist. Chip wiped cleanly.${NC}"
            fi
        fi
        ;;

    "AVR-NANO")
        echo -e "\n${YELLOW}--> Initializing 8-Bit AVR Nano Flashing Pipeline...${NC}"
        if ! command -v avrdude &> /dev/null; then
            echo -e "Deploying system avrdude framework via apt..."
            apt-get update -q && apt-get install -y avrdude -q
        fi

        if [ ! -f "grbl_v1.1h.hex" ]; then
            echo -e "Downloading stable GRBL v1.1h compilation matrix..."
            if ! wget --timeout=15 --tries=2 --no-check-certificate -q --show-progress "https://github.com/gnea/grbl/releases/download/v1.1h.20190825/grbl_v1.1h.20190825.hex" -O grbl_v1.1h.hex; then
                curl -k -L --connect-timeout 15 --retry 2 "https://github.com/gnea/grbl/releases/download/v1.1h.20190825/grbl_v1.1h.20190825.hex" -o grbl_v1.1h.hex
            fi
        fi

        # Adaptive Multi-Protocol Flashing Matrix for /dev/ttyUSB* clones
        echo -e "${YELLOW}--> Strategy 1: Attempting Standard Nano Profile (arduino @ 57600 baud)...${NC}"
        if avrdude -c arduino -p m328p -P "$PORT" -b 57600 -U flash:w:grbl_v1.1h.hex:i; then
            echo -e "${GREEN}✓ Flash Successful using Standard Nano parameters!${NC}"
            exit 0
        fi

        echo -e "${RED}⚠ Strategy 1 Failed. Shifting timing logic...${NC}"
        echo -e "${YELLOW}--> Strategy 2: Attempting Legacy STK500v1 Profile (stk500v1 @ 57600 baud)...${NC}"
        if avrdude -c stk500v1 -p m328p -P "$PORT" -b 57600 -U flash:w:grbl_v1.1h.hex:i; then
            echo -e "${GREEN}✓ Flash Successful using Legacy CH340 parameters!${NC}"
            exit 0
        fi

        echo -e "${RED}⚠ Strategy 2 Failed. Trying High-Speed Mode...${NC}"
        echo -e "${YELLOW}--> Strategy 3: Attempting High-Speed Nano Profile (arduino @ 115200 baud)...${NC}"
        if avrdude -c arduino -p m328p -P "$PORT" -b 115200 -U flash:w:grbl_v1.1h.hex:i; then
            echo -e "${GREEN}✓ Flash Successful using High-Speed Nano parameters!${NC}"
            exit 0
        fi

        # Hardware Line Escape Option (Fallback manual hard sync)
        echo -e "\n${RED}❌ Error: Automated communication signatures timed out.${NC}"
        echo -e "${YELLOW}Let's try a forced manual hard-reset override. Ready your finger on the physical reset button.${NC}"
        read -rp "Press [Enter] when ready to start the synchronized pulse sequence..."
        
        echo -e "${GREEN}Launching flash sequence... PRESS the hardware Reset Button NOW!${NC}"
        if avrdude -c arduino -p m328p -P "$PORT" -b 57600 -D -U flash:w:grbl_v1.1h.hex:i; then
             echo -e "${GREEN}✓ Manual Override Flash Successful!${NC}"
        else
             echo -e "${RED}❌ Deployment terminated. Please verify your hardware connection states.${NC}"
             exit 1
        fi
        ;;
esac

echo -e "\n${GREEN}=== [UniversalBit] Firmware Flash Deployment Complete! ===${NC}"
