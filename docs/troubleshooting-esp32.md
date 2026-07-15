# 📘 Troubleshooting: Resilient ESP32 CNC Simulator

### 1. The Kernel Trap (Missing Drivers)
**Symptom:** The physical USB board is detected by the motherboard (visible via `lsusb`), but no `/dev/ttyUSB` port is created.
**Cause:** Ubuntu distributions optimized for real-time audio or minimal footprints often boot into a `lowlatency` kernel, which strips out standard USB-to-Serial drivers (like CH340 or CP210x).
**The Fix:** 
Install the mainstream generic kernel and set it as the default boot option.

```bash
# Install the generic kernel metapackage
sudo apt-get update
sudo apt-get install linux-generic -y

# Edit GRUB to remember your boot choice
sudo nano /etc/default/grub
# Add/Modify these lines:
# GRUB_DEFAULT=saved
# GRUB_SAVEDEFAULT=true

# Update GRUB and reboot
sudo update-grub
sudo reboot

```

*Note: During the reboot, hold `Shift`, select "Advanced Options", and boot the `-generic` kernel once so the system remembers it permanently.*

---

### 2. The Braille Hijacker (`brltty`)

**Symptom:** The generic kernel is running, the device is detected, but `/dev/ttyUSB0` connects and immediately disconnects, or the port remains completely invisible.
**Cause:** By default, Ubuntu installs `brltty` (a braille terminal reader for the visually impaired). This service aggressively monitors USB ports and instantly hijacks CP2102/CH340 serial chips the moment they are plugged in.
**The Fix:**
Purge the service completely from the system.

```bash
sudo apt-get remove --purge brltty -y

```

---

### 3. 🛡️ Troubleshooting: Permission Denied on Serial Port (`/dev/ttyUSB0`)

**Symptom:** Running `dmesg` shows the `ttyUSB0` port is successfully created, but CNCjs still cannot see it, or your background simulator daemon log throws a `Permission denied, cannot open /dev/ttyUSB0` error.
**Cause:** The process engine (or standard user account) does not have clearance to access the serial hardware. In Linux, standard accounts are blocked from reading serial ports for security reasons.
**Secure Fix: Propagate Linux Group Permissions**
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

*(Note: If you are not running the daemon/background scripts, a simple system reboot will also apply the `dialout` permission change).*

---

### 4. The Hardware Reset Loop (RTS/DTR Lines)

**Symptom:** CNCjs connects to the port, but the console is completely blank. Sending `$$` or `$X` results in total silence, or you get endless garbage text upon connecting.
**Cause:** ESP8266 and ESP32 boards use the USB-to-Serial RTS (Request to Send) and DTR (Data Terminal Ready) pins to trigger their internal bootloaders. If CNCjs holds these lines active when opening the port, the physical reset pin on the ESP chip is held permanently low, keeping it in a frozen/powered-down state.
**The Fix:**
In the CNCjs Connection panel:

* **Uncheck** `Set DTR line status upon opening`.
* **Uncheck** `Set RTS line status upon opening`.
* Ensure the active states are toggled to **CLR** (Clear), not SET.
* Set Baud Rate strictly to **115200** for standard GRBL communication (only use `74880` to debug bootloader crashes).

```

```
