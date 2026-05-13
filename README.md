# Nothing-Kali

**[日本語版はこちら / Japanese](README.ja.md)**

> Kali NetHunter Pro kernel builds and installation guides for Nothing & CMF devices.

Turn your Nothing phone into a portable penetration testing platform — without losing everyday functionality.

---

## Quick Start

1. **Check [Device Support](#device-support)** to see what's possible on your phone
2. **Read [Kernel Build Overview](guides/kernel-build-overview.md)** to understand what's being modified and why
3. **Follow your [device-specific guide](#kernel-build-per-device)** to build and flash the kernel
4. **Install [NetHunter Pro](guides/nethunter-install.md)** for the penetration testing toolkit

## Device Support

| Device | Codename | SoC | WiFi Chip | Driver | Kernel | Monitor Mode | Status |
|--------|----------|-----|-----------|--------|--------|:---:|--------|
| Phone (1) | Spacewar | Snapdragon 778G+ | WCN6750 | ath11k | 5.4 | ✅ | Supported ([DroidSpace Kernel](https://github.com/ExTV/android_kernel_msm-5.4_nothing_sm7325)) |
| Phone (2) | Pong | Snapdragon 8+ Gen 1 | WCN6855 | ath11k | 5.10 | ❌ | Firmware blocks monitor mode |
| Phone (2a) Series | Pacman | Dimensity 7200 Pro | MT6655 (Connac3) | gen4m | 5.15 | ⚠️ | [Experimental](guides/phone-2a.md) |
| Phone (3a) / (3a) Pro | Asteroids | Snapdragon 7s Gen 3 | WCN6750 | ath11k | 6.1 | ❌ | [USB HID only](guides/phone-3a.md) |
| Phone (3) | Metroid | Snapdragon 8s Gen 4 | WCN7850 (FC 7800) | ath12k | 6.6 | 🔧 | [Patchable](guides/phone-3.md) |
| Phone (4a) | Frogger | Snapdragon 7s Gen 3 | WCN6750 | ath11k | 6.1 | ❌ | [USB HID only](guides/phone-4a.md) |
| Phone (4a) Pro | FroggerPro | Snapdragon 7 Gen 4 | WCN7850 (FC 7800) | ath12k | 6.6 | 🔧 | [Patchable](guides/phone-4a-pro.md) |

### Legend

- ✅ Community kernel with NetHunter support exists
- 🔧 Upstream driver patches available — kernel build required
- ⚠️ Driver code exists but untested on this chip — experimental
- ❌ Firmware limitation — internal WiFi monitor mode not possible (external USB adapter needed)

### Which Device Should I Get?

If you're choosing a Nothing phone specifically for pentesting:

| Priority | Best Choice | Why |
|----------|-------------|-----|
| Internal WiFi monitor mode | **Phone (3)** or **Phone (4a) Pro** | WCN7850 with patchable ath12k driver |
| Budget + USB HID attacks | **Phone (2a)** | Cheapest option, full USB ConfigFS support |
| Already own | Any supported device | USB HID + Kali chroot works on all devices |

## Architecture

All Nothing phones are **arm64 (aarch64)**. Use **NetHunter Pro Generic arm64** from the [official download page](https://www.kali.org/get-kali/#kali-mobile).

## Guides

### Start Here

- **[Kernel Build Overview — What You're Actually Doing](guides/kernel-build-overview.md)** — what changes, what doesn't, where builds fail, and how to recover

### Kernel Build (per device)

- [Phone (2a) Series — MT6886 / gen4m](guides/phone-2a.md)
- [Phone (3) — SM8735 / ath12k / WCN7850](guides/phone-3.md)
- [Phone (3a) / (3a) Pro — SM7635 / ath11k](guides/phone-3a.md)
- [Phone (4a) — SM7635 / ath11k](guides/phone-4a.md)
- [Phone (4a) Pro — SM7750 / ath12k / WCN7850](guides/phone-4a-pro.md)

### Common

- [NetHunter Pro Installation](guides/nethunter-install.md) — ARM64 verification, download, install
- [External WiFi Adapters](guides/external-wifi.md)
- [Troubleshooting](guides/troubleshooting.md)
- [Security & Operational Considerations](guides/security.md)

### Platform Setup

- [Windows Setup](guides/setup-windows.md) — ADB/Fastboot, WSL2 / cloud kernel build
- [macOS Setup](guides/setup-macos.md) — Homebrew, OrbStack / UTM / Docker kernel build

## Prerequisites

All devices require:

1. **Unlocked bootloader** — see [Nothing Archive guides](https://spike0en.github.io/nothing_archive/docs/guides#unlocking-bootloader)
2. **Root access** (Magisk / KernelSU / KernelSU Next)
3. **Partition backups** — always back up `persist`, `nvram`, etc. before flashing custom kernels
4. **Build environment** — Linux x86_64 host with:
   - AOSP prebuilt clang (version varies by device — see [Kernel Build Overview](guides/kernel-build-overview.md#1-toolchain))
   - `mkbootimg`, `lz4`, `dtc`
   - 16 GB+ RAM, 100–150 GB disk space
   - **Windows:** [Windows Setup Guide](guides/setup-windows.md) (WSL2 or cloud build)
   - **macOS:** [macOS Setup Guide](guides/setup-macos.md) (OrbStack / UTM / Docker)

### Build Environment Quick Setup

```bash
# Ubuntu 22.04+ / Debian 12+
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod

# Download the correct clang for your device
./scripts/setup-clang.sh r510928    # Phone (3) / Phone (4a) Pro
./scripts/setup-clang.sh r487747c   # Phone (3a) / Phone (4a)
./scripts/setup-clang.sh r450784e   # Phone (2a) Series
```

## Kernel Sources (NothingOSS)

| Device | Kernel Source | Kernel Modules |
|--------|-------------|----------------|
| Phone (2a) Series | [android_kernel_5.15_nothing_mt6886](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) | [android_kernel_modules_nothing_mt6886](https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886) |
| Phone (3a) / (3a) Pro | [android_kernel_msm-6.1_nothing_sm7635](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | — |
| Phone (3) | [android_kernel_msm-6.6_nothing_sm8735](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735) | — |
| Phone (4a) | [android_kernel_msm-6.1_nothing_sm7635](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) (`sm7635/b/mr_Frogger`) | — |
| Phone (4a) Pro | [android_kernel_msm-6.6_nothing_sm7750](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750) | — |

## Capability Matrix

What you can do with each device after building and installing NetHunter Pro:

| Capability | All Devices | Phone (3) / (4a) Pro | Phone (2a) |
|-----------|:-----------:|:---------------------:|:-----------:|
| USB HID keyboard/mouse attacks | ✅ | ✅ | ✅ |
| DuckyScript execution | ✅ | ✅ | ✅ |
| Kali chroot (Metasploit, Nmap, etc.) | ✅ | ✅ | ✅ |
| RNDIS USB tethering | ✅ | ✅ | ✅ |
| NetHunter KeX (desktop) | ✅ | ✅ | ✅ |
| Internal WiFi monitor mode | ❌ | 🔧 Patchable | ⚠️ Experimental |
| Internal WiFi packet injection | ❌ | ⚠️ Limited by FW | ❌ |
| External USB WiFi (monitor + inject) | ✅ | ✅ | ✅ |
| Bluetooth (Ubertooth) | ✅ | ✅ | ✅ |

## FAQ

### Is this safe? Will it brick my phone?

The risk of a permanent brick is extremely low. You're replacing only the kernel image — partition tables, baseband firmware, and userdata remain untouched. If the custom kernel fails to boot, you can always recover via fastboot (power + volume down) by flashing the stock boot image from [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware). See [Recovery Procedures](guides/troubleshooting.md#recovery-procedures) for step-by-step instructions.

### Will my phone still work as a daily driver?

Yes. Calls, SMS, WiFi (normal mode), Bluetooth, camera, fingerprint, NFC — everything works exactly as before. The only thing that breaks is OTA updates, which can be re-enabled by restoring the stock kernel. See the [Kernel Build Overview](guides/kernel-build-overview.md) for details.

### Do I need to root my phone?

Yes. Root access (Magisk, KernelSU, or KernelSU Next) is required for NetHunter to function. Root is needed to load kernel modules, configure USB gadgets, and switch WiFi modes.

### My device shows ❌ for monitor mode. Is NetHunter still useful?

Absolutely. WiFi monitor mode is just one feature. USB HID attacks (BadUSB / DuckyScript), the full Kali Linux chroot with Metasploit/Nmap/Burp, RNDIS networking, and Bluetooth tooling all work without monitor mode. You can also use an [external USB WiFi adapter](guides/external-wifi.md) for wireless attacks.

### What's the difference between NetHunter, NetHunter Lite, and NetHunter Pro?

| Variant | Requires | Custom Kernel | USB HID | WiFi Tools |
|---------|----------|:---:|:---:|:---:|
| **NetHunter Pro** | Unlocked bootloader + root + custom kernel | ✅ | ✅ | ✅ (if kernel supports it) |
| **NetHunter (Rootless)** | Nothing | ❌ | ❌ | ❌ |
| **NetHunter Lite** | Root only | ❌ | ❌ | Limited |

This project focuses on **NetHunter Pro** because it's the only variant that supports USB HID attacks and custom kernel features.

### Can I go back to stock?

Yes, at any time. Flash the stock `init_boot.img` (or `boot.img`) from [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) via fastboot, and your phone returns to its original state. OTA updates will work again.

## References

### Nothing Archive

This project builds on data and guides from [**Nothing Archive**](https://spike0en.github.io/nothing_archive/) ([GitHub](https://github.com/spike0en/nothing_archive)) — the community-maintained hub for Nothing & CMF firmware, guides, and aftermarket development resources. Nothing Archive provides:

- [Bootloader unlock / root / flash guides](https://spike0en.github.io/nothing_archive/docs/guides)
- [OTA firmware downloads](https://spike0en.github.io/nothing_archive/docs/firmware) and [stock boot images](https://spike0en.github.io/nothing_archive/docs/firmware) for safe recovery
- [Official kernel sources index](https://spike0en.github.io/nothing_archive/docs/official#kernel-sources)
- [Device catalog](https://spike0en.github.io/nothing_archive/docs/devices) (codenames, model numbers, SoC info)
- [Aftermarket development channels](https://spike0en.github.io/nothing_archive/docs/guides#aftermarket-development) (custom ROM/kernel Telegram channels)

Always back up your partitions using the [Nothing Archive backup guide](https://spike0en.github.io/nothing_archive/docs/guides#backing-up-essential-partitions) before flashing custom kernels.

### Kali NetHunter

- [Kali NetHunter — Porting to New Devices](https://www.kali.org/docs/nethunter/porting-nethunter/)
- [Kali NetHunter — Kernel Builder](https://www.kali.org/docs/nethunter/porting-nethunter-kernel-builder/)
- [NetHunter Kernel Patches](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels)
- [NetHunter Project (Installer)](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project)

### Existing NetHunter Work for Nothing Devices

- [DroidSpace Kernel](https://github.com/ExTV/android_kernel_msm-5.4_nothing_sm7325) — Phone (1) custom kernel with NetHunter + Docker support by ExTV
- [nethunter-spacewar](https://github.com/ExTV/nethunter-spacewar) — Phone (1) NetHunter Magisk module by ExTV

### Upstream WiFi Driver Resources

- [ath12k mailing list](http://lists.infradead.org/pipermail/ath12k/) — monitor mode patches for WCN7850
- [mt76 driver (upstream)](https://github.com/openwrt/mt76) — upstream MediaTek WiFi driver (not used by gen4m but useful for reference)
- [rtl8812au (aircrack-ng fork)](https://github.com/aircrack-ng/rtl8812au) — external USB WiFi driver for Realtek adapters

## Contributing

Contributions welcome! If you have:

- **Tested a build** on a device listed here — open an issue with your results (success or failure, logs, firmware version)
- **Found a fix** for a build error — submit a PR with the fix and a description of the error
- **Ported to a new device** — submit a PR adding a new device guide in `guides/`
- **Firmware research** — any findings about monitor mode enablement on ❌ devices are valuable

### Structure

```
Nothing-Kali/
├── README.md                          # This file
├── guides/
│   ├── kernel-build-overview.md       # Start here — what/why/how
│   ├── nethunter-install.md           # ARM64 verification + download + install
│   ├── phone-2a.md                    # Phone (2a) kernel build
│   ├── phone-3.md                     # Phone (3) kernel build + monitor mode
│   ├── phone-3a.md                    # Phone (3a) kernel build
│   ├── phone-4a.md                    # Phone (4a) kernel build
│   ├── phone-4a-pro.md               # Phone (4a) Pro kernel build + monitor mode
│   ├── external-wifi.md               # External USB WiFi adapters
│   ├── troubleshooting.md             # Common problems and solutions
│   ├── security.md                    # OpSec and safety considerations
│   ├── setup-windows.md              # Windows: ADB/Fastboot + WSL2 build env
│   ├── setup-macos.md                # macOS: Homebrew + VM/Docker build env
│   └── ja/                           # Japanese translations (日本語版)
│       └── (mirrors of all guides above)
└── scripts/
    ├── enable-nethunter-configs.sh    # Enable USB ConfigFS in kernel config
    ├── setup-clang.sh                 # Download AOSP clang prebuilts
    ├── verify-kernel.sh               # Verify kernel config after build
    └── build-rtl8812au.sh             # Cross-compile rtl8812au driver
```

## Disclaimer

> This project is independent and not affiliated with Nothing Technology Limited or Offensive Security / Kali Linux.
> Flashing custom kernels can brick your device and will void your OEM warranty. Proceed at your own risk.
> Back up all partitions before making any modifications.
> This toolset is intended for authorized security testing and educational purposes only.

## License

MIT
