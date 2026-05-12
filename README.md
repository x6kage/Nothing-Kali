# Nothing-Kali

Kali NetHunter Pro kernel builds and installation guides for Nothing & CMF devices.

## Device Support

| Device | Codename | SoC | WiFi Chip | Driver | Kernel | Monitor Mode | Status |
|--------|----------|-----|-----------|--------|--------|:---:|--------|
| Phone (1) | Spacewar | Snapdragon 778G+ | WCN6750 | ath11k | 5.4 | ✅ | Supported ([DroidSpace Kernel](https://github.com/ExTV/android_kernel_msm-5.4_nothing_sm7325)) |
| Phone (2) | Pong | Snapdragon 8+ Gen 1 | WCN6855 | ath11k | 5.10 | ❌ | Firmware blocks monitor mode |
| Phone (2a) Series | Pacman | Dimensity 7200 Pro | MT6655 (Connac3) | gen4m | 5.15 | ⚠️ | [Experimental](guides/phone-2a.md) |
| Phone (3a) / (3a) Pro | Asteroids | Snapdragon 7s Gen 3 | WCN6750 | ath11k | 6.1 | ❌ | Firmware blocks monitor mode |
| Phone (3) | Metroid | Snapdragon 8s Gen 4 | WCN7850 (FC 7800) | ath12k | 6.6 | 🔧 | [Patchable](guides/phone-3.md) |
| Phone (4a) | Frogger | Snapdragon 7s Gen 3 | WCN6750 | ath11k | 6.1 | ❌ | Firmware blocks monitor mode |
| Phone (4a) Pro | FroggerPro | Snapdragon 7 Gen 4 | WCN7850 (FC 7800) | ath12k | 6.6 | 🔧 | [Patchable](guides/phone-4a-pro.md) |

### Legend

- ✅ Community kernel with NetHunter support exists
- 🔧 Upstream driver patches available — kernel build required
- ⚠️ Driver code exists but untested on this chip — experimental
- ❌ Firmware limitation — internal WiFi monitor mode not possible

## Architecture

All Nothing phones are **arm64 (aarch64)**. Use **NetHunter Pro Generic arm64** from the [official download page](https://www.kali.org/get-kali/#kali-mobile).

## Guides

### Start Here

- **[Kernel Build Overview — What You're Actually Doing](guides/kernel-build-overview.md)** — 何が変わって何が変わらないのか、ビルドで詰まるポイントと対処法、復旧方法

### Kernel Build (per device)

- [Phone (2a) Series — MT6886 / gen4m](guides/phone-2a.md)
- [Phone (3) — SM8735 / ath12k / WCN7850](guides/phone-3.md)
- [Phone (3a) / (3a) Pro — SM7635 / ath11k](guides/phone-3a.md)
- [Phone (4a) — SM7635 / ath11k](guides/phone-4a.md)
- [Phone (4a) Pro — SM7750 / ath12k / WCN7850](guides/phone-4a-pro.md)

### Common

- [NetHunter Pro Installation](guides/nethunter-install.md)

## Prerequisites

All devices require:

1. **Unlocked bootloader** — see [Nothing Archive guides](https://spike0en.github.io/nothing_archive/docs/guides#unlocking-bootloader)
2. **Root access** (Magisk / KernelSU / KernelSU Next)
3. **Partition backups** — always back up `persist`, `nvram`, etc. before flashing custom kernels
4. **Build environment** — Linux x86_64 host with:
   - `aarch64-linux-gnu-` cross-compiler toolchain
   - Android NDK (for Qualcomm) or MTK build tools (for MediaTek)
   - `mkbootimg`, `lz4`, `dtc`

## Kernel Sources (NothingOSS)

| Device | Kernel Source | Kernel Modules |
|--------|-------------|----------------|
| Phone (2a) Series | [android_kernel_5.15_nothing_mt6886](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) | [android_kernel_modules_nothing_mt6886](https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886) |
| Phone (3a) / (3a) Pro | [android_kernel_msm-6.1_nothing_sm7635](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | — |
| Phone (3) | [android_kernel_msm-6.6_nothing_sm8735](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735) | — |
| Phone (4a) | [android_kernel_msm-6.1_nothing_sm7635](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) (`sm7635/b/mr_Frogger`) | — |
| Phone (4a) Pro | [android_kernel_msm-6.6_nothing_sm7750](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750) | — |

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

## Disclaimer

> This project is independent and not affiliated with Nothing Technology Limited or Offensive Security / Kali Linux.
> Flashing custom kernels can brick your device and will void your OEM warranty. Proceed at your own risk.
> Back up all partitions before making any modifications.

## License

MIT
