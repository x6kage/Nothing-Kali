# Phone (3a) / (3a) Pro — NetHunter Pro Kernel Build

| | |
|---|---|
| **Codename** | Asteroids / AsteroidsPro |
| **SoC** | Qualcomm Snapdragon 7s Gen 3 (SM7635) |
| **Arch** | arm64 |
| **WiFi Chip** | WCN6750 (FastConnect, Wi-Fi 6E) |
| **WiFi Driver** | ath11k (`supports_monitor = false`) |
| **Kernel** | Linux 6.1 (`android14-6.1`) |
| **Toolchain** | AOSP Clang `r487747c` with `LLVM=1` |
| **Build System** | Kleaf / Bazel |
| **Monitor Mode** | ❌ Blocked — firmware limitation, no upstream workaround |

> **Same platform as Phone (4a).** The Phone (4a) (codename Frogger) uses the same SoC and WiFi chip but with a different kernel branch. See [Phone (4a)](phone-4a.md) for the differences.

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | `sm7635/b/mr` |

## WiFi Monitor Mode Status

The WCN6750 WiFi chip has `supports_monitor = false` in the ath11k driver. This is confirmed in the kernel source at `drivers/net/wireless/ath/ath11k/core.c`:

```c
/* wcn6750 hw1.0 */
.supports_monitor = false,
```

This is a **firmware limitation** — the WCN6750 firmware does not implement the monitor mode HAL interface. Unlike WCN7850 (ath12k), no upstream patches exist to enable it.

### Why Can't We Just Flip the Flag?

Unlike the WCN7850 where upstream patches provide a complete monitor mode implementation, the WCN6750's limitation is deeper:

- The firmware doesn't expose monitor mode ring descriptors
- The HAL (Hardware Abstraction Layer) interface for monitor mode is not implemented in firmware
- Flipping `supports_monitor = true` would cause the driver to initialize monitor rings that the firmware doesn't understand, leading to crashes

### What Still Works Without Monitor Mode

**Internal WiFi monitor mode is not possible.** However, NetHunter Pro is still highly valuable:

| Feature | Status | Details |
|---------|:------:|---------|
| USB HID attacks (DuckyScript) | ✅ | Full keyboard/mouse emulation |
| USB RNDIS networking | ✅ | Network over USB cable |
| Kali chroot (Metasploit, Nmap, etc.) | ✅ | Full Kali Linux toolset |
| NetHunter KeX (desktop) | ✅ | Full desktop via VNC |
| External USB WiFi (monitor + inject) | ✅ | Via USB OTG adapter |
| Bluetooth attacks (Ubertooth) | ✅ | Via Ubertooth USB hardware |
| Internal WiFi (managed mode) | ✅ | Normal WiFi works as usual |

## 1. Build Environment

### Host Requirements

- Ubuntu 22.04+ (x86_64)
- 120GB+ disk space
- 16GB+ RAM (32GB recommended for parallel builds)

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves bazel
```

### Fetch Source

```bash
mkdir nothing-3a-kernel && cd nothing-3a-kernel

git clone -b sm7635/b/mr --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635.git kernel

# AOSP Clang r487747c
./scripts/setup-clang.sh r487747c
# Or manually:
mkdir -p prebuilts/clang/host/linux-x86
# Download from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/
```

## 2. Kernel Configuration — USB ConfigFS

```
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_SERIAL=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_USB_CONFIGFS_OBEX=y
CONFIG_USB_CONFIGFS_NCM=y
CONFIG_USB_CONFIGFS_ECM=y
CONFIG_USB_CONFIGFS_ECM_SUBSET=y
CONFIG_USB_CONFIGFS_RNDIS=y
CONFIG_USB_CONFIGFS_EEM=y
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_USB_CONFIGFS_F_HID=y
```

After loading the defconfig:

```bash
make O=out <defconfig>
../scripts/enable-nethunter-configs.sh . out
```

### Finding the Defconfig

```bash
# List available defconfigs for this device
ls arch/arm64/configs/ | grep -i -E 'asteroids|sm7635|gki|vendor'

# Check build config for canonical defconfig
cat build.config.* | grep -i defconfig

# If unsure, extract from running device
adb shell su -c "cat /proc/config.gz" | gunzip > running_config
```

## 3. Build Kernel

### Using Kleaf/Bazel (recommended)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r487747c/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# Kleaf/Bazel
python3 build_with_bazel.py

# or legacy:
# build/build.sh
```

### Build Output Verification

```bash
# Check output files
ls -la out/dist/init_boot.img 2>/dev/null || ls -la out/arch/arm64/boot/Image*

# Verify USB ConfigFS is in the config
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config
# Expected: CONFIG_USB_CONFIGFS_F_HID=y

# Use verification script
../scripts/verify-kernel.sh out
```

## 4. Flash

```bash
# Backup (do this ONCE before first custom kernel flash)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# Flash
adb reboot bootloader
fastboot flash init_boot out/dist/init_boot.img
fastboot reboot
```

## 5. Post-Flash Verification

```bash
# Check kernel version changed
adb shell uname -r

# Verify USB ConfigFS is available
adb shell su -c "ls /config/usb_gadget/"

# Verify WiFi still works (managed mode)
adb shell su -c "iw dev wlan0 info"
```

## 6. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 7. External WiFi Adapter (Required for WiFi Attacks)

Since internal WiFi does not support monitor mode, an external USB adapter is mandatory for wireless penetration testing.

### Build rtl8812au Driver

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

Output: `88XXau.ko`

### Load and Test

```bash
# After connecting adapter via USB OTG:
adb push 88XXau.ko /sdcard/
adb shell su -c "insmod /sdcard/88XXau.ko"
adb shell su -c "ip link"        # look for wlan1
adb shell su -c "iw dev wlan1 set type monitor"
adb shell su -c "ip link set wlan1 up"
adb shell su -c "iw dev wlan1 info"   # should show type: monitor
```

### Recommended USB WiFi Adapters

| Adapter | Chipset | Driver | Monitor + Inject | Notes |
|---------|---------|--------|:---:|-------|
| Alfa AWUS036ACH | RTL8812AU | rtl8812au | ✅ | Best for dual-band, high power |
| Alfa AWUS036ACHM | RTL8812AU | rtl8812au | ✅ | Smaller form factor |
| Alfa AWUS036ACM | MT7612U | mt76 | ✅ | Good kernel support |
| Panda PAU09 | RT5572 | rt2800usb | ✅ | Budget option |

See [External WiFi Adapters](external-wifi.md) for detailed setup and comparison.
