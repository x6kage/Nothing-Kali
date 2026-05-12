# Phone (4a) Pro — NetHunter Pro Kernel Build

| | |
|---|---|
| **Codename** | FroggerPro |
| **SoC** | Qualcomm Snapdragon 7 Gen 4 (SM7750) |
| **Arch** | arm64 |
| **WiFi Chip** | WCN7850 (FastConnect 7800, Wi-Fi 7) |
| **WiFi Driver** | ath12k |
| **Kernel** | Linux 6.6 (`android15-6.6`) |
| **Toolchain** | AOSP Clang `r510928` with `LLVM=1` |
| **Build System** | Kleaf / Bazel |
| **Monitor Mode** | 🔧 Patchable — same WCN7850 + ath12k as Phone (3) |

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750) | `sm7750/b/FroggerPro` |

## Overview

The Phone (4a) Pro uses the **same WCN7850 WiFi chip and ath12k driver** as the Phone (3). The kernel version (6.6) and AOSP clang version (`r510928`) are also identical. The upstream ath12k monitor mode patches apply to both devices.

Refer to the [Phone (3) guide](phone-3.md) for the full WCN7850 monitor mode patching procedure. Below are the Phone (4a) Pro-specific differences.

## Fetch Source

```bash
mkdir nothing-4a-pro-kernel && cd nothing-4a-pro-kernel

git clone -b sm7750/b/FroggerPro --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750.git kernel

# AOSP Clang r510928 (same as Phone 3)
mkdir -p prebuilts/clang/host/linux-x86
```

## USB ConfigFS + Monitor Mode

Identical to [Phone (3)](phone-3.md):

1. Enable all `CONFIG_USB_CONFIGFS_*` options
2. Flip `supports_monitor = true` in `drivers/net/wireless/ath/ath12k/hw.c`
3. Backport the [13-patch WCN7850 monitor mode series](http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html)

Since both Phone (3) and Phone (4a) Pro use kernel 6.6 with the same ath12k base, patches should apply with identical or very similar conflicts.

## Build

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r510928/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

python3 build_with_bazel.py
```

## Flash

```bash
adb reboot bootloader
fastboot flash init_boot out/dist/init_boot.img
fastboot reboot
```

## Verify Monitor Mode

```bash
adb shell su -c "ip link set wlan0 down"
adb shell su -c "iw dev wlan0 set type monitor"
adb shell su -c "ip link set wlan0 up"
adb shell su -c "iw dev wlan0 info"
# Expected: type monitor
```

## NetHunter Pro & External WiFi

- Install: [NetHunter Pro Installation](nethunter-install.md)
- External WiFi (optional, for reliable injection): [same as Phone (3)](phone-3.md#8-external-wifi-adapter-optional)
