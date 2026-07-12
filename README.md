![Arduino Uno Tested](https://img.shields.io/badge/Arduino_Uno-Tested-blue?style=flat-square&logo=arduino)
![Arduino Nano Tested](https://img.shields.io/badge/Arduino_Nano-Tested-blue?style=flat-square&logo=arduino)
![ESP8266 Tested](https://img.shields.io/badge/ESP8266-Tested-brightgreen?style=flat-square&logo=espressif)
![ESP32 Tested](https://img.shields.io/badge/ESP32-Tested-brightgreen?style=flat-square&logo=espressif)
# UniversalBit CNC Project
This repository provides resources, instructions, and tools for setting up and operating CNC router machines. It includes wiring guides, firmware installation, and G-code tools to help you get started with CNC projects.

![CNC Machine](https://github.com/universalbit-dev/cnc-router-machines/blob/main/assets/images/universalbit_cnc_project.png)

---

## Table of Contents
1. [Overview](#overview)
2. [Getting Started](#getting-started)
   - [Upload GRBL Firmware](#upload-grbl-firmware)
   - [Wiring Guides](#wiring-guides)
3. [G-Code Tools](#g-code-tools)
4. [Additional Resources](#additional-resources)
5. [Author and License](#author-and-license)

---

## Overview

This repository features a detailed guide for building and managing CNC router machines. With support for GRBL firmware and tools like InkScape, it's tailored for hobbyists and makers aiming to create efficient and cost-effective CNC setups.

Supported Features:
- Firmware installation.
- Wiring diagrams for CNC routers and 3D printers.
- G-code generation and laser tools.
- Compatibility with CNCjs for machine control.

## 🖥️ CNCjs Web Interface Controller

The `unbt_cncjs.sh` script automates the installation, daemon management, and execution of the CNCjs web-based interface tool ecosystem. It provides a clean terminal control stack to spin up the server environment on your local thin client or single-board computer (like a Raspberry Pi).

### 🔹 Step 1: Initialize First-Time Deployment
To automatically check system dependencies (Node.js/NPM), pull down the core packages, and configure local firewall exceptions:
```bash
./unbt_cncjs.sh --install

```

### 🔹 Step 2: Spin Up the Controller Stack

To boot the CNCjs production server engine running quietly in the background as a localized persistent service process:

```bash
./unbt_cncjs.sh --start
```

### 🌐 Accessing the Interface

Depending on how your network environment is configured, you can access the CNCjs workspace via two pathways:
> 💡 *Once started, open your web browser and navigate directly to: **`http://localhost:8000`** (or your machine's local network IP).*

* **🔒 Secure HTTPS Mode (Recommended):** If you are running Nginx or Apache2 using the generated configuration templates from this script, navigate securely to port `8443`:
  ```text
  https://localhost:8443/#/workspace
  ```
### 🔹 Step 3: Stop or Restart the Server Environment

If you need to drop active socket states, clear interface terminal locks, or power down the system framework completely:

```bash
# To safely stop the server daemon process
./unbt_cncjs.sh --stop

# To forcefully reboot the communication socket framework
./unbt_cncjs.sh --restart

```

### 🔹 Step 4: Live Log Inspection

To read real-time traffic outputs, monitor active serial mapping protocols, or debug data handshake issues between CNCjs and your microcontrollers:

```bash
./unbt_cncjs.sh --logs

```

![CNCjs Example](https://github.com/universalbit-dev/cnc-router-machines/blob/main/g-code/mandala/cncjs/mandala_cncjs.png)

---

## Getting Started

### Upload GRBL Firmware:
---
## 🚀 Firmware Deployment Usage

Use the utility script to flash your targeted microcontroller architecture automatically. Ensure your device is connected via USB and powered ON.

### 🔹 Arduino Uno / Nano (AVR Architecture)
To flash the pre-compiled standard AVR `.hex` engine directly onto an Arduino layout:
```bash
sudo ./universalbit_grbl_flasher.sh --chip avr --yes

```

### 🔹 ESP8266

To automatically compile the ESP8266 controller firmware locally from the available source files:

```bash
sudo ./universalbit_grbl_flasher.sh --chip esp8266 --build-esp8266-from-source --yes

```

Alternatively, if you already have a compiled binary snapshot file ready, point the script directly to its local path payload:

```bash
sudo ./universalbit_grbl_flasher.sh --chip esp8266 --bin "$HOME/grblesp/.pio/build/esp12e/firmware.bin" --yes

```

### 🔹 ESP32 Controllers

Because the ESP32 chip family features a multi-tiered structural partition layout, you can bypass standard tools and use `esptool` directly.

First, execute a deep physical storage wipe on the chip's internal sector memory:

```bash
sudo esptool --chip esp32 --no-stub --port /dev/ttyUSB0 erase_flash

```

Next, burn your locally compiled PlatformIO custom release binary directly into the root execution address space (`0x0`):

```bash
sudo esptool --chip esp32 --no-stub --port /dev/ttyUSB0 --baud 115200 \
  write_flash --flash_mode dio --flash_size detect 0x0 "$HOME/Grbl_Esp32/.pio/build/release/firmware.bin"

```

To upload GRBL firmware to an Arduino Nano Shield v3, follow the guide provided in the **[UniversalBit Project CNC Section](https://github.com/universalbit-dev/universalbit-dev/tree/main/cnc)**.

#### GRBL Firmware Release
- **Version**: [Grbl v1.1](https://github.com/gnea/grbl/releases)


### Wiring Guides

For connecting components, refer to the following resources:
- [GRBL Wiring Guide](https://github.com/grbl/grbl/wiki/Connecting-Grbl)
- [Fritzing CNC-Router-Grbl Project](https://fritzing.org/projects/stepper-motor-with-drv8825-cnc-router-grbl)
- [MakerBase MKS-DLC32 Wiring Manual](https://github.com/makerbase-mks/MKS-DLC32/blob/main/MKS-DLC32-main/doc/DLC32%20wiring%20manual.pdf)
- [Raspberry Pi CNC](https://wiki.protoneer.co.nz/Raspberry_Pi_CNC)

---

## G-Code Tools

Generate and manage G-code for CNC and laser cutting using the following tools:
- [InkScape Version 1.3.2](https://inkscape.org/de/release/inkscape-1.3.2/)
- [InkScape Gcodetools](https://github.com/inkscape/inkscape)
- [InkScape LaserTools Plugin](https://github.com/ChrisWag91/Inkscape-Lasertools-Plugin)

---

## Additional Resources

Explore more about CNC router machines and their applications:
- [CNCjs](https://github.com/cncjs/cncjs): A web-based interface for CNC controllers.
- [MakerBase MKS-DLC32](https://github.com/makerbase-mks/MKS-DLC32)
---

### CNC Components Gallery:
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/assets/images/wemos_d1_arduino/wemos_d1_arduino.png" width="9%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/assets/images/wemos_d1_arduino/cnc_shield.png" width="9%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/assets/images/arduino_nano_cnc_shield/arduino_nano.png" width="9%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/assets/images/arduino_nano_cnc_shield/arduino_nano_cnc_shield.png" width="9%"></img>
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_001.jpg" width="10%"></img>
---
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_001.jpg" width="40%" ></img>
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/BeamCap-BeltHolder-ZCartHolder.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/BeltHolderBeamCap.png" width="10%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/BeltHolderBrace.png" width="10%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/CartEndLeft.png" width="10%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/Cart_Connector.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/Cart_Connector2.png" width="10%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/Cart_Connector3.png" width="10%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/Cart_EndRight.png" width="10%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/LeftCartInside.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/LeftCartOutside.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/MotorSpacer-YBlockHolder.png" width="10%"></img>
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/MotorSpacer-ZCartEndSpace.png" width="10%"></img> 
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/RightCartInside.png" width="10%"></img> 
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/RightCartOutside.png" width="10%"></img> 
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/XBearingBlockHolder.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/XCartCap.png" width="10%"></img>
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/XCartCap2.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/Z-RailRunner.png" width="10%"></img> 
<img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/Z-RailSpacer.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/ZCartEndNut-ZCartHolderB.png" width="5%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/ZCartEndSpace-ZCartEndNut.png" width="5%"></img> <img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/ZCartHolderA.png" width="10%"></img><img src="https://github.com/universalbit-dev/cnc-router-machines/blob/main/cnc/cnc_a4/ZRailBack.png" width="5%"></img> 
##### Author and License
Original CNC router machine component,parts,designs and guides by [oomlout](https://www.instructables.com/How-to-Make-a-Three-Axis-CNC-Machine-Cheaply-and-/), shared under the [CC BY-SA 4.0 License](https://creativecommons.org/licenses/by-sa/4.0/).

---

## 📢 Support the UniversalBit Project
Help us grow and continue innovating!  
- [Support the UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support)  
- [Learn about Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation)  
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
