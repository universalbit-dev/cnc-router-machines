![Arduino Uno Tested](https://img.shields.io/badge/Arduino_Uno-Tested-blue?style=flat-square&logo=arduino)
![Arduino Nano Tested](https://img.shields.io/badge/Arduino_Nano-Tested-blue?style=flat-square&logo=arduino)
![ESP8266 Tested](https://img.shields.io/badge/ESP8266-Tested-brightgreen?style=flat-square&logo=espressif)
![ESP32 Tested](https://img.shields.io/badge/ESP32-Tested-brightgreen?style=flat-square&logo=espressif)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

# UniversalBit CNC Project

UniversalBit CNC is a practical toolkit for building, flashing, and operating GRBL-based CNC systems across **AVR (Uno/Nano)**, **ESP8266**, and **ESP32** platforms.

It includes:
- CNCjs setup automation
- Unified firmware flashing workflows
- Hardware wiring references
- G-code toolchain resources

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

This repository provides an end-to-end CNC workflow for makers and workshop automation:

- ⚡ **Multi-target flashing**: AVR, ESP8266, ESP32
- 🖥️ **Web control stack**: CNCjs installation and daemon control
- 🔌 **Wiring knowledge base**: official + practical references
- 🛠️ **Design-to-machine pipeline**: vector tools and G-code plugins

---

## 🖥️ CNCjs Web Interface Controller

The `unbt_cncjs.sh` script manages CNCjs installation and lifecycle operations.

### 1) Install and provision

```bash
sudo ./unbt_cncjs.sh --install
```

### 2) Start CNCjs daemon

```bash
./unbt_cncjs.sh --start
```

### 3) Open workspace

```text
https://localhost:8443/#/workspace
```

or direct local mode:

```text
http://localhost:8000/#/workspace
```

### 4) Stop / restart / logs

```bash
./unbt_cncjs.sh --stop
./unbt_cncjs.sh --restart
./unbt_cncjs.sh --logs
```

---

## 🚀 Firmware Deployment Usage

Use:

`universalbit_grbl_flasher.sh`

Ensure the board is connected, powered, and visible as a serial device before flashing.

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

```bash
# Build from source + flash
sudo ./universalbit_grbl_flasher.sh --chip esp8266 --build-esp8266-from-source --yes

# Reflash existing binary
sudo ./universalbit_grbl_flasher.sh --chip esp8266 --bin "$HOME/grblesp/.pio/build/esp12e/firmware.bin" --yes
```

---

### 🔹 ESP32 (script flow)

```bash
# Build from source + flash
sudo ./universalbit_grbl_flasher.sh --chip esp32 --build-esp32-from-source --yes

# Reflash existing binary (if supported by your current script revision)
sudo ./universalbit_grbl_flasher.sh --chip esp32 --bin "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin" --yes
```

---

### 🔹 ESP32 (manual esptool flow)

```bash
# Erase flash
sudo esptool --chip esp32 --port /dev/ttyUSB0 erase_flash

# Flash bootloader + partitions + firmware
sudo esptool --chip esp32 --port /dev/ttyUSB0 --baud 115200 --before default_reset --after hard_reset write_flash \
  0x1000  "$HOME/Grbl_Esp32/.pio/build/release/bootloader.bin" \
  0x8000  "$HOME/Grbl_Esp32/.pio/build/release/partitions.bin" \
  0x10000 "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin"
```

---

## ⚠️ Troubleshooting

### A) Missing `stub_flasher_32.json`

If you get:

`FileNotFoundError: .../stub_flasher_32.json`

your distro `esptool` package may be incomplete.

#### Recommended fix

```bash
sudo apt remove -y esptool
python3 -m pip install --user --upgrade esptool
~/.local/bin/esptool version
```

Then run `~/.local/bin/esptool ...` or add `~/.local/bin` to your `PATH`.

#### Workaround (`--no-stub`)

```bash
sudo esptool --chip esp32 --no-stub --port /dev/ttyUSB0 erase_flash
sudo esptool --chip esp32 --no-stub --port /dev/ttyUSB0 --baud 115200 \
  write_flash --flash_mode dio --flash_size detect 0x0 "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin"
```

### B) Connected but no physical motion

If UI connects but motors do not move:
- verify stepper drivers are connected and powered
- verify common GND between controller and drivers
- verify ENABLE/STEP/DIR wiring
- check alarm/lock state (`$X`, `$H`, `?`)
- confirm motor power supply is present

---

## 🔌 Hardware Wiring Guides

- [GRBL Wiring (Official)](https://github.com/grbl/grbl/wiki/Connecting-Grbl)
- [DRV8825 CNC Wiring Example (Fritzing)](https://fritzing.org/projects/stepper-motor-with-drv8825-cnc-router-grbl)
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

---

## 📜 Author and License

Created and maintained by **[universalbit-dev](https://github.com/universalbit-dev)**.  
Licensed under the **[GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html)**.

---

## 🤝 Support

If this project helps your CNC workflow, consider starring the repository and sharing it with others in the maker/CNC community.
