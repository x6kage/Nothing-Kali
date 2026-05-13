# NetHunter Pro Installation

Common installation steps for all Nothing devices after flashing a custom kernel with USB ConfigFS support.

## Prerequisites

- Custom kernel flashed with USB ConfigFS gadget options enabled (see device-specific guides)
- Root access (Magisk / KernelSU / KernelSU Next)
- Unlocked bootloader
- USB debugging enabled (`Settings → Developer options → USB debugging`)
- PC with `adb` and `fastboot`
- ~10 GB free storage on the device (for full chroot)

## 1. アーキテクチャの確認

**全てのNothingデバイスは arm64 (aarch64)** アーキテクチャです。NetHunter Proのダウンロード時に `arm64` を選択してください。

端末上で確認する場合:

```bash
# 方法1: getprop
adb shell getprop ro.product.cpu.abi
# 出力: arm64-v8a  ← これが正しい

# 方法2: uname
adb shell uname -m
# 出力: aarch64  ← これが正しい
```

| 表示 | 意味 | NetHunterの選択 |
|------|------|:---:|
| `arm64-v8a` / `aarch64` | 64-bit ARM | **arm64** ✅ |
| `armeabi-v7a` / `armv7l` | 32-bit ARM | arm (非該当) |
| `x86_64` | Intel/AMD 64-bit | x86_64 (非該当) |

> **重要:** `armhf` や `armel` は選ばないでください。Nothing phoneは全て64-bitです。

## 2. NetHunter Pro のダウンロード

公式ダウンロードページ: https://www.kali.org/get-kali/#kali-mobile

### ダウンロード手順

1. ページを開き **NetHunter** セクションまでスクロール
2. 以下を選択:

| 項目 | 選択する値 | 理由 |
|------|-----------|------|
| **Platform** | Android | — |
| **Type** | NetHunter | Proを含むフルバージョン |
| **Architecture** | **arm64** | Nothing phoneは全てarm64 |

3. ファイル名が `nethunter-generic-arm64-kalifs-full.zip` のようになっていることを確認

### なぜ「Generic」なのか

NetHunter Proのイメージには「デバイス固有」と「Generic」がある:

| タイプ | 説明 | Nothing phoneでは |
|--------|------|:---:|
| **Generic arm64** | 汎用arm64イメージ | ✅ これを使う |
| デバイス固有 (Pixel, OnePlus等) | 特定デバイス向け | ❌ Nothing用は無い |

Nothing phone専用のNetHunterイメージは存在しないため、**Generic arm64** を使用する。カスタムカーネルで USB ConfigFS が有効化されていれば、Generic イメージで全機能が使える。

### イメージバリアント

| Variant | ファイル名に含まれる語 | サイズ | 内容 | 推奨 |
|---------|----------------------|--------|------|:---:|
| **Full** | `kalifs-full` | ~1.5 GB | 完全なツールセット (Metasploit, Nmap, Burp等) | ✅ |
| **Minimal** | `kalifs-minimal` | ~300 MB | 基本ツールのみ。他は `apt` で追加 | ストレージ節約向け |
| **Nano** | `kalifs-nano` | ~100 MB | 最小限 | 非推奨 |

> ダウンロード後、Kaliダウンロードページに記載されたSHA256チェックサムと照合してください:
> ```bash
> # Linux / macOS
> sha256sum nethunter-generic-arm64-kalifs-full.zip
> # Windows (PowerShell)
> Get-FileHash nethunter-generic-arm64-kalifs-full.zip -Algorithm SHA256
> ```

## 2. Install NetHunter

### Method A: Flash via Magisk Manager (Recommended)

1. Transfer the NetHunter zip to the device:
   ```bash
   adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
   ```

2. Open **Magisk Manager** → **Modules** → **Install from storage**

3. Select the NetHunter zip file and flash

4. **Do not reboot yet** — proceed to post-install verification first if you want, or reboot when prompted

### Method B: Flash via KernelSU

KernelSU uses a different module format, but NetHunter's installer detects the root method automatically.

1. Transfer the zip to the device:
   ```bash
   adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
   ```

2. Open **KernelSU Manager** → **Modules** → **Install from storage**

3. Select the NetHunter zip — the installer will detect KernelSU and configure accordingly

4. Reboot when prompted

> **KernelSU Note:** If the NetHunter installer fails to detect KernelSU, you may need to install via terminal:
> ```bash
> adb shell
> su
> cd /sdcard/Download/
> unzip nethunter-generic-arm64-kalifs-full.zip -d /tmp/nethunter/
> sh /tmp/nethunter/META-INF/com/google/android/update-binary "" "" /sdcard/Download/nethunter-generic-arm64-kalifs-full.zip
> ```

### Method C: Flash via Custom Recovery (TWRP / OrangeFox)

If TWRP or OrangeFox is available for your device:

1. Boot into recovery:
   ```bash
   adb reboot recovery
   ```
2. Navigate to **Install** → select the NetHunter zip
3. Swipe to flash
4. Reboot to system

> **Note:** Custom recovery support varies by device. Most Nothing phones don't have official TWRP builds yet. Method A or B is more reliable.

## 3. Initial Setup

After rebooting:

1. **Open the NetHunter app** — it should appear in your app drawer

2. **Grant all permissions** when prompted:
   - Root access (Superuser)
   - Storage
   - Location (for WiFi features)
   - Notification (for background services)

3. **Set up the Kali Chroot:**
   - Go to **Kali Chroot Manager** in the NetHunter app
   - If the chroot wasn't included in the flash, download it:
     - Select **Full chroot** for maximum tooling
     - Architecture: **arm64**
     - Wait for download and extraction (can take 10–30 minutes depending on connection)
   - Once installed, tap **Start Kali Chroot**

4. **Verify the chroot is running:**
   ```bash
   # In NetHunter terminal or a root shell:
   su
   nethunter
   cat /etc/os-release
   # Should show: Kali GNU/Linux
   ```

### First-Time Configuration Inside Chroot

```bash
# Update package lists
apt update

# Upgrade installed packages (optional, takes time)
apt upgrade -y

# Install commonly used tools if not present
apt install -y nmap metasploit-framework aircrack-ng wifite sqlmap john hashcat \
  hydra burpsuite responder seclists wordlists

# Set up Metasploit database
msfdb init
```

## 4. Verify USB HID Gadget

Test that USB ConfigFS is working:

```bash
su
ls /config/usb_gadget/
```

If the directory exists and contains gadget configurations, USB HID is functional.

In the NetHunter app:
1. Go to **USB Arsenal**
2. If it shows "Your kernel does not support USB ConfigFS!" → the kernel was not properly configured
3. If it loads normally → USB HID attacks are ready

### Quick USB HID Test

1. Connect the phone to a target computer via USB
2. In NetHunter → **HID Attacks** → **DuckyScript**
3. Enter a simple script:
   ```
   DELAY 2000
   GUI r
   DELAY 500
   STRING notepad
   DELAY 500
   ENTER
   DELAY 1000
   STRING Hello from NetHunter!
   ```
4. Tap **Execute** — the target computer should open Notepad and type the text

> **Safety:** Only test USB HID on your own machines. The target computer sees the phone as a keyboard/mouse — there is no way for the target to block this at the OS level.

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

Quick capture test:

```bash
# Capture packets for 10 seconds
tcpdump -i wlan0 -c 100 -w /sdcard/capture.pcap

# Or use airodump-ng
airodump-ng wlan0
```

### For MT6655 devices (Phone 2a) with gen4m sniffer patch:

Check if the sniffer mode activates via the gen4m driver interface. The exact method depends on whether the firmware accepts the sniffer command. See the [Phone (2a) guide](phone-2a.md#3-internal-wifi-monitor-mode-experimental) for details.

### For WCN6750 devices (Phone 3a, 4a):

Internal WiFi monitor mode is not available. Connect an external USB WiFi adapter:

```bash
su
# After plugging in the adapter via OTG:
ip link
# Look for wlan1 or similar new interface
iw dev wlan1 set type monitor
ip link set wlan1 up
iw dev wlan1 info
```

See [External WiFi Adapters](external-wifi.md) for recommended adapters and driver setup.

## 6. Install External WiFi Driver (if needed)

If you built `88XXau.ko` (rtl8812au) from your device-specific guide:

```bash
# Push the module
adb push 88XXau.ko /sdcard/

# Load it (temporary — until next reboot)
adb shell su -c "insmod /sdcard/88XXau.ko"

# Verify the module loaded
adb shell su -c "lsmod | grep 88XXau"
```

### Make the Driver Persistent Across Reboots

**Option A: Magisk Module (recommended)**

Create a simple Magisk module that loads the driver at boot:

```bash
mkdir -p /data/adb/modules/rtl8812au/system/vendor/lib/modules/
cp /sdcard/88XXau.ko /data/adb/modules/rtl8812au/system/vendor/lib/modules/

# Create module.prop
cat > /data/adb/modules/rtl8812au/module.prop << 'EOF'
id=rtl8812au
name=RTL8812AU WiFi Driver
version=1.0
versionCode=1
author=Nothing-Kali
description=RTL8812AU driver for external WiFi monitor mode
EOF

# Create post-fs-data.sh to load the module
cat > /data/adb/modules/rtl8812au/post-fs-data.sh << 'EOF'
#!/system/bin/sh
insmod /vendor/lib/modules/88XXau.ko
EOF
chmod 755 /data/adb/modules/rtl8812au/post-fs-data.sh
```

**Option B: Direct placement**

```bash
adb shell su -c "mount -o rw,remount /vendor"
adb shell su -c "cp /sdcard/88XXau.ko /vendor/lib/modules/"
adb shell su -c "chmod 644 /vendor/lib/modules/88XXau.ko"
adb shell su -c "mount -o ro,remount /vendor"
```

## 7. NetHunter KeX (Desktop Mode)

NetHunter KeX provides a full Kali Linux desktop accessible from the phone or remotely:

1. In the NetHunter app → **KeX Manager**
2. Set a VNC password
3. Start the KeX server
4. Connect using:
   - **On phone:** Install a VNC client (e.g., AVNC) and connect to `localhost:5901`
   - **From PC:** `vncviewer <phone-ip>:5901`

## Tools Available in NetHunter Pro

With a properly configured kernel, you have access to:

| Tool | Requires | Description |
|------|----------|-------------|
| USB HID Keyboard/Mouse attacks | USB ConfigFS ✅ | Emulate keyboard/mouse on target machines |
| DuckyScript execution | USB ConfigFS ✅ | Run automated keystroke injection scripts |
| RNDIS / USB tethering | USB ConfigFS ✅ | Create a network interface over USB |
| USB Mass Storage emulation | USB ConfigFS ✅ | Emulate a USB drive |
| Aircrack-ng / WiFi cracking | Monitor mode WiFi | WPA/WPA2 handshake capture and cracking |
| Wifite / automated WiFi audit | Monitor mode WiFi | Automated wireless attacks |
| Kismet / WiFi reconnaissance | Monitor mode WiFi | Passive wireless network discovery |
| Bluetooth tools (Ubertooth) | Ubertooth hardware | BLE sniffing and analysis |
| Metasploit Framework | Kali chroot ✅ | Exploitation framework |
| Nmap / network scanning | Kali chroot ✅ | Network discovery and port scanning |
| Burp Suite / web testing | Kali chroot ✅ | Web application security testing |
| SQLMap / SQL injection | Kali chroot ✅ | Automated SQL injection |
| Responder / LLMNR poisoning | Kali chroot ✅ | Network protocol exploitation |
| John / Hashcat / cracking | Kali chroot ✅ | Password hash cracking |
| NetHunter KeX (desktop) | Kali chroot ✅ | Full Kali desktop via VNC |

## Troubleshooting

### "Your kernel does not support USB ConfigFS!"

The kernel wasn't built with the required CONFIG options. Rebuild with all `CONFIG_USB_CONFIGFS_*` options enabled. See the [kernel config verification script](../scripts/verify-kernel.sh).

### WiFi adapter not detected

```bash
# Check USB device enumeration
dmesg | grep -i usb

# Check if the module loaded
lsmod | grep 88XXau

# Try manual load
insmod /path/to/88XXau.ko

# Check kernel log for errors
dmesg | tail -20
```

### Chroot fails to install

- Ensure sufficient storage: full chroot needs ~5–10 GB
- Try minimal chroot first, then install tools individually via `apt`
- Check `/data/local/nhsystem/` permissions: should be owned by root
- If download fails, manually download the rootfs from Kali and extract:
  ```bash
  wget https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz
  adb push kalifs-arm64-full.tar.xz /sdcard/
  ```

### Monitor mode crashes or fails

```bash
# Check kernel log for panics/errors
dmesg | grep -i -E "ath12k|ath11k|wlan|monitor|panic"

# For ath12k: verify firmware version
ls /vendor/firmware/ath12k/WCN7850/hw2.0/
cat /vendor/firmware/ath12k/WCN7850/hw2.0/board-2.bin.txt 2>/dev/null

# Check if another process holds the interface
iw dev
rfkill list
```

### NetHunter app shows blank screen / crashes

- Clear app data: `Settings → Apps → NetHunter → Clear Data`
- Re-flash the NetHunter zip
- Check if Magisk/KernelSU is properly granting root to the app

### Metasploit database won't start

```bash
# Inside chroot
service postgresql start
msfdb reinit
```

## Next Steps

- **[External WiFi Adapters](external-wifi.md)** — setup external USB WiFi for guaranteed monitor mode + injection
- **[Security Considerations](security.md)** — operational security when using NetHunter
- **[Troubleshooting](troubleshooting.md)** — comprehensive problem-solving guide
