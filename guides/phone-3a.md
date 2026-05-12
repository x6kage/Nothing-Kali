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

**Internal WiFi monitor mode is not possible.** An external USB WiFi adapter is required for wireless pentesting.

NetHunter Pro is still valuable for: USB HID attacks (DuckyScript, keyboard/mouse emulation), Kali chroot tools (Metasploit, Nmap, Burp), and Bluetooth attacks.

## 1. Build Environment

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod bazel

mkdir nothing-3a-kernel && cd nothing-3a-kernel

git clone -b sm7635/b/mr --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635.git kernel

# AOSP Clang r487747c
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

## 3. Build Kernel

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

## 4. Flash

```bash
adb reboot bootloader
fastboot flash init_boot out/dist/init_boot.img
fastboot reboot
```

## 5. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 6. External WiFi Adapter (Required for WiFi attacks)

Since internal WiFi does not support monitor mode, an external USB adapter is mandatory.

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

Output: `88XXau.ko`

```bash
# After connecting adapter via USB OTG:
adb push 88XXau.ko /sdcard/
adb shell su -c "insmod /sdcard/88XXau.ko"
adb shell su -c "ip link"        # look for wlan1
adb shell su -c "iw dev wlan1 set type monitor"
adb shell su -c "ip link set wlan1 up"
```

### Recommended USB WiFi Adapters

| Adapter | Chipset | Driver | Monitor + Inject |
|---------|---------|--------|:---:|
| Alfa AWUS036ACH | RTL8812AU | rtl8812au | ✅ |
| Alfa AWUS036ACM | MT7612U | mt76 | ✅ |
| Panda PAU09 | RT5572 | rt2800usb | ✅ |
