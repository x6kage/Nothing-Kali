# Troubleshooting

Common problems and solutions for Nothing-Kali kernel builds, flashing, and NetHunter usage.

## Build Issues

### Toolchain / Compiler

| Symptom | Cause | Solution |
|---------|-------|----------|
| `clang: not found` | Clang not in PATH | `export PATH=.../clang-rXXX/bin:$PATH` |
| `incompatible pointer type` | Wrong clang version | Use exact version from `build.config.constants` |
| `CONFIG_LTO_CLANG: unmet dependency` | LTO not configured | Enable `CONFIG_LTO=y` and `CONFIG_LTO_CLANG_THIN=y` |
| `BTF: .tmp_vmlinux.btf: pahole not found` | Missing dwarves | `sudo apt install dwarves` |
| `openssl/bio.h: No such file` | Missing OpenSSL dev headers | `sudo apt install libssl-dev` |
| `elf.h: No such file` | Missing libelf headers | `sudo apt install libelf-dev` |
| `bison: command not found` | Missing build deps | `sudo apt install bison flex` |

### Defconfig / Configuration

| Symptom | Cause | Solution |
|---------|-------|----------|
| `No rule to make target '...defconfig'` | Wrong defconfig name | `ls arch/arm64/configs/` to find available configs |
| Config option not set after `make defconfig` | Dependency not met | Check `make menuconfig` for the option's dependencies |
| `.config` is empty after defconfig | Wrong output directory | Ensure `O=out` matches your working directory |
| `CONFIG_USB_CONFIGFS_F_HID` not available | Missing USB gadget dependency | Enable `CONFIG_USB_GADGET=y` first |

### Build System

| Symptom | Cause | Solution |
|---------|-------|----------|
| `WORKSPACE not found` (Bazel) | Wrong working directory | Run from kernel root where WORKSPACE file exists |
| `bazel: command not found` | Bazel not installed | Install from https://bazel.build/install/ubuntu |
| `repo: command not found` | Repo tool missing | `sudo apt install repo` or `pip install repo` |
| Python version errors | Wrong Python version | Ensure Python 3.8+ is available |
| Out of disk space during build | Insufficient disk | Need 100-150 GB free; clean old builds: `rm -rf out/` |
| Out of memory (OOM killed) | Insufficient RAM | Reduce parallel jobs: `make -j4` instead of `-j$(nproc)` |

### KMI / Module Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| `KMI symbol ... not exported` | KMI violation | Set `CONFIG_TRIM_UNUSED_KSYMS=n` |
| `depmod: FATAL: Module not found` | Module path wrong | Use `make INSTALL_MOD_PATH=... modules_install` |
| `version magic mismatch` | Module/kernel mismatch | Rebuild module against the same kernel |
| Vendor modules fail to load | KMI breakage from wrong compiler | Use exact AOSP clang version |

## Flash Issues

### Fastboot

| Symptom | Cause | Solution |
|---------|-------|----------|
| `fastboot: command not found` | Platform tools not installed | Install Android SDK platform-tools |
| `< waiting for any device >` | Device not in fastboot mode | Hold Power + Vol Down for 10s |
| `FAILED (remote: not allowed)` | Bootloader locked | Unlock bootloader first ([Nothing Archive guide](https://spike0en.github.io/nothing_archive/docs/guides#unlocking-bootloader)) |
| `FAILED (remote: flash is not allowed for init_boot)` | Fastboot flashing locked | `fastboot flashing unlock` in bootloader |
| `sparse_file_read_normal: sparse file not found` | Wrong image format | Check that you're flashing the correct .img file |
| Flash succeeds but device won't boot | Bad kernel build | Flash stock image to recover (see below) |

### A/B Partitions

Nothing phones use A/B partition scheme. This affects how you flash:

```bash
# Check current active slot
fastboot getvar current-slot

# Flash to specific slot
fastboot flash init_boot_a init_boot.img
fastboot flash init_boot_b init_boot.img

# Or flash to both slots
fastboot flash init_boot init_boot.img  # flashes to active slot
fastboot --set-active=other
fastboot flash init_boot init_boot.img  # flashes to other slot
```

## Recovery Procedures

### Boot Loop (Stuck on Nothing Logo)

1. **Enter fastboot:** Hold Power + Volume Down for 10-15 seconds
2. **Connect USB** to your PC
3. **Verify fastboot connection:**
   ```bash
   fastboot devices
   ```
4. **Flash stock init_boot:**
   ```bash
   # Using your backup
   fastboot flash init_boot stock_init_boot_a.img
   fastboot reboot
   ```
5. If you don't have a backup, download from [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware)

### Black Screen After Flash

1. **Force reboot:** Hold Power for 15 seconds
2. If it reboots to Nothing logo and loops → follow boot loop procedure above
3. If it reboots normally → the kernel is working but something else may be wrong

### Cannot Enter Fastboot

1. **Long press:** Power + Volume Down for 30 seconds (not 10)
2. If still nothing, wait for battery to fully drain (may take hours)
3. Charge for a few minutes, then try Power + Volume Down again
4. If the device charges (LED indicator), fastboot should be accessible

### WiFi Stopped Working After Flash

The custom kernel may have a WLAN module mismatch:

```bash
# Check if WLAN module loaded
adb shell su -c "lsmod | grep wlan"

# Check kernel log for WLAN errors
adb shell su -c "dmesg | grep -i -E 'wlan|ath11k|ath12k|gen4m'"

# If module version mismatch, restore stock module
adb shell su -c "mount -o rw,remount /vendor"
adb push stock_wlan_module.ko /sdcard/
adb shell su -c "cp /sdcard/stock_wlan_module.ko /vendor/lib/modules/<module_name>.ko"
adb shell su -c "mount -o ro,remount /vendor"
adb reboot
```

### Complete Stock Restore

To fully restore to stock (undo all modifications):

1. Download the full stock firmware from [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware)
2. Flash all partitions:
   ```bash
   adb reboot bootloader
   fastboot flash init_boot stock_init_boot.img
   fastboot flash boot stock_boot.img       # if applicable
   fastboot reboot
   ```
3. Unroot (if desired):
   - **Magisk:** Open Magisk Manager → Uninstall → Complete Uninstall
   - **KernelSU:** Flash stock kernel or use KernelSU Manager to uninstall
4. Re-lock bootloader (if desired — this wipes data):
   ```bash
   fastboot flashing lock
   ```

## NetHunter Issues

### "Your kernel does not support USB ConfigFS!"

The kernel wasn't built with ConfigFS options. Verify:

```bash
adb shell su -c "grep USB_CONFIGFS /proc/config.gz 2>/dev/null" | gunzip
# or
adb shell su -c "zcat /proc/config.gz | grep USB_CONFIGFS"
```

If the options aren't set, rebuild the kernel with all `CONFIG_USB_CONFIGFS_*` options enabled.

### NetHunter App Crashes / Blank Screen

```bash
# Clear app data
adb shell pm clear com.offsec.nethunter

# Check if root is working
adb shell su -c "id"
# Should show: uid=0(root)

# Re-flash NetHunter
adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/
# Flash via Magisk/KernelSU
```

### Kali Chroot Issues

| Symptom | Solution |
|---------|----------|
| Chroot won't start | Check storage space: `df -h /data` |
| Chroot download fails | Download manually and push via ADB |
| `apt update` fails in chroot | Check DNS: `echo "nameserver 8.8.8.8" > /etc/resolv.conf` |
| Permission denied in chroot | Ensure root access is granted to NetHunter app |
| chroot is corrupted | Delete and reinstall: `rm -rf /data/local/nhsystem/kali*` |

### Metasploit Issues

```bash
# Database won't start
nethunter
service postgresql start
msfdb reinit

# Slow startup
# Metasploit loads many modules — first start takes 2-5 minutes on phone hardware
# Use msfconsole -q for quiet (faster) start

# Out of memory
# Phone RAM is limited — close other apps before running Metasploit
```

## WiFi Monitor Mode Issues

### Monitor Mode Command Fails

```bash
# Error: "Operation not supported"
# Check if monitor mode is in supported types
adb shell su -c "iw phy phy0 info | grep -A 20 'Supported interface modes'"

# Error: "Device or resource busy"
# Another process is using the interface
adb shell su -c "iw dev"
# Kill interfering processes
adb shell su -c "airmon-ng check kill"

# Error: "Operation not permitted"
# SELinux blocking
adb shell su -c "getenforce"
# Temporarily set permissive:
adb shell su -c "setenforce 0"
```

### Monitor Mode Works But No Packets Captured

```bash
# Check channel — you may be on the wrong channel
adb shell su -c "iw dev wlan0 info"

# Try specific channel
adb shell su -c "iw dev wlan0 set channel 6"

# Check with tcpdump
adb shell su -c "tcpdump -i wlan0 -c 10"
# If no output, the driver/firmware isn't delivering packets

# For ath12k: check firmware log
adb shell su -c "dmesg | grep ath12k"
```

### Kernel Panic When Entering Monitor Mode

This usually means the monitor mode patches were not fully applied:

1. Verify all 13 patches were applied (for WCN7850 devices)
2. Check `dmesg` for the specific panic message
3. Common cause: patch 10 (radiotap construction) was skipped or had unresolved conflicts
4. Rebuild with all patches correctly applied

## Performance Tips

### Build Speed

```bash
# Use ccache to speed up rebuilds
sudo apt install ccache
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
ccache -M 50G

# Parallel build (use nproc or specific count)
make O=out -j$(nproc)

# If running out of RAM, reduce jobs
make O=out -j4
```

### NetHunter Performance on Phone

- Close unnecessary apps before running heavy tools
- Use minimal chroot instead of full if storage is limited
- For long-running tasks (password cracking), keep the phone plugged in and disable sleep
- Use a fan/cooler during intensive operations — phones can thermal throttle
- Connect via SSH from a PC for a better terminal experience:
  ```bash
  # In NetHunter chroot:
  service ssh start
  # From PC:
  ssh root@<phone-ip>
  ```

## Getting Help

If you encounter an issue not covered here:

1. **Check `dmesg`** — the kernel log almost always has the answer
   ```bash
   adb shell su -c "dmesg | tail -50"
   ```
2. **Search existing issues** on the [Nothing-Kali GitHub](https://github.com/x6kage/Nothing-Kali/issues)
3. **Open a new issue** with:
   - Device model and Nothing OS version
   - Kernel source branch and commit hash
   - Full error message or `dmesg` output
   - Steps to reproduce
