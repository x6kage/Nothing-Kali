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

> **Shares WiFi hardware with Phone (3).** Both use the WCN7850 chip and ath12k driver on kernel 6.6. The upstream monitor mode patches apply to both devices with identical or very similar results.

## Sources

| Repo | Branch |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750) | `sm7750/b/FroggerPro` |

## WiFi Monitor Mode

The Phone (4a) Pro uses the **same WCN7850 WiFi chip and ath12k driver** as the Phone (3). The upstream ath12k monitor mode patch series (13 patches, April 2025) applies to both devices.

For the full patching procedure, conflict resolution guide, and firmware compatibility details, see **[Phone (3) — Enable WCN7850 Monitor Mode](phone-3.md#3-enable-wcn7850-monitor-mode)**.

### Quick Summary

1. Flip `supports_monitor = true` in `drivers/net/wireless/ath/ath12k/hw.c`
2. Backport the [13-patch WCN7850 monitor mode series](http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html)
3. Both steps are required — flag flip alone will crash

Since Phone (3) and Phone (4a) Pro both use kernel 6.6 with the same AOSP clang version (`r510928`), patches should apply with identical or very similar conflicts.

### Potential Differences from Phone (3)

While the WiFi hardware and driver are identical, the SM7750 SoC may have slightly different:

- Device tree configurations (different SoC → different platform DTS)
- Vendor kernel patches (Qualcomm may ship different vendor patches per SoC)
- ath12k firmware version (check your firmware — see below)

```bash
# Check firmware version on your Phone (4a) Pro
adb shell ls /vendor/firmware/ath12k/WCN7850/hw2.0/
adb shell su -c "dmesg | grep ath12k | grep firmware"
```

## 1. Build Environment

### Host Requirements

- Ubuntu 22.04+ (x86_64)
- 150GB+ disk space
- 16GB+ RAM (32GB recommended)

### Dependencies

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves bazel
```

### Fetch Source

```bash
mkdir nothing-4a-pro-kernel && cd nothing-4a-pro-kernel

git clone -b sm7750/b/FroggerPro --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750.git kernel

# AOSP Clang r510928 (same as Phone 3)
# If you cloned the Nothing-Kali repo, use:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r510928
# Or manually:
mkdir -p prebuilts/clang/host/linux-x86
# Download from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/
```

## 2. Kernel Configuration

### Defconfig

Phone (4a) Pro uses the Qualcomm `sun` platform (same as Phone 3). The defconfig is assembled from:

```
gki_defconfig                          # GKI base
  + vendor/sun_perf.config             # Qualcomm sun platform config
  + vendor/FroggerPro.config           # Nothing Phone (4a) Pro device config
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

After loading defconfig:

```bash
./scripts/enable-nethunter-configs.sh . out
```

### Monitor Mode Patches

Follow the identical procedure from [Phone (3) — Enable WCN7850 Monitor Mode](phone-3.md#3-enable-wcn7850-monitor-mode):

1. **Flip the flag:** Edit `drivers/net/wireless/ath/ath12k/hw.c`, set `supports_monitor = true` for WCN7850
2. **Download patches:** Get the 13-patch series from the ath12k mailing list
3. **Apply patches:** `git am` each patch in order
4. **Resolve conflicts:** Same conflict areas as Phone (3) — `dp_mon.c`, `hw.c`, `hal.c`

> **Tip:** If you already applied the patches to a Phone (3) kernel tree, you can generate a combined patch and apply it here:
> ```bash
> # On the Phone (3) tree after patches are applied:
> git format-patch HEAD~14..HEAD -o ../shared-patches/
> # On the Phone (4a) Pro tree:
> for p in ../shared-patches/*.patch; do git am "$p"; done
> ```

## 3. Build Kernel

### Using Kleaf/Bazel (recommended)

```bash
cd kernel

# Build for sun (SM7750) platform, perf variant
python3 build_with_bazel.py -t sun perf
```

Output lands in `out/msm-kernel-sun-perf/dist/`.

### Using legacy make (fallback)

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
  arch/arm64/configs/vendor/FroggerPro.config

# Enable NetHunter configs
./scripts/enable-nethunter-configs.sh . out

# Build
make O=out -j$(nproc)
```

### Verify the Build

```bash
# Check output
ls -la out/dist/init_boot.img 2>/dev/null || ls -la out/arch/arm64/boot/Image*

# Verify USB ConfigFS
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config

# Verify monitor mode flag
grep "supports_monitor" out/.config 2>/dev/null
# Or check the compiled source:
grep -r "supports_monitor" drivers/net/wireless/ath/ath12k/hw.c

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

## 5. Verify Monitor Mode

```bash
adb shell su -c "ip link set wlan0 down"
adb shell su -c "iw dev wlan0 set type monitor"
adb shell su -c "ip link set wlan0 up"
adb shell su -c "iw dev wlan0 info"
# Expected: type monitor
```

### If Monitor Mode Fails

```bash
# Check supported interface modes
adb shell su -c "iw phy phy0 info | grep -A 10 'Supported interface modes'"

# Check kernel log
adb shell su -c "dmesg | grep -i ath12k | tail -30"

# Check firmware
adb shell su -c "ls /vendor/firmware/ath12k/WCN7850/hw2.0/"
```

See [Phone (3) troubleshooting](phone-3.md#6-verify-monitor-mode) and [Troubleshooting](troubleshooting.md) for more details.

## 6. Install NetHunter Pro

See [NetHunter Pro Installation](nethunter-install.md).

## 7. External WiFi (Optional)

Even with internal monitor mode working, an external adapter provides reliable packet injection:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

See [External WiFi Adapters](external-wifi.md) for recommended adapters and usage.

## Differences from Phone (3)

| Aspect | Phone (3) | Phone (4a) Pro |
|--------|----------|---------------|
| Codename | Metroid | FroggerPro |
| SoC | SM8735 (Snapdragon 8s Gen 4) | SM7750 (Snapdragon 7 Gen 4) |
| Kernel repo | `android_kernel_msm-6.6_nothing_sm8735` | `android_kernel_msm-6.6_nothing_sm7750` |
| Branch | `sm8735/b/mr` | `sm7750/b/FroggerPro` |
| WiFi chip | WCN7850 (identical) | WCN7850 (identical) |
| WiFi driver | ath12k (identical) | ath12k (identical) |
| Kernel version | 6.6 (identical) | 6.6 (identical) |
| Clang version | `r510928` (identical) | `r510928` (identical) |
| Monitor mode patches | Applies ✅ | Same patches apply ✅ |
