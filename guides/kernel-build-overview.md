# Kernel Build Overview — What You're Actually Doing

> This guide explains the concepts behind building a custom NetHunter kernel. Read this before diving into device-specific guides.

## What NetHunter Pro Does

NetHunter Pro does **not replace Android**. It takes the stock Android kernel source, **adds** penetration testing features, and rebuilds it. Your phone stays a phone — it just gains extra capabilities.

### What Changes / What Stays the Same

| | Unchanged (Stock) | Added by NetHunter |
|---|---|---|
| **Calls/SMS** | ✅ Works normally | — |
| **WiFi (normal)** | ✅ Works normally | Monitor mode (manual switch) |
| **Bluetooth** | ✅ Works normally | — |
| **Camera** | ✅ Works normally | — |
| **Apps** | ✅ Works normally | NetHunter app + Kali chroot |
| **Fingerprint** | ✅ Works normally | — |
| **NFC** | ✅ Works normally | — |
| **USB Charging** | ✅ Works normally | USB HID (keyboard/mouse emulation) |
| **OTA Updates** | ❌ Will fail | — |
| **SafetyNet/Play Integrity** | ⚠️ May fail | — |

**OTA Updates** will fail after flashing a custom kernel. To update: restore the stock kernel via [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/guides#ota-sideloading), apply the OTA, then re-flash the custom kernel.

**SafetyNet/Play Integrity** may fail depending on your root method. Magisk with Zygisk + DenyList can hide root from most apps. KernelSU is harder to detect by default.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                  Android OS (Nothing OS)              │
│    (Apps, UI, Phone, Camera — all unchanged)          │
├─────────────────────────────────────────────────────┤
│    Kali chroot (/data/local/nhsystem/)               │  ← Added by NetHunter
│    (Metasploit, Nmap, aircrack-ng, Burp, etc.)       │
├─────────────────────────────────────────────────────┤
│               Android Kernel (Custom Build)           │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Stock functionality (unchanged)                  │ │
│  │ + CONFIG_USB_CONFIGFS_F_HID  (USB HID attacks)  │ │  ← Added
│  │ + CONFIG_SNIFFER_RADIOTAP    (Phone 2a WiFi)    │ │  ← Added (device-specific)
│  │ + ath12k monitor mode patches (Phone 3/4a Pro)  │ │  ← Added (device-specific)
│  │ + CONFIG_USB_CONFIGFS_RNDIS  (USB networking)   │ │  ← Added
│  └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│    Firmware (WiFi FW, modem, DSP — NOT modified)     │
├─────────────────────────────────────────────────────┤
│                     Hardware                          │
└─────────────────────────────────────────────────────┘
```

### How WiFi Mode Switching Works

When the kernel supports monitor mode, WiFi operates in two states:

- **Normal (managed mode):** WiFi connects to access points, browses the internet, runs apps — identical to stock behavior.
- **Monitor mode:** The interface is brought down, switched to monitor mode, and brought back up. In this state, the WiFi chip captures all 802.11 frames in range (including frames not destined for your device).
- **Switching back:** Set the interface back to managed mode and reconnect. No reboot needed.

```bash
# Switch to monitor mode
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# Verify
iw dev wlan0 info    # type should show "monitor"

# Switch back to managed mode
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up
```

> **Important:** While in monitor mode, normal WiFi connectivity is unavailable. Switch back to managed mode when you're done.

## Understanding GKI (Generic Kernel Image)

Modern Android devices (kernel 5.10+) use Google's **GKI architecture**, which separates the kernel into:

```
┌──────────────────────────┐
│     GKI Kernel Image     │  ← Generic, from Google/AOSP
│  (core kernel + drivers) │
├──────────────────────────┤
│   Vendor Kernel Modules  │  ← Device-specific (Qualcomm/MediaTek/Nothing)
│    (.ko files in /vendor │
│     /lib/modules/)       │
└──────────────────────────┘
```

### Why GKI Matters for NetHunter Builds

1. **KMI (Kernel Module Interface):** GKI enforces a stable interface between the kernel and vendor modules. If your kernel build changes KMI symbols, vendor modules (WiFi, camera, etc.) won't load.
2. **Compiler matters:** Using a different compiler version than the vendor used can silently break KMI. Always use the exact AOSP clang version specified in the kernel source.
3. **`init_boot` vs `boot`:** GKI devices typically put the kernel in `init_boot.img` rather than `boot.img`. Check your device's partition layout before flashing.

### How to Check if Your Build Breaks KMI

```bash
# After building, check for KMI violations
grep "KMI" out/build.log

# Compare symbols
nm -D out/vmlinux | grep "T " | sort > built_symbols.txt
# Compare with stock kernel symbols if available
```

## Why Kernel Builds Fail (And How to Fix Them)

### 1. Toolchain

**Problem:** Using the wrong compiler version causes build failures or produces a kernel that won't boot.

**Fix:** The `build.config.constants` file in each NothingOSS kernel repo specifies the exact AOSP clang version. Use that version and nothing else.

| Device | Clang Version | Android Branch |
|---------|---------------|---------------|
| Phone (2a) | `r450784e` | `android13-5.15` |
| Phone (3a/4a) | `r487747c` | `android14-6.1` |
| Phone (3/4a Pro) | `r510928` | `android15-6.6` |

Use the provided script to download:

```bash
./scripts/setup-clang.sh r510928   # Downloads to prebuilts/clang/host/linux-x86/
```

Or download manually:

```bash
mkdir -p prebuilts/clang/host/linux-x86
cd prebuilts/clang/host/linux-x86
wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r510928.tar.gz
mkdir clang-r510928 && tar xzf clang-r510928.tar.gz -C clang-r510928
```

> If the tarball URL doesn't work (AOSP restructures their prebuilt hosting periodically), use `repo init` with the Android kernel manifest:
>
> ```bash
> repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6
> repo sync -c --no-tags
> ```

#### Why AOSP Clang, Not NDK or GCC?

| Compiler | Purpose | Can Build Kernel? |
|----------|---------|:-:|
| **AOSP Clang** (prebuilt) | Kernel builds | ✅ Correct choice |
| **Android NDK Clang** | Userspace apps/libraries | ❌ Wrong sysroot, wrong flags |
| **System GCC** (`gcc`) | General Linux | ⚠️ May work but risks KMI breakage |
| **System Clang** (`apt install clang`) | General development | ⚠️ Wrong version, LTO incompatibility |

The NDK ships a clang configured for userspace (linked against Bionic libc, with an Android sysroot). Using it for kernel builds produces broken binaries. System GCC can technically compile the kernel, but GKI kernels are tested with specific AOSP clang versions — using anything else risks ABI/KMI mismatches that cause vendor modules to fail silently.

### 2. Finding the Defconfig

**Problem:** You don't know which defconfig file to use.

**Fix:** GKI kernels use `gki_defconfig` as a base, with **vendor config fragments** layered on top. The exact fragments vary per device:

| Device | Base | Platform Fragment | Device Fragment |
|--------|------|-------------------|-----------------|
| Phone (2a) | `gki_defconfig` | (MTK Kleaf handles this) | — |
| Phone (3) | `gki_defconfig` | `vendor/sun_perf.config` | `vendor/Metroid.config` |
| Phone (3a) | `gki_defconfig` | `vendor/pineapple_GKI.config` | `vendor/Asteroids.config` |
| Phone (4a) | `gki_defconfig` | `vendor/pineapple_GKI.config` | `vendor/Frogger.config` |
| Phone (4a) Pro | `gki_defconfig` | `vendor/sun_perf.config` | `vendor/FroggerPro.config` |

With Kleaf/Bazel (recommended), the build system assembles the defconfig automatically. For legacy `make`, merge manually:

```bash
# Example for Phone (3):
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/sun_perf.config \
  arch/arm64/configs/vendor/Metroid.config
```

If vendor fragments are missing from your source tree, extract the running config from the device:

```bash
adb shell su -c "cat /proc/config.gz" | gunzip > running_config
cp running_config arch/arm64/configs/extracted_defconfig
make O=out extracted_defconfig
```

> **Tip:** After extracting, diff against `gki_defconfig` to see what Nothing customized:
> ```bash
> diff <(sort gki_defconfig) <(sort extracted_defconfig) | head -50
> ```

### 3. Build System: Kleaf/Bazel vs build.sh

NothingOSS kernels use Kleaf (a Bazel-based build system from Google). It wraps the traditional `make` workflow with hermetic builds.

**If Bazel works (recommended):**

For **MediaTek (Phone 2a)**:
```bash
tools/bazel run //common:kernel_aarch64_dist
```

For **Qualcomm (Phone 3, 3a, 4a, 4a Pro)** — uses `build_with_bazel.py` with `-t TARGET VARIANT`:
```bash
# Phone (3) / Phone (4a) Pro — "sun" platform
python3 build_with_bazel.py -t sun perf

# Phone (3a) / Phone (4a) — "pineapple" platform
python3 build_with_bazel.py -t pineapple gki
```

**If Bazel fails (legacy fallback):**

```bash
export LLVM=1
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_PREBUILT_BIN=$(pwd)/../prebuilts/clang/host/linux-x86/clang-rXXXXXX/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# Load defconfig
make O=out <device_defconfig>

# Enable NetHunter configs
../scripts/enable-nethunter-configs.sh . out

# Build
make O=out -j$(nproc)
```

### 4. Common Build Errors

| Error | Cause | Fix |
|--------|------|------|
| `clang: not found` | PATH missing clang binary | `export PATH=...clang-rXXX/bin:$PATH` |
| `incompatible pointer type` | Clang version mismatch | Use the exact version from `build.config.constants` |
| `CONFIG_LTO_CLANG: unmet dependency` | LTO configuration incomplete | Set `CONFIG_LTO_CLANG_THIN=y` and `CONFIG_LTO=y` |
| `KMI symbol ... not exported` | KMI violation | Set `CONFIG_TRIM_UNUSED_KSYMS=n` |
| `depmod: FATAL: Module ... not found` | Module path mismatch | `make O=out INSTALL_MOD_PATH=... modules_install` |
| `No rule to make target 'xxx.dtb'` | Device tree source missing | Check `arch/arm64/boot/dts/` for vendor-specific subdirectory |
| `error: unused variable` (with `-Werror`) | Strict warning flags | Add `-Wno-unused-variable` or fix the code |
| `BTF: .tmp_vmlinux.btf: pahole not found` | Missing `pahole` tool | `sudo apt install dwarves` |
| `openssl/bio.h: No such file` | Missing OpenSSL headers | `sudo apt install libssl-dev` |
| `Cannot use CONFIG_CC_STACKPROTECTOR` | Compiler/config mismatch | Ensure AOSP clang matches kernel branch |
| Bazel `WORKSPACE not found` | Wrong working directory | Run Bazel from the kernel root directory |
| `repo: command not found` | Missing `repo` tool | `sudo apt install repo` or install from Google |

### 5. Build Output and What to Flash

```
out/
├── arch/arm64/boot/
│   ├── Image              # Raw kernel image
│   ├── Image.lz4          # LZ4-compressed kernel image
│   ├── Image.gz           # Gzip-compressed kernel image
│   └── dts/               # Device tree blobs
│       └── vendor/        # Vendor-specific device trees
├── init_boot.img          # ← Flash this (most GKI devices)
├── boot.img               # ← Some devices use this instead
├── vendor_boot.img        # ← Vendor boot (may need for modules)
└── *.ko                   # Kernel modules
```

**What to flash:**

| Device | Target Partition | Command |
|---------|-----------------|---------|
| Phone (2a) | `init_boot` | `fastboot flash init_boot init_boot.img` |
| Phone (3a/4a) | `init_boot` | `fastboot flash init_boot init_boot.img` |
| Phone (3) | `init_boot` or `boot` | Check device partition layout first |
| Phone (4a) Pro | `init_boot` or `boot` | Check device partition layout first |

To check which partition holds the kernel on your device:

```bash
adb shell su -c "ls -la /dev/block/by-name/ | grep -E 'boot|init_boot'"
```

### 6. Verifying the Build Before Flashing

Before flashing, verify your kernel was built correctly:

```bash
# Check that the image exists
ls -la out/arch/arm64/boot/Image*

# Verify it's an ARM64 kernel
file out/arch/arm64/boot/Image
# Expected: "Linux kernel ARM64 boot executable Image"

# Check config was applied
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config
# Expected: CONFIG_USB_CONFIGFS_F_HID=y

# Use the verification script
../scripts/verify-kernel.sh out
```

### 7. Recovery — You Can Always Go Back

If the custom kernel fails to boot:

1. **Fastboot is always accessible** — hold Power + Volume Down to enter bootloader mode
2. Download the stock boot image from [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware)
3. Flash: `fastboot flash init_boot stock_init_boot.img`
4. Reboot — back to normal

**The risk of a permanent brick is extremely low** because:

- You only replace the kernel image — no partition table or baseband changes
- Fastboot mode is independent of the kernel — it lives in a separate partition
- Nothing phones have A/B partition schemes — if slot A fails, the bootloader may fall back to slot B

### Recovery Scenarios

| Scenario | Solution |
|----------|----------|
| Boot loop (stuck on Nothing logo) | Fastboot → flash stock init_boot |
| Black screen after flash | Hold power 15s to force reboot → fastboot |
| WiFi doesn't work after flash | Vendor WiFi module mismatch — reflash stock or rebuild modules |
| System boots but crashes randomly | Kernel config issue — check `dmesg` via ADB, rebuild with fixes |
| Can't enter fastboot | Hold Power + Vol Down for 15s. If still stuck, wait for battery drain, then try again |

## Build Workflow Summary

```
┌─────────────────────────────────────────────────────┐
│ 1. Backup partitions (persist, nvram, boot/init_boot)│
├─────────────────────────────────────────────────────┤
│ 2. Clone kernel source + download AOSP clang         │
├─────────────────────────────────────────────────────┤
│ 3. Configure (defconfig + NetHunter configs)         │
│    - USB ConfigFS options                            │
│    - Monitor mode patches (device-specific)          │
├─────────────────────────────────────────────────────┤
│ 4. Build (Kleaf/Bazel or make)                       │
├─────────────────────────────────────────────────────┤
│ 5. Verify (check Image, .config, modules)            │
├─────────────────────────────────────────────────────┤
│ 6. Flash via fastboot                                │
├─────────────────────────────────────────────────────┤
│ 7. Install NetHunter Pro                             │
├─────────────────────────────────────────────────────┤
│ 8. Verify (USB HID, WiFi mode, Kali chroot)         │
└─────────────────────────────────────────────────────┘
```

## Next Steps

- **[Device-specific guide](../README.md#kernel-build-per-device)** — follow the build steps for your phone
- **[NetHunter Pro Installation](nethunter-install.md)** — install after flashing the custom kernel
- **[Troubleshooting](troubleshooting.md)** — if something goes wrong during or after the build
