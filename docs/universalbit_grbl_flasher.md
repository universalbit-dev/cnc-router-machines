# universalbit_grbl_flasher.sh

Universal firmware flasher for CNC controllers based on **AVR**, **ESP32**, and **ESP8266**.

This script automates detection, download, build, and flashing of GRBL-based firmware for supported controller boards.

## Supported targets

- **AVR**
  - Uses prebuilt `gnea/grbl` hex release
  - Typical boards: Arduino Uno / Nano with ATmega328P

- **ESP32**
  - Supports flashing a prebuilt firmware binary
  - Supports building from `bdring/Grbl_Esp32` source with PlatformIO

- **ESP8266**
  - Supports flashing a user-provided binary
  - Supports building from `gcobos/grblesp` source with PlatformIO
  - If no binary or source-build option is provided, it performs **erase-only**

---

## Main features

- Automatic serial port detection
- Automatic chip probing:
  - `esp32`
  - `esp8266`
  - fallback to `avr`
- Root/sudo enforcement for flashing operations
- Automatic installation of missing dependencies where possible
- PlatformIO auto-installation for the invoking user
- Git repository clone/fetch support for source builds
- Safety checks to avoid flashing obvious wrong-chip binaries
- Interactive confirmation, with optional non-interactive mode

---

## Requirements

Run on a Debian/Ubuntu-like Linux system with:

- `bash`
- `sudo`
- `apt-get`
- USB serial device access
- Internet connection for downloading firmware, dependencies, or source repos

The script can install missing tools such as:

- `curl`
- `git`
- `esptool`
- `avrdude`
- `pipx`
- `python3-venv`

---

## Usage

```bash
sudo ./universalbit_grbl_flasher.sh [options]
```

### Core options

- `--port <device>`  
  Serial port device, for example `/dev/ttyUSB0` or `/dev/ttyACM0`

- `--chip <auto|avr|esp32|esp8266>`  
  Select target chip manually or let the script auto-detect it

- `--yes`  
  Skip interactive confirmation prompt

- `--bin <file>`  
  Use a custom firmware binary file  
  Intended for ESP targets

---

## ESP32 options

- `--build-esp32-from-source`  
  Build firmware locally with PlatformIO before flashing

- `--esp32-repo-dir <path>`  
  Local checkout directory for `Grbl_Esp32`  
  Default: `~/Grbl_Esp32`

- `--esp32-git-url <url>`  
  Git repository URL  
  Default: `https://github.com/bdring/Grbl_Esp32.git`

- `--esp32-git-ref <ref>`  
  Optional branch, tag, or commit to checkout

- `--esp32-pio-env <env>`  
  Optional PlatformIO environment name

- `--esp32-tag <tag>`  
  Release tag used when downloading prebuilt firmware  
  Default: `v1.3a`

---

## ESP8266 options

- `--build-esp8266-from-source`  
  Build firmware locally with PlatformIO before flashing

- `--esp8266-repo-dir <path>`  
  Local checkout directory for `grblesp`  
  Default: `~/grblesp`

- `--esp8266-git-url <url>`  
  Git repository URL  
  Default: `https://github.com/gcobos/grblesp.git`

- `--esp8266-git-ref <ref>`  
  Optional branch, tag, or commit to checkout

- `--esp8266-pio-env <env>`  
  Optional PlatformIO environment name

---

## AVR options

- `--avr-tag <tag>`  
  Release tag from `gnea/grbl`  
  Default: `v1.1h.20190825`

---

## Typical examples

### Flash AVR-based GRBL board

```bash
sudo ./universalbit_grbl_flasher.sh --chip avr --port /dev/ttyUSB0 --yes
```

### Build and flash ESP32 from source

```bash
sudo ./universalbit_grbl_flasher.sh \
  --chip esp32 \
  --build-esp32-from-source \
  --esp32-repo-dir /home/unbt/Grbl_Esp32 \
  --yes
```

### Flash ESP32 from a prebuilt binary

```bash
sudo ./universalbit_grbl_flasher.sh \
  --chip esp32 \
  --bin /path/to/firmware.bin \
  --yes
```

### Build and flash ESP8266 from source

```bash
sudo ./universalbit_grbl_flasher.sh \
  --chip esp8266 \
  --build-esp8266-from-source \
  --esp8266-repo-dir /home/unbt/grblesp \
  --yes
```

### Flash ESP8266 from a binary

```bash
sudo ./universalbit_grbl_flasher.sh \
  --chip esp8266 \
  --bin /home/unbt/grblesp/.pio/build/<env>/firmware.bin \
  --yes
```

### Erase only an ESP8266

```bash
sudo ./universalbit_grbl_flasher.sh --chip esp8266 --yes
```

---

## How it works

## 1. Environment preparation

At startup, the script:

- checks that it is run as root
- ensures required tools are installed
- detects the serial port if not provided
- ensures the invoking user is in the `dialout` group

## 2. Chip detection

The script uses `esptool chip_id` on the selected serial port:

- if output contains `ESP8266` → target is `esp8266`
- if output contains `ESP32` → target is `esp32`
- otherwise it falls back to `avr`

A manual `--chip` selection overrides auto-detection.

## 3. Confirmation

Unless `--yes` is supplied, the script asks:

```text
Proceed with flash installation? (yes/no):
```

## 4. Flash flow by target

### AVR
- Downloads `grbl_v1.1h.20190825.hex` if missing
- Tries multiple `avrdude` strategies:
  1. `arduino` @ 57600
  2. `stk500v1` @ 57600
  3. `arduino` @ 115200

### ESP32
- Uses `--bin` if supplied
- Otherwise builds from source if requested
- Otherwise downloads a release binary
- Erases flash with `esptool`
- Writes firmware at address `0x0`

### ESP8266
- Uses `--bin` if supplied
- Otherwise builds from source if requested
- Otherwise performs erase-only
- Erases flash with `esptool`
- Writes firmware at address `0x0` when a binary is available

---

## Functions overview

### `usage()`
Prints command help and example invocations.

### `need_cmd()`
Checks whether a command exists in `PATH`.

### `install_pkg_if_missing()`
Installs a missing package via `apt-get`.

### `download_file()`
Downloads a file with `curl` using retry logic.

### `expand_path_for_user()`
Expands `~` using the original sudo user’s home directory.

### `require_root()`
Stops execution unless the script is run as root.

### `confirm_or_exit()`
Prompts user confirmation unless `--yes` is enabled.

### `detect_port()`
Finds the first available serial device from:
- `/dev/ttyUSB*`
- `/dev/ttyACM*`

### `ensure_dialout_group()`
Adds the invoking user to the `dialout` group if needed.

### `ensure_platformio_for_user()`
Ensures `pio` is installed for the original non-root user using `pipx`.

### `chip_probe()`
Uses `esptool` to identify whether the target is ESP32, ESP8266, or fallback AVR.

### `ensure_git_repo()`
Clones a repository if missing, otherwise fetches updates and optional ref checkout.

### `build_with_pio()`
Builds firmware using PlatformIO and returns the path to `firmware.bin`.

### `validate_bin_for_chip()`
Performs basic binary-path safety checks, currently focused on ESP8266 vs ESP32 mixups.

### `flash_esp32()`
Handles download/build selection, erase, and flashing for ESP32.

### `flash_esp8266()`
Handles download/build selection, erase, and flashing for ESP8266.

### `flash_avr()`
Downloads AVR firmware if needed and flashes it with fallback `avrdude` strategies.

---

## Safety behavior

The script includes basic cross-chip protection:

- If `--chip esp32` is selected but probe detects `esp8266`, it aborts
- If `--chip esp8266` is selected but probe detects `esp32`, it aborts
- For ESP8266, it refuses binaries whose path suggests they came from `Grbl_Esp32`

---

## Notes and limitations

- The script assumes `apt-get` is available
- It is intended primarily for Linux systems
- AVR support is currently tuned for **ATmega328P**
- ESP flashing writes firmware at `0x0`, which may not fit every custom firmware layout
- Binary validation is minimal and mostly path-based
- If multiple serial ports are connected, the first detected one is used unless `--port` is specified

---

## Recommended improvements

Possible future enhancements:

- stronger firmware validation using file inspection instead of path hints
- support for more AVR MCUs and board profiles
- better serial port selection when multiple devices are connected
- checksum verification for downloaded release artifacts
- configurable flash offsets for ESP targets
- dry-run mode
- verbose/debug logging option

---

## Exit behavior

The script exits immediately on errors because it uses:

```bash
set -Eeuo pipefail
```

This improves safety during flashing operations.

---

## Related upstream projects

- `gnea/grbl`
- `bdring/Grbl_Esp32`
- `gcobos/grblesp`
