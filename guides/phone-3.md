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

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735) | `sm8735/b/mr` |

## 1. Build Environment

### Host Requirements

- Ubuntu 22.04+ (x86_64)
- 150GB+ disk space (Qualcomm kernel trees are larger)
- 16GB+ RAM

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod

# Bazel (for Kleaf)
sudo apt install -y bazel
```

### Fetch Source

```bash
mkdir nothing-3-kernel && cd nothing-3-kernel

git clone -b sm8735/b/mr --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735.git kernel

# AOSP Clang r510928
mkdir -p prebuilts/clang/host/linux-x86
# Download r510928 from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/
# or from Android CI build artifacts
```

### Why AOSP Clang?

The kernel config specifies `LLVM=1` and `CLANG_VERSION=r510928`. This is **not** the same as Android NDK clang:

- **NDK clang** targets Android userspace (linked against Bionic libc, Android sysroot). Compiling a kernel with NDK clang will fail or produce subtly broken binaries.
- **AOSP prebuilt clang** is a bare-metal compiler configured for kernel builds, matching what Nothing/Qualcomm used to build and test the stock kernel.
- GKI (Generic Kernel Image) kernels enforce KMI symbol checking — using a different compiler can break KMI compatibility, preventing vendor modules from loading.

## 2. Kernel Configuration — USB ConfigFS

Add to defconfig:

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

## 3. Enable WCN7850 Monitor Mode

The stock NothingOSS kernel has `supports_monitor = false` for WCN7850 in `drivers/net/wireless/ath/ath12k/hw.c`. Upstream Linux added full monitor mode support in April 2025.

### Step A: Flip the hw_params flag

Edit `drivers/net/wireless/ath/ath12k/hw.c`, find the WCN7850 hw_params:

```diff
 		.interface_modes = BIT(NL80211_IFTYPE_STATION) |
 				   BIT(NL80211_IFTYPE_AP),
-		.supports_monitor = false,
+		.supports_monitor = true,
```

### Step B: Backport the 13-patch monitor mode series

Without backporting the implementation, flipping the flag alone will crash or silently fail.

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

Download each patch from the mailing list archive and apply:

```bash
cd kernel

# Save patches to patches/ directory, then:
for p in patches/00*.patch; do
  git am "$p" || git am --abort
done
```

If conflicts occur (likely due to NothingOSS/Qualcomm vendor changes), resolve manually. Most conflicts will be in `dp_mon.c`, `hw.c`, or `hal.c`.

### Firmware compatibility

The patches were validated against firmware `WLAN.HMT.1.0.c5-00481-QCAHMTSWPL_V1.0_V2.0_SILICONZ-3`. Check your device's firmware:

```bash
adb shell ls /vendor/firmware/ath12k/WCN7850/hw2.0/
```

If the firmware version differs significantly, monitor mode may not work or may require a firmware update.

## 4. Build Kernel

### Using Kleaf/Bazel

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel

# Qualcomm kernels may use build_with_bazel.py
python3 build_with_bazel.py
```

### Using build.sh (legacy)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r510928/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

build/build.sh
```

## 5. Flash

```bash
adb reboot bootloader

# GKI devices may use boot or init_boot — check device partition layout
fastboot flash init_boot out/dist/init_boot.img
# or: fastboot flash boot out/dist/boot.img

fastboot reboot
```

## 6. Verify Monitor Mode

```bash
adb shell su -c "ip link set wlan0 down"
adb shell su -c "iw dev wlan0 set type monitor"
adb shell su -c "ip link set wlan0 up"
adb shell su -c "iw dev wlan0 info"
# Should show: type monitor
```

## 7. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 8. External WiFi Adapter (Optional)

Even with internal WiFi monitor mode, packet injection may be limited by firmware. For reliable injection, cross-compile rtl8812au:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```
