# Phone (2a) Series — NetHunter Pro Kernel Build

| | |
|---|---|
| **Codename** | Pacman / PacmanPro |
| **SoC** | MediaTek Dimensity 7200 Pro (MT6886) |
| **CPU** | 2x Cortex-A715 @ 2.8GHz + 6x Cortex-A510 @ 2.0GHz |
| **Arch** | arm64 (ARMv9.0-A) |
| **WiFi Chip** | MT6655 (Connac3, Wi-Fi 6E 2T2R) |
| **WiFi Driver** | gen4m (MediaTek vendor, not upstream mt76) |
| **Kernel** | Linux 5.15 (`android13-5.15`) |
| **Toolchain** | AOSP Clang `r450784e` with `LLVM=1` |
| **Build System** | Kleaf / Bazel |
| **Monitor Mode** | ⚠️ Experimental — sniffer code exists, disabled for MT6655 |

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) | `mt6886/Pacman/v` |
| [Kernel Modules](https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886) | `mt6886/Pacman/v` |

## 1. Build Environment

### Host Requirements

- Ubuntu 22.04+ (x86_64)
- 100GB+ disk space
- 16GB+ RAM

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod

# Install Bazel (Kleaf uses Bazel)
# https://bazel.build/install/ubuntu
sudo apt install -y apt-transport-https gnupg
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings/
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update && sudo apt install -y bazel
```

### Fetch Source

```bash
mkdir nothing-2a-kernel && cd nothing-2a-kernel

# Kernel
git clone -b mt6886/Pacman/v --depth=1 \
  https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886.git kernel

# Kernel modules (contains WLAN gen4m driver)
git clone -b mt6886/Pacman/v --depth=1 \
  https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886.git modules

# AOSP Clang r450784e
mkdir -p prebuilts/clang/host/linux-x86
cd prebuilts/clang/host/linux-x86
git clone --depth=1 \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  -b main clang-r450784e
cd ../../../../
```

> **Note:** AOSP clang prebuilts are large. Alternatively, download only the specific clang version tarball from [Android CI](https://ci.android.com/) or use `repo init` with the Android kernel manifest.

## 2. Kernel Configuration

### USB ConfigFS (NetHunter HID gadget)

Add or enable in your defconfig (check `arch/arm64/configs/`):

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

### Why AOSP Clang, not NDK or GCC?

NothingOSS kernels are built with AOSP prebuilt clang (`LLVM=1`) and the Kleaf build system. The `build.config.common` explicitly sets:

```
LLVM=1
CLANG_PREBUILT_BIN=prebuilts/clang/host/linux-x86/clang-r450784e/bin
```

- **Android NDK** is for userspace (apps/libraries), not kernel compilation. NDK ships a different clang build and sysroot targeting Android libc, which is wrong for kernel builds.
- **Bare-metal GCC** (`aarch64-linux-gnu-gcc`) can technically compile the kernel, but these kernels are tested and validated with AOSP clang + LTO. Using GCC risks subtle ABI mismatches, missing compiler features, and LTO incompatibility.
- Using the **exact AOSP clang version** the vendor used ensures binary compatibility with the stock vendor modules and avoids KMI (Kernel Module Interface) breakage.

## 3. Internal WiFi Monitor Mode (Experimental)

The gen4m WLAN driver has sniffer/radiotap support code, but it is **only enabled for MT6985** in the stock Makefile.

### What exists in the driver source

```
modules/connectivity/wlan/core/gen4m/
├── nic/radiotap.c                  # radiotap header construction
├── include/nic/radiotap.h          # radiotap structures
├── include/config.h                # CFG_SUPPORT_SNIFFER_RADIOTAP flag
├── common/wlan_oid.c               # wlanoidSetIcsSniffer() — firmware sniffer command
└── Makefile                        # CONFIG_SNIFFER_RADIOTAP gated under MT6985 only
```

### How to enable for MT6655

Edit `modules/connectivity/wlan/core/gen4m/Makefile`:

```diff
 ifneq ($(filter MT6655,$(MTK_COMBO_CHIP)),)
 ccflags-y:=$(filter-out -UMT6655,$(ccflags-y))
 ccflags-y += -DMT6655
+CONFIG_SNIFFER_RADIOTAP=y
 ifeq ($(MTK_ANDROID_WMT), y)
```

This enables:
- `CFG_SUPPORT_SNIFFER_RADIOTAP` compile flag
- `CFG_SUPPORT_PDMA_SCATTER` for DMA scatter
- Compilation of `radiotap.o` into the module
- Firmware sniffer command path (`MCU_UNI_CMD_SNIFFER`)

### Caveats

- **Firmware acceptance is unconfirmed.** The driver sends `MCU_UNI_CMD_SNIFFER` to firmware, but MT6655 firmware may silently ignore it.
- **Packet injection (TX)** is almost certainly unsupported without firmware RE.
- **Fallback:** External USB WiFi adapter (see below).

## 4. Build Kernel

### Using Kleaf/Bazel (recommended)

```bash
cd kernel

# Set environment
export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r450784e/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# Build with Kleaf
tools/bazel run //common:kernel_aarch64_dist
```

### Using build.sh (legacy fallback)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r450784e/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

build/build.sh
```

## 5. Build WLAN Module

```bash
cd modules/connectivity/wlan/core/gen4m

export ARCH=arm64
export LLVM=1
export KERNEL_SRC=../../../../../kernel/out

make -C ${KERNEL_SRC} M=$(pwd) \
  LLVM=1 ARCH=arm64 \
  MTK_COMBO_CHIP=MT6655 \
  MTK_ANDROID_WMT=y \
  WLAN_CHIP_ID=6886 \
  modules
```

Output: `wlan_drv_gen4m.ko`

## 6. Flash

Phone (2a) uses **`init_boot`** for kernel images:

```bash
adb reboot bootloader
fastboot flash init_boot <path-to-built-init_boot.img>
fastboot reboot
```

Replace the WLAN module:

```bash
adb push wlan_drv_gen4m.ko /sdcard/
adb shell su -c "mount -o rw,remount /vendor"
adb shell su -c "cp /sdcard/wlan_drv_gen4m.ko /vendor/lib/modules/wlan_drv_gen4m.ko"
adb shell su -c "chmod 644 /vendor/lib/modules/wlan_drv_gen4m.ko"
adb shell su -c "mount -o ro,remount /vendor"
adb reboot
```

## 7. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 8. External WiFi Adapter (Fallback)

If internal WiFi monitor mode does not work, cross-compile rtl8812au against your built kernel:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=<path-to-kernel-out> \
  modules
```

Output: `88XXau.ko` — load after connecting an RTL8812AU-based USB adapter via OTG.
