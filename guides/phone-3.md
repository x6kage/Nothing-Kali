# Phone (3) — NetHunter Pro Kernel Build

| | |
|---|---|
| **Codename** | Metroid |
| **SoC** | Qualcomm Snapdragon 8s Gen 4 (SM8735) |
| **Arch** | arm64 |
| **WiFi Chip** | WCN7850 (FastConnect 7800, Wi-Fi 7) |
| **WiFi Driver** | ath12k |
| **Kernel** | Linux 6.6 (`android15-6.6`) |
| **Toolchain** | AOSP Clang `r510928` with `LLVM=1` |
| **Build System** | Kleaf / Bazel |
| **Monitor Mode** | 🔧 Patchable — upstream ath12k added WCN7850 support (Apr 2025) |

> **Best device for internal WiFi pentesting** — the WCN7850 is a modern Wi-Fi 7 chip with well-maintained upstream Linux support. The Phone (4a) Pro shares the same WiFi chip and driver.

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735) | `sm8735/b/mr` |

## 1. Build Environment

### Host Requirements

- Ubuntu 22.04+ (x86_64)
- 150GB+ disk space (Qualcomm kernel trees are larger than MediaTek)
- 16GB+ RAM (32GB recommended)

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves

# Bazel (for Kleaf)
sudo apt install -y bazel
```

### Fetch Source

```bash
mkdir nothing-3-kernel && cd nothing-3-kernel

git clone -b sm8735/b/mr --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735.git kernel

# AOSP Clang r510928
# If you cloned the Nothing-Kali repo, use:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r510928
# Or manually:
mkdir -p prebuilts/clang/host/linux-x86
# Download r510928 from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/
# or from Android CI build artifacts
```

### Why AOSP Clang?

The kernel config specifies `LLVM=1` and `CLANG_VERSION=r510928`. This is **not** the same as Android NDK clang:

- **NDK clang** targets Android userspace (linked against Bionic libc, Android sysroot). Compiling a kernel with NDK clang will fail or produce subtly broken binaries.
- **AOSP prebuilt clang** is a bare-metal compiler configured for kernel builds, matching what Nothing/Qualcomm used to build and test the stock kernel.
- GKI (Generic Kernel Image) kernels enforce KMI symbol checking — using a different compiler can break KMI compatibility, preventing vendor modules from loading.

## 2. Kernel Configuration

### Defconfig

Phone (3) uses the Qualcomm `sun` platform. The defconfig is assembled from layers:

```
gki_defconfig                          # GKI base (in arch/arm64/configs/)
  + vendor/sun_perf.config             # Qualcomm sun platform config
  + vendor/Metroid.config              # Nothing Phone (3) device config
```

With Kleaf/Bazel (recommended), the build system assembles the defconfig automatically when you specify the correct target (`sun`) and variant (`perf`).

For legacy `make` builds, assemble manually:

```bash
# Start with GKI base
make O=out gki_defconfig

# Merge vendor fragments
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/sun_perf.config \
  arch/arm64/configs/vendor/Metroid.config
```

### USB ConfigFS (NetHunter HID gadget)

After loading the defconfig, enable USB ConfigFS:

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

Or use the helper script:

```bash
./scripts/enable-nethunter-configs.sh . out
```

## 3. Enable WCN7850 Monitor Mode

The stock NothingOSS kernel has `supports_monitor = false` for WCN7850 in `drivers/net/wireless/ath/ath12k/hw.c`. Upstream Linux added full monitor mode support in April 2025.

### Overview of Required Changes

Enabling monitor mode requires two things:
1. Flip the `supports_monitor` flag in hw_params
2. Backport the 13-patch implementation series that adds the actual monitor mode data path

> **Warning:** Flipping the flag alone (without the patches) will result in a crash or silent failure when attempting to enter monitor mode. Both steps are required.

### Step A: Flip the hw_params flag

Edit `drivers/net/wireless/ath/ath12k/hw.c`, find the WCN7850 hw_params:

```diff
 		.interface_modes = BIT(NL80211_IFTYPE_STATION) |
 				   BIT(NL80211_IFTYPE_AP),
-		.supports_monitor = false,
+		.supports_monitor = true,
```

### Step B: Backport the 13-patch monitor mode series

**Patch source:** [\[PATCH ath-next 00/13\] wifi: ath12k: add monitor mode support for WCN7850](http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html)

The series includes:

| # | Patch | Purpose |
|---|-------|---------|
| 01 | configure mon ring | Ring configuration for monitor status |
| 02 | mon ring interrupt | Interrupt setup for monitor rings |
| 03 | reap mon dest ring | Process monitor destination ring |
| 04 | reap mon status ring | Process monitor status ring |
| 05 | mon mode handler | Main monitor mode handler |
| 06 | init mon params | Initialize monitor parameters |
| 07 | mon ring offsets WCN7850 | Ring offsets specific to WCN7850 |
| 08 | pkt offset WCN7850 | Packet offset handling |
| 09 | dp_mon WCN7850 init | Data path monitor init |
| 10 | radiotap construction | Build radiotap headers from HW TLVs |
| 11 | NL80211 monitor iface | Register monitor interface type |
| 12 | supports_monitor = true | Flip the flag (already done in Step A) |
| 13 | cleanup / test | Test and validation |

### Downloading Patches from the Mailing List

```bash
cd kernel
mkdir -p patches/monitor-mode

# Download each patch from the mailing list archive
# The patches are linked from the cover letter at:
# http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html
#
# Each follow-up message (01/13 through 13/13) contains a patch.
# Save them as:
#   patches/monitor-mode/0001-configure-mon-ring.patch
#   patches/monitor-mode/0002-mon-ring-interrupt.patch
#   ...
#   patches/monitor-mode/0013-cleanup-test.patch
```

> **Tip:** You can use the `b4` tool to download the entire series:
> ```bash
> pip install b4
> b4 am http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html -o patches/monitor-mode/
> ```

### Applying Patches

```bash
cd kernel

# Apply all patches in order
for p in patches/monitor-mode/00*.patch; do
  echo "Applying: $p"
  git am "$p"
  if [ $? -ne 0 ]; then
    echo "CONFLICT in $p — resolve manually"
    echo "After resolving: git am --continue"
    echo "To skip this patch: git am --skip"
    echo "To abort all: git am --abort"
    break
  fi
done
```

### Resolving Patch Conflicts

Conflicts are likely because the NothingOSS kernel has Qualcomm vendor patches on top of the upstream ath12k code. Common conflict areas:

| File | Typical Conflict | Resolution |
|------|-----------------|------------|
| `dp_mon.c` | Function signature changes | Keep Qualcomm version, add new monitor functions |
| `hw.c` | hw_params struct layout | Merge both Qualcomm additions and monitor fields |
| `hal.c` | Ring descriptor definitions | Add new monitor ring definitions alongside existing ones |
| `core.h` | Struct member additions | Add monitor-related members to the struct |
| `dp.h` | Data path struct changes | Merge both Qualcomm and monitor additions |

General conflict resolution strategy:

```bash
# When a conflict occurs:
git status                          # See which files conflict
vim <conflicted-file>               # Open in editor

# Look for conflict markers:
# <<<<<<< HEAD        (NothingOSS/Qualcomm version)
# =======
# >>>>>>> patch        (upstream patch version)

# Usually: keep the Qualcomm-specific code AND add the new monitor code
# The upstream patches add new functions — they should coexist with vendor code

git add <resolved-file>
git am --continue
```

### Understanding the Patch Series

For those who want to understand what each patch does:

**Patches 01–04 (Ring Setup):** Configure hardware descriptor rings that the WiFi chip uses to deliver captured packets. WCN7850 has dedicated monitor mode rings that need initialization.

**Patches 05–06 (Handler/Params):** Set up the software handler that processes packets from the monitor rings and initializes parameters like channel, bandwidth, etc.

**Patches 07–09 (WCN7850-specific):** Ring offsets and data path initialization specific to WCN7850 hardware. These values come from the chip's datasheet.

**Patch 10 (Radiotap):** Converts hardware-specific TLV (Type-Length-Value) metadata from captured frames into standard radiotap headers that tools like Wireshark/tcpdump understand.

**Patches 11–13 (Interface/Flag/Cleanup):** Register the monitor interface type with nl80211 (the Linux WiFi configuration API), flip the `supports_monitor` flag, and clean up.

### Firmware Compatibility

The patches were validated against firmware `WLAN.HMT.1.0.c5-00481-QCAHMTSWPL_V1.0_V2.0_SILICONZ-3`. Check your device's firmware:

```bash
adb shell ls /vendor/firmware/ath12k/WCN7850/hw2.0/
```

If the firmware version differs significantly, monitor mode may not work or may require a firmware update. The firmware files are:

| File | Purpose |
|------|---------|
| `amss.bin` | Main WiFi firmware |
| `m3.bin` | M3 firmware |
| `board-2.bin` | Board data file |
| `regdb.bin` | Regulatory database |

> **Note:** Firmware updates for WCN7850 typically come through Nothing OS OTA updates. If you need a newer firmware, you may need to extract it from a newer Nothing OS build via [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware).

## 4. Build Kernel

### Using Kleaf/Bazel (recommended)

```bash
cd kernel

# Build for sun (SM8735) platform, perf variant
python3 build_with_bazel.py -t sun perf
```

The output lands in `out/msm-kernel-sun-perf/dist/`. Look for `init_boot.img` or `boot.img`.

### Using legacy make (fallback)

If Bazel doesn't work:

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r510928/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# Assemble defconfig
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/sun_perf.config \
  arch/arm64/configs/vendor/Metroid.config

# Enable NetHunter configs
./scripts/enable-nethunter-configs.sh . out

# Build
make O=out -j$(nproc)
```

### Generating init_boot.img from legacy make

If you built with `make` instead of Bazel, the build system may not produce `init_boot.img` automatically. You need `mkbootimg`:

```bash
# Install mkbootimg (from Android platform tools or build tools)
pip install mkbootimg
# or clone: git clone https://android.googlesource.com/platform/system/tools/mkbootimg

# Create init_boot.img
mkbootimg \
  --header_version 4 \
  --kernel out/arch/arm64/boot/Image.lz4 \
  --output out/init_boot.img

# Alternatively, use the stock init_boot as a template:
# Extract stock init_boot, replace kernel, repack
unpack_bootimg --boot_img stock_init_boot.img --out stock_parts/
mkbootimg \
  --header_version 4 \
  --kernel out/arch/arm64/boot/Image.lz4 \
  --ramdisk stock_parts/ramdisk \
  --output out/init_boot.img
```

> **Note:** GKI init_boot format varies by device. If in doubt, use `unpack_bootimg` on the stock image to check the exact format, then repack with your custom kernel.

### Qualcomm-Specific Build Notes

| Topic | Detail |
|-------|--------|
| Build time | ~30 min on 8-core, ~15 min on 16-core |
| `vendor_boot.img` | May be produced alongside `init_boot.img` — usually not needed for kernel-only changes |
| Device tree | Qualcomm DTS files are in `arch/arm64/boot/dts/qcom/` |
| `dtbo.img` | Device tree overlay image — flash only if you modified device tree overlays |

## 5. Flash

```bash
# Backup first (do this ONCE)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# Reboot to bootloader
adb reboot bootloader

# GKI devices may use boot or init_boot — check device partition layout
fastboot flash init_boot out/dist/init_boot.img
# or: fastboot flash boot out/dist/boot.img

fastboot reboot
```

### How to Determine boot vs init_boot

```bash
adb shell su -c "ls /dev/block/by-name/ | grep -E 'boot|init_boot'"
# If init_boot_a exists → use init_boot
# If only boot_a exists → use boot
```

## 6. Verify Monitor Mode

```bash
adb shell su -c "ip link set wlan0 down"
adb shell su -c "iw dev wlan0 set type monitor"
adb shell su -c "ip link set wlan0 up"
adb shell su -c "iw dev wlan0 info"
# Should show: type monitor
```

If the `iw dev wlan0 set type monitor` command fails:

```bash
# Check kernel log for errors
adb shell su -c "dmesg | grep -i ath12k | tail -30"

# Check if monitor mode is listed in supported interface modes
adb shell su -c "iw phy phy0 info | grep -A 10 'Supported interface modes'"
# "monitor" should be in the list

# Check rfkill
adb shell su -c "rfkill list"
```

### Capture Test

```bash
# Quick packet capture
adb shell su -c "tcpdump -i wlan0 -c 50 -w /sdcard/test_capture.pcap"
adb pull /sdcard/test_capture.pcap

# Open in Wireshark on your PC to verify 802.11 frames are captured

# Or use airodump-ng for AP discovery
adb shell
su
nethunter
airodump-ng wlan0
```

## 7. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 8. External WiFi Adapter (Optional)

Even with internal WiFi monitor mode, packet injection may be limited by firmware. WCN7850 monitor mode captures frames (RX) reliably, but frame injection (TX in monitor mode) depends on firmware support that may be incomplete.

For reliable injection, cross-compile rtl8812au:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

See [External WiFi Adapters](external-wifi.md) for recommended adapters and usage.
