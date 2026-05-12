# NetHunter Pro Installation

Common installation steps for all Nothing devices after flashing a custom kernel with USB ConfigFS support.

## Prerequisites

- Custom kernel flashed with USB ConfigFS gadget options enabled (see device-specific guides)
- Root access (Magisk / KernelSU / KernelSU Next)
- Unlocked bootloader
- USB debugging enabled
- PC with `adb` and `fastboot`

## 1. Download NetHunter Pro

Download **NetHunter Pro Generic arm64** from the official Kali download page:

👉 https://www.kali.org/get-kali/#kali-mobile

Select:
- **Platform:** Android
- **Type:** NetHunter
- **Architecture:** arm64

This downloads a zip file (e.g., `nethunter-generic-arm64-kalifs-full.zip`).

## 2. Install via Magisk

### Method A: Flash via Magisk Manager

1. Transfer the NetHunter zip to the device:
   ```bash
   adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/
   ```

2. Open **Magisk Manager** → **Modules** → **Install from storage**

3. Select the NetHunter zip and flash

4. Reboot when prompted

### Method B: Flash via TWRP / Custom Recovery

If TWRP or OrangeFox is available for your device:

1. Boot into recovery
2. Flash the NetHunter zip
3. Reboot to system

## 3. Initial Setup

After rebooting:

1. Open **NetHunter** app
2. Grant all requested permissions (root, storage, location)
3. Go to **Kali Chroot Manager**
4. Install the chroot:
   - Select **Full chroot** for maximum tooling
   - Architecture: **arm64**
   - Wait for download and extraction to complete

## 4. Verify USB HID Gadget

Test that USB ConfigFS is working:

```bash
# In NetHunter terminal or Termux with root:
su
ls /config/usb_gadget/
```

If the directory exists and contains gadget configurations, USB HID is functional.

In the NetHunter app:
1. Go to **USB Arsenal**
2. If it shows "Your kernel does not support USB ConfigFS!" → the kernel was not properly configured (re-check the USB ConfigFS kernel options)
3. If it loads normally → USB HID attacks are ready

## 5. Verify WiFi Monitor Mode

### For WCN7850 devices (Phone 3, 4a Pro) with ath12k patches:

```bash
su
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up
iw dev wlan0 info
```

If `type monitor` shows in the output, internal WiFi monitor mode is working.

### For MT6655 devices (Phone 2a) with gen4m sniffer patch:

Check if the sniffer mode activates via the gen4m driver interface. The exact method depends on whether the firmware accepts the sniffer command.

### For WCN6750 devices (Phone 3a, 4a):

Internal WiFi monitor mode is not available. Connect an external USB WiFi adapter and verify:

```bash
su
# After plugging in the adapter:
ip link
# Look for wlan1 or similar
iw dev wlan1 set type monitor
ip link set wlan1 up
```

## 6. Install External WiFi Driver (if needed)

If you built `88XXau.ko` (rtl8812au) from your device-specific guide:

```bash
adb push 88XXau.ko /sdcard/
adb shell su -c "insmod /sdcard/88XXau.ko"
```

To make it persistent across reboots, place it in `/vendor/lib/modules/` or use a Magisk module to load it at boot.

## Tools Available in NetHunter Pro

With a properly configured kernel, you have access to:

| Tool | Requires |
|------|----------|
| USB HID Keyboard/Mouse attacks | USB ConfigFS ✅ |
| DuckyScript execution | USB ConfigFS ✅ |
| RNDIS / USB tethering | USB ConfigFS ✅ |
| Aircrack-ng / WiFi cracking | Monitor mode WiFi |
| Wifite / automated WiFi audit | Monitor mode WiFi |
| Bluetooth tools (Ubertooth) | Ubertooth hardware |
| Metasploit Framework | Kali chroot ✅ |
| Nmap / network scanning | Kali chroot ✅ |
| Burp Suite / web testing | Kali chroot ✅ |
| NetHunter KeX (desktop) | Kali chroot ✅ |

## Troubleshooting

### "Your kernel does not support USB ConfigFS!"
→ Rebuild kernel with all `CONFIG_USB_CONFIGFS_*` options enabled.

### WiFi adapter not detected
→ Check `dmesg | grep -i usb` after plugging in. Make sure the driver module is loaded (`lsmod | grep 88XXau`).

### Chroot fails to install
→ Ensure sufficient storage (full chroot needs ~5-10 GB). Try minimal chroot first.

### Monitor mode crashes
→ Check `dmesg` for kernel panics. For ath12k backports, firmware version mismatch can cause issues — check `/lib/firmware/ath12k/WCN7850/`.
