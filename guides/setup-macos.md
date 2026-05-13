# macOS Environment Setup

A guide for building and flashing a custom kernel for NetHunter Pro onto a Nothing phone from macOS.

## Overview: What Requires Native macOS vs. a Linux VM

| Task | macOS Only | Linux VM / Docker |
|------|:---:|:---:|
| adb / fastboot (flashing) | ✅ | ✅ |
| Bootloader unlock | ✅ | ✅ |
| NetHunter Pro zip transfer | ✅ | ✅ |
| **Kernel build** | ❌ | ✅ |
| **Kernel module build** | ❌ | ✅ |
| **rtl8812au build** | ❌ | ✅ |

A Linux x86_64 environment is required for kernel builds (because AOSP clang ships as a Linux binary). macOS can be used for flashing via adb/fastboot and installing NetHunter.

> **Apple Silicon (M1/M2/M3/M4) note:** The kernel build cross-compiler targets x86_64 Linux. On Apple Silicon, an x86_64 Linux VM (UTM/OrbStack, etc.) or a cloud build environment is required.

## 1. Installing ADB / Fastboot

### Via Homebrew (Recommended)

```bash
# Install Homebrew if not already present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Android Platform Tools
brew install android-platform-tools

# Verify
adb version
fastboot --version
```

### Manual Installation

1. Download [Android SDK Platform Tools for macOS](https://developer.android.com/tools/releases/platform-tools)
2. Extract and place in a location of your choice (e.g., `~/Library/Android/platform-tools`)
3. Add to PATH:
   ```bash
   # Add to ~/.zshrc
   export PATH="$HOME/Library/Android/platform-tools:$PATH"
   ```
4. Apply with `source ~/.zshrc`

### Verifying the USB Connection

macOS does not require additional drivers for adb/fastboot to work:

```bash
# With the device connected and USB debugging enabled
adb devices
```

If it shows `unauthorized`, approve the USB debugging prompt on the phone.

> **USB-C to USB-C cable note:** Some USB-C cables do not support data transfer. If adb does not recognize the device, try a USB-A to USB-C cable instead.

## 2. Kernel Build Environment

### Method A: OrbStack (Recommended — Apple Silicon Compatible)

[OrbStack](https://orbstack.dev/) provides a lightweight Linux VM + Docker environment. It supports x86_64 emulation on Apple Silicon.

```bash
# After installing OrbStack
orb create ubuntu kernel-build --arch amd64

# Enter the VM
orb shell kernel-build

# Set up the build environment (inside the VM)
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves
```

> **Note:** `--arch amd64` is required. The AOSP clang prebuilts are x86_64 Linux binaries and will not run in an ARM64 Linux VM. On Apple Silicon, they run via Rosetta translation, but build speed will be reduced.

### Method B: UTM (Free)

Create an Ubuntu 22.04 x86_64 VM using [UTM](https://mac.getutm.app/):

1. Download and install UTM
2. Download the Ubuntu 22.04 Server (amd64) ISO
3. Create a new VM:
   - **Emulate** (Apple Silicon) or **Virtualize** (Intel Mac)
   - Memory: 8 GB or more
   - Disk: 150 GB or more
   - CPU: 4 cores or more
4. After installing Ubuntu, install the build dependency packages

### Method C: Docker (Build Only)

```bash
# After installing Docker Desktop for Mac
docker run -it --platform linux/amd64 \
  -v ~/nothing-kernel:/workspace \
  ubuntu:22.04 bash

# Inside the container
apt update && apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves
```

> **Docker limitation:** Bazel builds consume large amounts of memory and disk. Increase the Docker Desktop resource limits (Settings → Resources → Memory 8 GB+, Disk 150 GB+).

### Method D: Cloud Build

If the local machine lacks sufficient performance:

- **GitHub Codespaces** — Build in a Linux environment from a browser
- **GCP / AWS Temporary VM** — Build completes in 15–30 minutes on e2-standard-8 (8 vCPU, 32 GB RAM)
- **Gitpod** — Lighter builds are possible even on the free tier

## 3. Transferring Build Artifacts

Transfer `init_boot.img` from the VM/Docker to the macOS host:

### OrbStack

```bash
# Files inside the VM are directly accessible from macOS
# Finder: OrbStack → kernel-build → File Browser
# Or from the terminal:
orb push kernel-build:/home/ubuntu/kernel/out/dist/init_boot.img ~/Desktop/
```

### Docker

```bash
# If the output is in a -v mounted directory, it is already available
ls ~/nothing-kernel/out/dist/init_boot.img

# Or copy from the container
docker cp <container_id>:/workspace/kernel/out/dist/init_boot.img ~/Desktop/
```

### UTM

Configure a shared folder between the VM and host in UTM, or transfer via `scp`:

```bash
# From inside the VM
scp init_boot.img <mac-user>@<mac-ip>:~/Desktop/
```

## 4. Flashing Procedure (macOS)

```bash
# Enter bootloader
adb reboot bootloader

# Backup (first time only)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img ~/Desktop/backup/

# Flash the custom kernel
fastboot flash init_boot ~/Desktop/init_boot.img
fastboot reboot

# Transfer the NetHunter zip
adb push ~/Downloads/nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
```

## 5. Recovery (macOS)

```bash
# Hold Power + Volume Down to enter fastboot mode
fastboot flash init_boot ~/Desktop/backup/stock_init_boot_a.img
fastboot reboot
```

## Troubleshooting

| Problem | Solution |
|------|------|
| `adb devices` shows nothing | Try a different USB cable. Try connecting via a USB-A to USB-C adapter |
| `fastboot devices` shows nothing | Try `sudo fastboot devices`. Allow USB access in macOS security settings |
| OrbStack x86_64 VM is slow | x86_64 emulation on Apple Silicon runs at roughly 30–50% native speed. Bazel builds may take 1–2 hours |
| Out of memory in Docker | Docker Desktop → Settings → Resources → Increase memory to 12 GB+ |
| `brew install` fails | Run `brew update && brew upgrade` first |
| macOS Ventura+ reports "unidentified developer" for adb | System Settings → Privacy & Security → Click "Allow Anyway" |

## Intel Mac vs. Apple Silicon

| | Intel Mac | Apple Silicon (M1+) |
|---|---|---|
| adb/fastboot | ✅ Native | ✅ Runs via Rosetta |
| Linux VM (native x86_64) | ✅ Fast (VT-x) | ❌ Emulation (slow) |
| Linux VM (arm64) | ❌ | ✅ Fast, but AOSP clang is unsupported |
| Docker x86_64 | ✅ Fast | ⚠️ Runs via Rosetta translation (slow) |
| Cloud build | ✅ Recommended | ✅ **Most recommended** |

**Recommendation for Apple Silicon users:** Run adb/fastboot locally, and perform kernel builds in a cloud environment (e.g., GitHub Codespaces) or in an OrbStack x86_64 VM with sufficient memory allocated.
