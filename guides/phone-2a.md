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

> **Also applies to:** Phone (2a) Plus (same SoC, kernel, and WiFi chip)

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) | `mt6886/Pacman/v` |
| [Kernel Modules](https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886) | `mt6886/Pacman/v` |

## 1. Build Environment

### Host Requirements

- Ubuntu 22.04+ (x86_64)
- 100GB+ disk space (MediaTek kernel + modules is large)
- 16GB+ RAM (32GB recommended for parallel builds)

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves

# Install Bazel (Kleaf uses Bazel)
# See https://bazel.build/install/ubuntu for the latest instructions
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
./scripts/setup-clang.sh r450784e
# Or manually:
mkdir -p prebuilts/clang/host/linux-x86
cd prebuilts/clang/host/linux-x86
git clone --depth=1 \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  -b main clang-r450784e
cd ../../../../
```

> **Note:** AOSP clang prebuilts are large (~2 GB). Alternatively, download only the specific clang version tarball from [Android CI](https://ci.android.com/) or use `repo init` with the Android kernel manifest.

## 2. Kernel Configuration

### Understanding MediaTek Kernel Structure

MediaTek kernels differ from Qualcomm in several ways:

```
kernel/                           # Main kernel tree
├── arch/arm64/configs/           # Defconfigs
├── drivers/                      # In-tree drivers
└── build.config.*                # Build configuration

modules/                          # Out-of-tree vendor modules
├── connectivity/
│   └── wlan/
│       └── core/
│           └── gen4m/            # ← WiFi driver lives here
├── gpu/
├── display/
└── ...
```

The WiFi driver is **not in the main kernel tree** — it's compiled as an out-of-tree module from the `modules` repo. This means you need to build both the kernel and the WLAN module separately.

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

Or use the helper script after running `make O=out <defconfig>`:

```bash
../scripts/enable-nethunter-configs.sh . out
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
├── nic/radiotap.c                  # Radiotap header construction
├── include/nic/radiotap.h          # Radiotap structures
├── include/config.h                # CFG_SUPPORT_SNIFFER_RADIOTAP flag
├── common/wlan_oid.c               # wlanoidSetIcsSniffer() — firmware sniffer command
├── os/linux/gl_hook_api.c          # Netdev ops including monitor mode
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

### What the code path does

When sniffer mode is enabled:

1. **Driver side:** `wlanoidSetIcsSniffer()` sends `MCU_UNI_CMD_SNIFFER` to the WiFi firmware
2. **Firmware side:** If the firmware supports it, the chip switches to sniffer mode and delivers raw 802.11 frames with radiotap headers
3. **Kernel side:** `radiotap.c` constructs proper radiotap headers for tools like `tcpdump` and `airodump-ng`

### Caveats

- **Firmware acceptance is unconfirmed.** The driver sends `MCU_UNI_CMD_SNIFFER` to firmware, but MT6655 firmware may silently ignore it or return an error.
- **No error logging by default.** Add debug prints around `wlanoidSetIcsSniffer()` to see if the command succeeds:
  ```c
  // In wlan_oid.c, after sending the command:
  DBGLOG(INIT, INFO, "Sniffer command result: %d\n", rStatus);
  ```
- **Packet injection (TX) is almost certainly unsupported** without firmware reverse engineering.
- **Testing method:** After enabling and building, try:
  ```bash
  su
  # Check if the driver exposes sniffer capability
  cat /proc/net/wlan/status
  # Try setting monitor mode via iw
  ip link set wlan0 down
  iw dev wlan0 set type monitor
  ip link set wlan0 up
  ```
- **Fallback:** If monitor mode doesn't work, use an external USB WiFi adapter (see [External WiFi Adapters](external-wifi.md)).

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

### MediaTek-Specific Build Troubleshooting

| Issue | Fix |
|-------|-----|
| `MTK_PLATFORM not defined` | Check `build.config.*` for the correct platform variable |
| `Cannot find DTS include` | MediaTek DTS files may be in `arch/arm64/boot/dts/mediatek/` — check includes |
| Module version mismatch | Ensure kernel and modules repos are from the same branch/tag |
| `CONFIG_MTK_*` errors | These are MediaTek vendor configs — check the defconfig for correct values |

## 5. Build WLAN Module

The WiFi driver must be built separately against the compiled kernel:

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

### Verify the module

```bash
# Check the module was built
ls -la wlan_drv_gen4m.ko

# Check module info
modinfo wlan_drv_gen4m.ko

# If sniffer was enabled, check for the radiotap symbol
nm wlan_drv_gen4m.ko | grep -i radiotap
# Should show radiotap-related symbols if CONFIG_SNIFFER_RADIOTAP=y was effective
```

## 6. Flash

Phone (2a) uses **`init_boot`** for kernel images:

```bash
# Step 1: Backup current init_boot (do this ONCE before first flash)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# Step 2: Reboot to bootloader
adb reboot bootloader

# Step 3: Flash the built kernel
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

> **Important:** Back up the original `wlan_drv_gen4m.ko` before replacing:
> ```bash
> adb shell su -c "cp /vendor/lib/modules/wlan_drv_gen4m.ko /sdcard/stock_wlan_drv_gen4m.ko"
> adb pull /sdcard/stock_wlan_drv_gen4m.ko
> ```

## 7. Post-Flash Verification

```bash
# Check kernel version
adb shell uname -r

# Verify USB ConfigFS
adb shell su -c "ls /config/usb_gadget/"

# Verify WLAN module loaded
adb shell su -c "lsmod | grep wlan"

# Check WiFi is working (normal mode)
adb shell su -c "ip link show wlan0"

# If sniffer patch was applied, check kernel log for radiotap
adb shell su -c "dmesg | grep -i radiotap"
```

## 8. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 9. External WiFi Adapter (Fallback)

If internal WiFi monitor mode does not work (expected for MT6655), cross-compile rtl8812au against your built kernel:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=<path-to-kernel-out> \
  modules
```

Output: `88XXau.ko` — load after connecting an RTL8812AU-based USB adapter via OTG.

See [External WiFi Adapters](external-wifi.md) for recommended adapters and detailed setup.
