# Windows Environment Setup

A guide for building and flashing a custom kernel for NetHunter Pro onto a Nothing phone from a Windows PC.

## Overview: What Requires Windows vs. Linux

| Task | Windows Only | WSL2 (Linux) |
|------|:---:|:---:|
| adb / fastboot (flashing) | ✅ | ✅ |
| Bootloader unlock | ✅ | ✅ |
| NetHunter Pro zip transfer | ✅ | ✅ |
| **Kernel build** | ❌ | ✅ |
| **Kernel module build** | ❌ | ✅ |
| **rtl8812au build** | ❌ | ✅ |

A Linux environment (WSL2 or cloud) is required for building kernels. Flashing alone can be done entirely from Windows.

## 1. Installing ADB / Fastboot

### Method A: Android SDK Platform Tools (Recommended)

1. Download the Windows version from [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools)
2. Extract to a folder of your choice (e.g., `C:\platform-tools`)
3. Add to the system PATH environment variable:
   - `Win + X` → `System` → `Advanced system settings` → `Environment Variables`
   - Edit `Path` → Add `C:\platform-tools`
4. Verify in Command Prompt or PowerShell:
   ```
   adb version
   fastboot --version
   ```

### Method B: winget (Windows 11)

```powershell
winget install Google.PlatformTools
```

### USB Drivers

USB drivers are required for Windows to recognize the Nothing phone via adb/fastboot:

1. Connect the device via USB
2. Enable `Settings → Developer Options → USB Debugging` on the phone
3. If the driver is not installed automatically:
   - Install the [Google USB Driver](https://developer.android.com/studio/run/win-usb)
   - Or use the [Universal ADB Driver](https://adb.clockworkmod.com/)
4. Verify:
   ```
   adb devices
   ```
   If the device appears, the setup is complete. If it shows `unauthorized`, approve the USB debugging prompt on the phone.

### Verifying Connection in Fastboot Mode

```
adb reboot bootloader
fastboot devices
```

If the device does not appear:
- Try a different USB cable (charging-only cables will not work)
- Try a different USB port (USB 2.0 ports are recommended)
- Check the driver in Device Manager

## 2. Choosing a Kernel Build Environment

A Linux x86_64 environment is required for kernel builds. Choose a method based on your PC's specifications:

| Method | Required Specs | Estimated Build Time | Recommended |
|------|-------------|---------------|:---:|
| **WSL2 (Local)** | RAM 16 GB+, Disk 150 GB+, 4+ cores | 15–60 min | ✅ High-spec PC |
| **Cloud (GitHub Codespaces)** | A working browser | 15–30 min | ✅ **Low-spec PC** |
| **Cloud (GCP/AWS Temporary VM)** | Browser + credit card | 10–20 min | Fastest |
| **Docker Desktop + WSL2** | RAM 16 GB+, Disk 150 GB+ | Same as WSL2 | For environment isolation |

### Low-Spec PCs

If your RAM is 8 GB or less, free disk space is under 100 GB, or your CPU has only 2 cores, local kernel builds **risk OOM kills or build times of several hours**. The following approach is recommended:

1. **Install only adb/fastboot locally** (Section 1 above)
2. **Run the kernel build in the cloud** (Section 2B)
3. **Download the build artifact (`init_boot.img`) and flash locally**

In this case, you can skip WSL2 setup (Section 2A).

### 2A. WSL2 Setup (Local Build)

> **Can be skipped:** This section is not needed if you are using cloud builds (2B).

A Linux environment is required for kernel builds. Use WSL2 (Windows Subsystem for Linux 2).

### Installing WSL2

In PowerShell (Administrator):

```powershell
wsl --install -d Ubuntu-22.04
```

After restarting, Ubuntu will launch and prompt you to create a user account.

### Ensuring Sufficient Disk Space

Kernel builds require 100–150 GB of free space. If the default WSL2 vhdx size is too small, expand it:

```powershell
# Stop WSL2
wsl --shutdown

# Locate the vhdx path (typically: %LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu22.04...\LocalState\ext4.vhdx)
# Expand with diskpart
diskpart
select vdisk file="C:\Users\<USER>\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04onWindows_79rhkp1fndgsc\LocalState\ext4.vhdx"
expand vdisk maximum=200000
exit

# Resize within WSL2
wsl
sudo resize2fs /dev/sdc 200G
```

### Setting Up the Build Environment

Inside WSL2 Ubuntu:

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves
```

From here, follow the kernel build instructions in the respective device guide. Work within WSL2 paths.

### Using adb/fastboot from WSL2

To access USB devices directly from WSL2, `usbipd-win` is required:

```powershell
# Windows side (PowerShell Administrator)
winget install usbipd
```

```bash
# WSL2 side
sudo apt install linux-tools-generic hwdata
sudo update-alternatives --install /usr/local/bin/usbip usbip /usr/lib/linux-tools/*-generic/usbip 20
```

```powershell
# After connecting the device, in PowerShell:
usbipd list                    # Check BUSID
usbipd bind --busid <BUSID>    # Bind
usbipd attach --wsl --busid <BUSID>   # Attach to WSL
```

`adb devices` will now work inside WSL2.

> **Simpler approach:** Perform only the kernel build in WSL2, and run adb/fastboot from the Windows Command Prompt. Build artifacts can be accessed from Windows via `/mnt/c/Users/<USER>/...`.

```bash
# After building in WSL2, copy to a Windows-accessible location
cp out/dist/init_boot.img /mnt/c/Users/<USER>/Desktop/
```

On the Windows side:
```
cd C:\Users\<USER>\Desktop
fastboot flash init_boot init_boot.img
```

### 2B. Cloud Build (Low-Spec PC / No Local Linux Environment Desired)

A browser is all that is needed to build the kernel. Download the build artifacts and flash using local adb/fastboot.

#### GitHub Codespaces (Recommended)

Available with a free-tier GitHub account (120 core-hours per month):

1. Go to [github.com/codespaces](https://github.com/codespaces)
2. **New codespace** → **Blank template** → Select machine type **4-core** or higher
3. Once the terminal opens, set up the build environment:

```bash
sudo apt update
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves

# Then follow the device guide to clone and build the kernel
# Example: Phone (2a)
git clone -b mt6886/Pacman/v --depth=1 \
  https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886.git kernel
```

4. After the build completes, download the artifact:
   - Right-click `init_boot.img` in the Codespace file explorer → **Download**
   - Or from a local terminal: `gh codespace cp remote:kernel/out/dist/init_boot.img .`

#### Google Cloud Shell

Available for free with a Google account (e2-small, temporary):

1. Go to [shell.cloud.google.com](https://shell.cloud.google.com/)
2. Set up the build environment in the terminal → Build
3. Download locally with `cloudshell download init_boot.img`

> **Note:** Cloud Shell has only 5 GB of persistent storage plus temporary storage. Place large kernel trees in the temporary area. Data is lost when the session ends.

#### GCP / AWS Temporary VM (Fastest)

If budget allows:

```bash
# GCP: e2-standard-8 (8 vCPU, 32GB RAM) — ~15 min build time
gcloud compute instances create kernel-build \
  --machine-type=e2-standard-8 \
  --boot-disk-size=200GB \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud

# AWS: c5.2xlarge (8 vCPU, 16GB RAM)
aws ec2 run-instances \
  --instance-type c5.2xlarge \
  --image-id ami-0xxx  # Ubuntu 22.04 AMI
```

After the build, download via `scp` and delete the VM — the cost will be minimal.

#### Cloud Build Workflow

```
┌──────────────────────────┐     ┌──────────────────────────┐
│     Cloud Environment     │     │     Local Windows        │
│                          │     │                          │
│  1. Fetch kernel source  │     │                          │
│  2. Configure defconfig  │     │                          │
│  3. Build                │     │                          │
│  4. Generate init_boot   │────→│  5. Download             │
│                          │     │  6. fastboot flash       │
│                          │     │  7. NetHunter install    │
└──────────────────────────┘     └──────────────────────────┘
```

## 3. Flashing Procedure (Windows)

```
:: Enter bootloader
adb reboot bootloader

:: Backup (first time only)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img C:\Users\<USER>\Desktop\backup\

:: Flash the custom kernel
fastboot flash init_boot init_boot.img
fastboot reboot

:: Transfer the NetHunter zip
adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
```

## 4. Recovery (Windows)

If the device fails to boot:

```
:: Hold Power + Volume Down to enter fastboot mode
:: Flash the stock image
fastboot flash init_boot stock_init_boot_a.img
fastboot reboot
```

## Troubleshooting

| Problem | Solution |
|------|------|
| `adb devices` shows nothing | Reinstall USB drivers; verify USB debugging is authorized |
| `fastboot devices` shows nothing | Install Google USB Driver; try a different USB port |
| `apt install` is slow in WSL2 | Fix WSL2 DNS: add `nameserver 8.8.8.8` to `/etc/resolv.conf` |
| WSL2 disk space is insufficient | Follow the vhdx expansion procedure above |
| `adb push` is slow | Use a USB 3.0 port; switch from MTP mode to File Transfer mode |
| Windows antivirus slows down builds | Work within the WSL2 filesystem (`/home/...`); the Windows-side `/mnt/c/` path is slow |
| WSL2 build stops with OOM (out of memory) | Increase the memory limit in `.wslconfig`, or reduce parallelism with `make -j2`. For a reliable solution, use cloud builds (2B) |
| PC has 8 GB RAM or less | Local builds in WSL2 are impractical. Use cloud builds (2B) |
| Less than 100 GB of free disk space | The kernel tree alone requires 50–80 GB. Move WSL2 to an external SSD, or use cloud builds |
| Bazel crashes in WSL2 | Likely caused by insufficient memory. Add the `--jobs=2` option, or switch to cloud builds |
