# Phone (4a) — NetHunter Pro カーネルビルド

| | |
|---|---|
| **コードネーム** | Frogger |
| **SoC** | Qualcomm Snapdragon 7s Gen 3 (SM7635) |
| **アーキテクチャ** | arm64 |
| **WiFiチップ** | WCN6750 (FastConnect, Wi-Fi 6E) |
| **WiFiドライバ** | ath11k (`supports_monitor = false`) |
| **カーネル** | Linux 6.1 (`android14-6.1`) |
| **ツールチェイン** | AOSP Clang `r487747c` (`LLVM=1`) |
| **ビルドシステム** | Kleaf / Bazel |
| **モニターモード** | ❌ ブロック — Phone (3a) と同じWCN6750ファームウェア制限 |

> **Phone (3a) と同一SoC・WiFiチップ。** 違いはカーネルブランチとデバイス固有の設定 (defconfig、デバイスツリー) のみです。

## ソース

| リポジトリ | ブランチ |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | `sm7635/b/mr_Frogger` |

> **注意:** Phone (3a) と同じリポジトリを使用しますが、**ブランチが異なります** (`sm7635/b/mr_Frogger` vs `sm7635/b/mr`)。

## WiFiモニターモードの状況

[Phone (3a)](phone-3a.md#wifiモニターモードの状況) と同じ — WCN6750ファームウェアはモニターモードに対応していません。無線攻撃には外部USB WiFiアダプターが必要です。

### モニターモードなしで使える機能

| 機能 | 状態 |
|---------|:------:|
| USB HID攻撃 (DuckyScript, BadUSB) | ✅ |
| Kali chroot (Metasploit, Nmap, Burp等) | ✅ |
| USB RNDISネットワーキング | ✅ |
| NetHunter KeX (デスクトップ) | ✅ |
| 外部USB WiFi (モニター + インジェクション) | ✅ |
| 内蔵WiFiモニターモード | ❌ |

## 1. ビルド環境

### 依存パッケージ

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves bazel
```

### ソースの取得

```bash
mkdir nothing-4a-kernel && cd nothing-4a-kernel

# 注意: Frogger固有のブランチ
git clone -b sm7635/b/mr_Frogger --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635.git kernel

# AOSP Clang r487747c (Phone 3aと同じ)
# Nothing-Kaliリポジトリをクローン済みの場合:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r487747c
```

## 2. カーネル設定

### Defconfig

Phone (4a) はPhone (3a) と同じQualcomm `pineapple` プラットフォームを使用しますが、Frogger固有のベンダー設定があります:

```
gki_defconfig                              # GKIベース
  + vendor/pineapple_GKI.config            # Qualcomm pineappleプラットフォーム設定
  + vendor/Frogger.config                  # Nothing Phone (4a) デバイス設定
```

### USB ConfigFS (NetHunter HIDガジェット)

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

## 3. カーネルビルド

### Kleaf/Bazel使用 (推奨)

```bash
cd kernel

# pineapple (SM7635) プラットフォーム、gkiバリアントでビルド
python3 build_with_bazel.py -t pineapple gki
```

### レガシーmake使用 (フォールバック)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r487747c/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# defconfigの構成 (注意: Asteroids.configではなくFrogger.config)
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/pineapple_GKI.config \
  arch/arm64/configs/vendor/Frogger.config

# NetHunter設定の有効化
./scripts/enable-nethunter-configs.sh . out

# ビルド
make O=out -j$(nproc)
```

### ビルドの検証

```bash
# 出力の確認
ls -la out/dist/init_boot.img 2>/dev/null || ls -la out/arch/arm64/boot/Image*

# 設定の確認
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config

# 検証スクリプトを使用
../scripts/verify-kernel.sh out
```

## 4. フラッシュ

```bash
# バックアップ (初回カスタムカーネルフラッシュ前に一度だけ)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# フラッシュ
adb reboot bootloader
fastboot flash init_boot out/dist/init_boot.img
fastboot reboot
```

## 5. フラッシュ後の検証

```bash
# カーネルバージョン
adb shell uname -r

# USB ConfigFS
adb shell su -c "ls /config/usb_gadget/"

# WiFi (マネージドモードで動作するはず)
adb shell su -c "iw dev wlan0 info"
```

## 6. NetHunter Proのインストール

[NetHunter Proインストール](nethunter-install.md) を参照。

## 7. 外部WiFiアダプター (WiFi攻撃に必須)

内蔵WiFiはモニターモードに対応していないため、rtl8812auドライバをビルドしてください:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

USB OTG経由でアダプターを接続後にロード:

```bash
adb push 88XXau.ko /sdcard/
adb shell su -c "insmod /sdcard/88XXau.ko"
adb shell su -c "ip link"
# wlan1を確認 → モニターモードに設定
adb shell su -c "iw dev wlan1 set type monitor"
adb shell su -c "ip link set wlan1 up"
```

推奨アダプターと永続ドライバ設定については [外部WiFiアダプター](external-wifi.md) を参照。

## Phone (3a) との相違点

| 項目 | Phone (3a) | Phone (4a) |
|--------|-----------|-----------|
| コードネーム | Asteroids | Frogger |
| カーネルブランチ | `sm7635/b/mr` | `sm7635/b/mr_Frogger` |
| Defconfig | Asteroids固有 | Frogger固有 |
| デバイスツリー | `asteroids.dtsi` | `frogger.dtsi` |
| SoC | SM7635 (同一) | SM7635 (同一) |
| WiFi | WCN6750 (同一) | WCN6750 (同一) |
| Clang | `r487747c` (同一) | `r487747c` (同一) |

ビルド手順はカーネルブランチとdefconfigファイル名を除いて同一です。Phone (4a) 固有の問題でここに記載されていないものがあれば、[Phone (3a) ガイド](phone-3a.md) を確認してください — ほとんどのトラブルシューティングが同様に適用されます。
