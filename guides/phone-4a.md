# Phone (4a) — NetHunter Pro Kernel Build

| | |
|---|---|
| **Codename** | Frogger |
| **SoC** | Qualcomm Snapdragon 7s Gen 3 (SM7635) |
| **Arch** | arm64 |
| **WiFi Chip** | WCN6750 (FastConnect, Wi-Fi 6E) |
| **WiFi Driver** | ath11k (`supports_monitor = false`) |
| **Kernel** | Linux 6.1 (`android14-6.1`) |
| **Toolchain** | AOSP Clang `r487747c` with `LLVM=1` |
| **Build System** | Kleaf / Bazel |
| **Monitor Mode** | ❌ Blocked — same WCN6750 firmware limitation as Phone (3a) |

> **Same SoC and WiFi chip as Phone (3a).** The only difference is the kernel branch and device-specific configurations (defconfig, device tree).

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | `sm7635/b/mr_Frogger` |

> **Note:** This uses the same repository as Phone (3a), but a **different branch** (`sm7635/b/mr_Frogger` vs `sm7635/b/mr`).

## WiFi Monitor Mode Status

Same as [Phone (3a)](phone-3a.md#wifi-monitor-mode-status) — WCN6750 firmware does not support monitor mode. External USB WiFi adapter required for wireless attacks.

### What You Get Without Monitor Mode

| Feature | Status |
|---------|:------:|
| USB HID attacks (DuckyScript, BadUSB) | ✅ |
| Kali chroot (Metasploit, Nmap, Burp, etc.) | ✅ |
| USB RNDIS networking | ✅ |
| NetHunter KeX (desktop) | ✅ |
| External USB WiFi (monitor + inject) | ✅ |
| Internal WiFi monitor mode | ❌ |

## 1. Build Environment

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves bazel
```

### Fetch Source

```bash
mkdir nothing-4a-kernel && cd nothing-4a-kernel

# Note: Frogger-specific branch
git clone -b sm7635/b/mr_Frogger --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635.git kernel

# AOSP Clang r487747c (same as Phone 3a)
# If you cloned the Nothing-Kali repo, use:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r487747c
```

## 2. Kernel Configuration

### Defconfig

Phone (4a) uses the same Qualcomm `pineapple` platform as Phone (3a), but with a Frogger-specific vendor config:

```
gki_defconfig                              # GKI base
  + vendor/pineapple_GKI.config            # Qualcomm pineapple platform config
  + vendor/Frogger.config                  # Nothing Phone (4a) device config
```

### USB ConfigFS (NetHunter HID gadget)

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

## 3. Build Kernel

### Using Kleaf/Bazel (recommended)

```bash
cd kernel

# Build for pineapple (SM7635) platform, gki variant
python3 build_with_bazel.py -t pineapple gki
```

### Using legacy make (fallback)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r487747c/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# Assemble defconfig (note: Frogger.config, not Asteroids.config)
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/pineapple_GKI.config \
  arch/arm64/configs/vendor/Frogger.config

# Enable NetHunter configs
./scripts/enable-nethunter-configs.sh . out

# Build
make O=out -j$(nproc)
```

### Verify the Build

```bash
# Check output exists
ls -la out/dist/init_boot.img 2>/dev/null || ls -la out/arch/arm64/boot/Image*

# Verify config
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config

# Use verification script
../scripts/verify-kernel.sh out
```

## 4. Flash

```bash
# Backup (ONCE before first custom kernel flash)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# Flash
adb reboot bootloader
fastboot flash init_boot out/dist/init_boot.img
fastboot reboot
```

## 5. Post-Flash Verification

```bash
# Kernel version
adb shell uname -r

# USB ConfigFS
adb shell su -c "ls /config/usb_gadget/"

# WiFi (managed mode should work)
adb shell su -c "iw dev wlan0 info"
```

## 6. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 7. External WiFi Adapter (Required for WiFi Attacks)

Since internal WiFi does not support monitor mode, build the rtl8812au driver:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

Load after connecting adapter via USB OTG:

```bash
adb push 88XXau.ko /sdcard/
adb shell su -c "insmod /sdcard/88XXau.ko"
adb shell su -c "ip link"
# Look for wlan1 → set to monitor mode
adb shell su -c "iw dev wlan1 set type monitor"
adb shell su -c "ip link set wlan1 up"
```

See [External WiFi Adapters](external-wifi.md) for recommended adapters and persistent driver setup.

## Differences from Phone (3a)

| Aspect | Phone (3a) | Phone (4a) |
|--------|-----------|-----------|
| Codename | Asteroids | Frogger |
| Kernel branch | `sm7635/b/mr` | `sm7635/b/mr_Frogger` |
| Defconfig | Asteroids-specific | Frogger-specific |
| Device tree | `asteroids.dtsi` | `frogger.dtsi` |
| SoC | SM7635 (identical) | SM7635 (identical) |
| WiFi | WCN6750 (identical) | WCN6750 (identical) |
| Clang | `r487747c` (identical) | `r487747c` (identical) |

The build process is identical except for the kernel branch and potentially the defconfig file name. If you encounter an issue specific to Phone (4a) not covered here, check the [Phone (3a) guide](phone-3a.md) — most troubleshooting applies equally.
