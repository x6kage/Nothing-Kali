# External WiFi Adapters

A guide to choosing, setting up, and using external USB WiFi adapters with Nothing phones for monitor mode and packet injection.

## Why External Adapters?

Internal WiFi monitor mode is only available on Phone (3) and Phone (4a) Pro (with kernel patches). All other devices require an external USB WiFi adapter for wireless pentesting. Even on devices with internal monitor mode, external adapters provide:

- **Reliable packet injection** — internal WiFi firmware may limit TX in monitor mode
- **Dual-radio operation** — stay connected to WiFi on internal radio while monitoring on external
- **Higher TX power** — some external adapters have amplifiers and external antennas
- **Band selection** — choose adapters optimized for 2.4GHz, 5GHz, or both

## Recommended Adapters

### Tier 1: Best Overall

| Adapter | Chipset | Bands | Driver | Monitor | Inject | Price Range |
|---------|---------|-------|--------|:---:|:---:|-------------|
| **Alfa AWUS036ACH** | RTL8812AU | 2.4 + 5 GHz | rtl8812au | ✅ | ✅ | ~$50 |
| **Alfa AWUS036ACHM** | RTL8812AU | 2.4 + 5 GHz | rtl8812au | ✅ | ✅ | ~$45 |
| **Alfa AWUS036ACM** | MT7612U | 2.4 + 5 GHz | mt76 | ✅ | ✅ | ~$40 |

### Tier 2: Budget Options

| Adapter | Chipset | Bands | Driver | Monitor | Inject | Price Range |
|---------|---------|-------|--------|:---:|:---:|-------------|
| **Panda PAU09** | RT5572 | 2.4 + 5 GHz | rt2800usb | ✅ | ✅ | ~$20 |
| **TP-Link TL-WN722N v1** | AR9271 | 2.4 GHz only | ath9k_htc | ✅ | ✅ | ~$15 |
| **Alfa AWUS036NHA** | AR9271 | 2.4 GHz only | ath9k_htc | ✅ | ✅ | ~$25 |

### Tier 3: WiFi 6/6E (Advanced)

| Adapter | Chipset | Bands | Driver | Monitor | Inject | Notes |
|---------|---------|-------|--------|:---:|:---:|-------|
| **Alfa AWUS036AXML** | MT7921AU | 2.4 + 5 + 6 GHz | mt76 | ✅ | ⚠️ | WiFi 6E, injection limited |
| **Netgear A8000** | MT7921AU | 2.4 + 5 + 6 GHz | mt76 | ✅ | ⚠️ | WiFi 6E |

> **Note on WiFi 6E adapters:** Monitor mode works, but packet injection support is still maturing in the mt76 driver. For reliable injection, Tier 1 adapters are recommended.

### Choosing an Adapter

| Use Case | Best Choice | Why |
|----------|-------------|-----|
| WPA/WPA2 cracking | Alfa AWUS036ACH | Dual-band, high TX power, reliable injection |
| Portable / travel | Alfa AWUS036ACHM | Small form factor, same chipset as ACH |
| Budget / learning | Panda PAU09 or TP-Link TL-WN722N v1 | Cheap, well-supported |
| WiFi 6E targets | Alfa AWUS036AXML | 6 GHz band support |
| Maximum compatibility | Alfa AWUS036ACM | mt76 has excellent kernel support |

## Hardware Setup

### USB OTG Connection

Nothing phones support USB OTG. You need:

1. **USB-C OTG adapter** (USB-C male → USB-A female)
2. **USB WiFi adapter** plugged into the OTG adapter

Some options:
- Simple USB-C to USB-A OTG adapter (~$5)
- USB-C hub with USB-A ports (allows charging while using adapter)
- Direct USB-C to Micro-USB OTG cable (for older adapters)

### Verifying USB OTG Works

```bash
# Plug in the adapter, then check
adb shell su -c "dmesg | tail -20"
# Look for USB device enumeration messages

adb shell su -c "lsusb"
# Should show the adapter (e.g., "0bda:8812" for RTL8812AU)
```

## Driver Setup

### RTL8812AU (Realtek)

The most commonly used adapter chipset. Requires building an out-of-tree module.

#### Cross-Compile on Build Host

```bash
# Clone the aircrack-ng maintained fork
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

# Build against your custom kernel
make ARCH=arm64 LLVM=1 \
  KSRC=<path-to-kernel-out-directory> \
  modules

# Output: 88XXau.ko
```

Or use the provided helper script:

```bash
./scripts/build-rtl8812au.sh <path-to-kernel-out>
```

#### Load on Device

```bash
# Push the module
adb push 88XXau.ko /sdcard/

# Load (temporary — until next reboot)
adb shell su -c "insmod /sdcard/88XXau.ko"

# Verify
adb shell su -c "lsmod | grep 88XXau"
adb shell su -c "ip link"    # look for wlan1
```

#### Make Persistent

Create a Magisk module:

```bash
adb shell
su

mkdir -p /data/adb/modules/rtl8812au/system/vendor/lib/modules/
cp /sdcard/88XXau.ko /data/adb/modules/rtl8812au/system/vendor/lib/modules/

cat > /data/adb/modules/rtl8812au/module.prop << 'EOF'
id=rtl8812au
name=RTL8812AU WiFi Driver
version=1.0
versionCode=1
author=Nothing-Kali
description=RTL8812AU driver for external WiFi monitor mode
EOF

cat > /data/adb/modules/rtl8812au/post-fs-data.sh << 'EOF'
#!/system/bin/sh
insmod /vendor/lib/modules/88XXau.ko
EOF
chmod 755 /data/adb/modules/rtl8812au/post-fs-data.sh
```

### MT7612U / MT7921AU (MediaTek)

The mt76 driver is mainlined in the Linux kernel. If your custom kernel build includes `CONFIG_MT76_USB=m` and `CONFIG_MT7612U=m`, the driver may already be available.

```bash
# Check if mt76 modules exist
adb shell su -c "find /vendor/lib/modules/ -name '*mt76*'"

# If present, they should load automatically when the adapter is plugged in
# If not, build from source:
cd kernel
make O=out M=drivers/net/wireless/mediatek/mt76 modules
```

### AR9271 / RT5572 (Atheros / Ralink)

These chipsets use in-kernel drivers (`ath9k_htc`, `rt2800usb`) that are typically included in Android kernels. They may work out of the box.

```bash
# Plug in adapter and check
adb shell su -c "dmesg | grep -i 'ath9k\|rt2800\|usb'"
adb shell su -c "ip link"
```

If the driver isn't loaded, ensure the relevant CONFIG options are enabled in your kernel build:

```
CONFIG_ATH9K_HTC=m        # For AR9271
CONFIG_RT2800USB=m         # For RT5572
```

## Using Monitor Mode

### Basic Setup

```bash
su

# Identify the external interface
ip link
# Internal WiFi: wlan0
# External adapter: typically wlan1

# Set to monitor mode
ip link set wlan1 down
iw dev wlan1 set type monitor
ip link set wlan1 up

# Verify
iw dev wlan1 info
# type should show "monitor"
```

### Channel Selection

```bash
# Set specific channel
iw dev wlan1 set channel 6          # 2.4 GHz channel 6
iw dev wlan1 set channel 36         # 5 GHz channel 36
iw dev wlan1 set channel 36 HT40+   # 40 MHz width
iw dev wlan1 set channel 36 80MHz    # 80 MHz width (if supported)
```

### Common Tools

```bash
# Network discovery
airodump-ng wlan1

# Target specific network (channel 6, BSSID filter)
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w capture wlan1

# Deauthentication (authorized testing only)
aireplay-ng -0 5 -a AA:BB:CC:DD:EE:FF wlan1

# WPA handshake capture + crack
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w handshake wlan1
# (wait for handshake capture)
aircrack-ng -w /usr/share/wordlists/rockyou.txt handshake-01.cap

# Automated audit
wifite --interface wlan1

# Passive packet capture
tcpdump -i wlan1 -w /sdcard/capture.pcap
```

### Dual-Radio Operation

One of the biggest advantages of an external adapter: stay connected to WiFi on the internal radio while pentesting on the external one.

```bash
# Internal (wlan0): connected to your home WiFi for internet
# External (wlan1): in monitor mode for pentesting

ip link set wlan1 down
iw dev wlan1 set type monitor
ip link set wlan1 up

# Internal WiFi still works for internet, data transfer, etc.
# External WiFi captures packets independently
```

## Troubleshooting

### Adapter Not Detected

```bash
# Check USB enumeration
adb shell su -c "dmesg | grep -i usb"
adb shell su -c "lsusb"

# If lsusb doesn't show the adapter:
# - Try a different OTG adapter/cable
# - Check if USB OTG is enabled in developer options
# - Some adapters draw too much power — use a powered USB hub
```

### Module Won't Load

```bash
# Check for errors
adb shell su -c "dmesg | tail -20"

# Common issues:
# "version magic mismatch" → module built against wrong kernel
# "Unknown symbol" → missing dependency module
# "Operation not permitted" → SELinux blocking → try: setenforce 0
```

### Monitor Mode Fails

```bash
# Check if monitor is in supported modes
adb shell su -c "iw phy phy1 info | grep -A 10 'Supported interface modes'"

# Check rfkill
adb shell su -c "rfkill list"
# If the adapter is soft-blocked: rfkill unblock all
```

### Low Signal / Poor Performance

- Check antenna connections on the adapter
- Try different USB OTG adapter (some have poor shielding)
- Use a USB extension cable to position the adapter away from the phone body
- Enable TX power boost (adapter-dependent):
  ```bash
  iw dev wlan1 set txpower fixed 3000    # 30 dBm (check regulatory limits)
  ```
