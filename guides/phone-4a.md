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
| **Monitor Mode** | ❌ Blocked — same as Phone (3a) |

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | `sm7635/b/mr_Frogger` |

## Overview

Same SoC and WiFi chip as Phone (3a). Internal WiFi monitor mode is **not possible**. The only difference is the kernel branch (`sm7635/b/mr_Frogger` instead of `sm7635/b/mr`).

Refer to the [Phone (3a) guide](phone-3a.md) for full details. Below are the Phone (4a)-specific differences only.

## Fetch Source

```bash
mkdir nothing-4a-kernel && cd nothing-4a-kernel

# Note: Frogger-specific branch
git clone -b sm7635/b/mr_Frogger --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635.git kernel
```

## Build & Flash

Same as [Phone (3a)](phone-3a.md#3-build-kernel). Check `arch/arm64/configs/` for the Frogger-specific defconfig — it may be named differently from the Asteroids config.

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r487747c/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

python3 build_with_bazel.py
```

```bash
adb reboot bootloader
fastboot flash init_boot out/dist/init_boot.img
fastboot reboot
```

## NetHunter Pro & WiFi

- Install: [NetHunter Pro Installation](nethunter-install.md)
- External WiFi: [same as Phone (3a)](phone-3a.md#6-external-wifi-adapter-required-for-wifi-attacks)
