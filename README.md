![Arduino Uno Compatible](https://img.shields.io/badge/Arduino_Uno-Compatible-lightgrey?style=flat-square&logo=arduino)
![Arduino Nano Compatible](https://img.shields.io/badge/Arduino_Nano-Compatible-lightgrey?style=flat-square&logo=arduino)
![ESP8266 Compatible](https://img.shields.io/badge/ESP8266-Compatible-lightgrey?style=flat-square&logo=espressif)
![ESP32 Tested](https://img.shields.io/badge/ESP32-Tested-brightgreen?style=flat-square&logo=espressif)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

# UniversalBit CNC Project

UniversalBit CNC is a practical toolkit for flashing, configuring, and operating GRBL-based CNC systems on:

- **AVR** (Arduino Uno / Nano)
- **ESP8266**
- **ESP32**

It includes:
- Unified firmware flasher script
- CNCjs deployment helper
- Wiring and toolchain references
- Real-world flash workflows

![CNC Machine](https://github.com/universalbit-dev/cnc-router-machines/blob/main/assets/images/universalbit_cnc_project.png)

---

## 📌 Table of Contents

1. [Overview](#-overview)
2. [CNCjs Web Interface Controller](#️-cncjs-web-interface-controller)
3. [Firmware Deployment Usage](#-firmware-deployment-usage)
4. [Troubleshooting](#️-troubleshooting)
5. [Hardware Wiring Guides](#-hardware-wiring-guides)
6. [G-Code Generation Tools](#️-g-code-generation-tools)
7. [Additional Resources](#-additional-resources)
8. [Author and License](#-author-and-license)

---

## 🔍 Overview

This repository provides an end-to-end CNC workflow:

- ⚡ Flash GRBL firmware for AVR / ESP8266 / ESP32
- 🖥️ Run CNCjs for machine control
- 🔌 Follow tested wiring references
- 🛠️ Generate G-code from vector designs

---

## 🖥️ CNCjs Web Interface Controller

Use `unbt_cncjs.sh` to install and manage CNCjs.

### Install / Provision

```bash
sudo ./unbt_cncjs.sh --install
```

### Start

```bash
./unbt_cncjs.sh --start
```

### Open Workspace

```text
https://localhost:8443/#/workspace
```

or direct mode:

```text
http://localhost:8000/#/workspace
```

### Stop / Restart / Logs

```bash
./unbt_cncjs.sh --stop
./unbt_cncjs.sh --restart
./unbt_cncjs.sh --logs
```

## 🛡️ Troubleshooting: Permission Denied on Serial Port (`/dev/ttyUSB0`)

If your background simulator daemon log throws a `Permission denied, cannot open /dev/ttyUSB0` error, the process engine does not have clearance to access the serial hardware.

### Secure Fix: Propagate Linux Group Permissions

Run the following commands to permanently add your active user account to the system hardware access group and force your background processes to reload their environment profiles:

```bash
# 1. Add your dynamic user account to the serial dialout group
sudo usermod -aG dialout $USER
# 2. Stop your active CNCjs instance session
./unbt_cncjs.sh --stop
# 3. Kill your background process manager engine to completely drop old permission locks
pm2 kill || true
# 4. Restart the runtime control engine under your updated profile layout
./unbt_cncjs.sh --start

```

---
## 🚀 Firmware Deployment Usage

Main tool:

`universalbit_grbl_flasher.sh`

Before flashing:
- connect board via USB
- ensure board has power
- confirm serial port exists (`/dev/ttyUSB*` or `/dev/ttyACM*`)

---

### 🔹 Arduino Uno / Nano (AVR)

```bash
# Auto-detect serial port
sudo ./universalbit_grbl_flasher.sh --chip avr --yes

# Explicit serial port
sudo ./universalbit_grbl_flasher.sh --chip avr --port /dev/ttyUSB0 --yes
```

---

### 🔹 ESP8266
# Build + flash (recommended)
```
sudo ./universalbit_grbl_flasher.sh \
  --chip esp8266 \
  --build-esp8266-from-source \
  --esp8266-pio-env esp12e \
  --port /dev/ttyUSB0 \
  --yes
```

# Flash existing binary (same env artifact)
```
sudo ./universalbit_grbl_flasher.sh \
  --chip esp8266 \
  --bin "$HOME/grblesp/.pio/build/esp12e/firmware.bin" \
  --port /dev/ttyUSB0 \
  --yes
```

---

### 🔹 ESP32 (recommended script flow)

This is the recommended and tested flow.

```bash
# Build from source + flash
sudo ./universalbit_grbl_flasher.sh --chip esp32 --build-esp32-from-source --esp32-repo-dir "$HOME/Grbl_Esp32" --yes

# Flash existing binary
sudo ./universalbit_grbl_flasher.sh --chip esp32 --bin "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin" --yes
```

---

### 🔹 ESP32 (manual esptool flow)

If you flash manually, build first:

```bash
cd "$HOME/Grbl_Esp32"
pio run -e release
```

Then flash with modern `esptool` syntax:

```bash
sudo esptool --chip esp32 --port /dev/ttyUSB0 erase-flash
sudo esptool --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
  write-flash --flash-mode dio --flash-size detect 0x0 "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin"
```

---

### 🔹 ESP32 ROM fallback (`--no-stub`)

Use this only when stub mode is unavailable on your environment.

```bash
sudo esptool --chip esp32 --no-stub --port /dev/ttyUSB0 --baud 115200 \
  write-flash --flash-mode dio --flash-size detect 0x0 "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin"
```

> Note: In `--no-stub` mode, `erase-flash` may fail on some ESP32 ROM loaders.  
> `write-flash` already erases the target range it writes.

---

## 🔌 Hardware Wiring Guides

- [GRBL Wiring (Official)](https://github.com/grbl/grbl/wiki/Connecting-Grbl)
- [DRV8825 CNC Example (Fritzing)](https://fritzing.org/projects/stepper-motor-with-drv8825-cnc-router-grbl)
- [MKS-DLC32 Wiring Manual (PDF)](https://github.com/makerbase-mks/MKS-DLC32/blob/main/MKS-DLC32-main/doc/DLC32%20wiring%20manual.pdf)
- [Raspberry Pi CNC Hat Guide](https://wiki.protoneer.co.nz/Raspberry_Pi_CNC)

---

## 🛠️ G-Code Generation Tools

- [Inkscape](https://inkscape.org/)
- [Inkscape Repository](https://github.com/inkscape/inkscape)
- [Inkscape Lasertools Plugin](https://github.com/ChrisWag91/Inkscape-Lasertools-Plugin)

---

## 📦 Additional Resources

- [CNCjs](https://github.com/cncjs/cncjs)
- [MKS-DLC32 Repository](https://github.com/makerbase-mks/MKS-DLC32)
- [GRBL Releases](https://github.com/gnea/grbl/releases)
- [Grbl_Esp32](https://github.com/bdring/Grbl_Esp32)
- [grblesp (ESP8266)](https://github.com/gcobos/grblesp)

---

## 📜 Author and License

Created and maintained by **[universalbit-dev](https://github.com/universalbit-dev)**.  
Licensed under the **[GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html)**.

---

## 🤝 Support

If this project helps your CNC workflow, please consider starring the repository and sharing it with the CNC/maker community.
