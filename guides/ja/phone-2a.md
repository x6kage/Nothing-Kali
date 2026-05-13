# Phone (2a) シリーズ — NetHunter Pro カーネルビルド

| | |
|---|---|
| **コードネーム** | Pacman / PacmanPro |
| **SoC** | MediaTek Dimensity 7200 Pro (MT6886) |
| **CPU** | 2x Cortex-A715 @ 2.8GHz + 6x Cortex-A510 @ 2.0GHz |
| **アーキテクチャ** | arm64 (ARMv9.0-A) |
| **WiFiチップ** | MT6655 (Connac3, Wi-Fi 6E 2T2R) |
| **WiFiドライバ** | gen4m (MediaTekベンダー製、アップストリームmt76ではない) |
| **カーネル** | Linux 5.15 (`android13-5.15`) |
| **ツールチェイン** | AOSP Clang `r450784e` (`LLVM=1`) |
| **ビルドシステム** | Kleaf / Bazel |
| **モニターモード** | ⚠️ 実験的 — MT6655向けスニファーコードは存在するが無効化されている |

> **対象機種:** Phone (2a) Plus にも適用 (同一SoC、カーネル、WiFiチップ)

## ソース

| リポジトリ | ブランチ |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) | `mt6886/Pacman/v` |
| [Kernel Modules](https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886) | `mt6886/Pacman/v` |

## 1. ビルド環境

### ホスト要件

- Ubuntu 22.04以上 (x86_64)
- ディスク空き容量 100GB以上 (MediaTekカーネル + モジュールは大きい)
- RAM 16GB以上 (並列ビルドには32GB推奨)

### 依存パッケージ

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves

# Bazelのインストール (KleafはBazelを使用)
# 最新の手順は https://bazel.build/install/ubuntu を参照
sudo apt install -y apt-transport-https gnupg
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings/
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update && sudo apt install -y bazel
```

### ソースの取得

```bash
mkdir nothing-2a-kernel && cd nothing-2a-kernel

# カーネル
git clone -b mt6886/Pacman/v --depth=1 \
  https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886.git kernel

# カーネルモジュール (WLAN gen4mドライバを含む)
git clone -b mt6886/Pacman/v --depth=1 \
  https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886.git modules

# AOSP Clang r450784e
# Nothing-Kaliリポジトリをクローン済みの場合:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r450784e
# 手動の場合:
mkdir -p prebuilts/clang/host/linux-x86
cd prebuilts/clang/host/linux-x86
git clone --depth=1 \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  -b main clang-r450784e
cd ../../../../
```

> **注意:** AOSPのclangプリビルトは大きい (~2 GB)。代替として、[Android CI](https://ci.android.com/) から特定のclangバージョンのtarballのみをダウンロードするか、`repo init` でAndroidカーネルマニフェストを使用する方法もあります。

## 2. カーネル設定

### MediaTekカーネル構造の理解

MediaTekカーネルはQualcommとはいくつかの点で異なります:

```
kernel/                           # メインカーネルツリー
├── arch/arm64/configs/           # Defconfig
├── drivers/                      # ツリー内ドライバ
└── build.config.*                # ビルド設定

modules/                          # ツリー外ベンダーモジュール
├── connectivity/
│   └── wlan/
│       └── core/
│           └── gen4m/            # ← WiFiドライバはここ
├── gpu/
├── display/
└── ...
```

WiFiドライバは**メインカーネルツリーには含まれていません** — `modules` リポジトリからツリー外モジュールとしてコンパイルされます。つまり、カーネルとWLANモジュールを別々にビルドする必要があります。

### Defconfig

Phone (2a) は `build.config.gki` で指定された `gki_defconfig` を使用します:

```
DEFCONFIG=gki_defconfig
```

MTKビルドシステム (Kleaf) は `gki_defconfig` を直接使用します。レガシー `make` ビルドの場合:

```bash
make O=out gki_defconfig
```

### USB ConfigFS (NetHunter HIDガジェット)

defconfigの読み込み後、ConfigFSを有効化します:

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

または `make O=out <defconfig>` 実行後にヘルパースクリプトを使用:

```bash
../../scripts/enable-nethunter-configs.sh . out
```

### なぜNDKやGCCではなくAOSP Clangなのか?

NothingOSSカーネルはAOSPプリビルトclang (`LLVM=1`) とKleafビルドシステムでビルドされます。`build.config.common` には以下が明示的に設定されています:

```
LLVM=1
CLANG_PREBUILT_BIN=prebuilts/clang/host/linux-x86/clang-r450784e/bin
```

- **Android NDK** はユーザースペース (アプリ/ライブラリ) 向けであり、カーネルコンパイル用ではありません。NDKはAndroid libcを対象とした異なるclangビルドとsysrootを含んでおり、カーネルビルドには不適切です。
- **ベアメタルGCC** (`aarch64-linux-gnu-gcc`) は技術的にカーネルをコンパイルできますが、これらのカーネルはAOSP clang + LTOでテスト・検証されています。GCCを使用すると微妙なABI不一致、コンパイラ機能の欠如、LTO非互換性のリスクがあります。
- ベンダーが使用した**正確なAOSP clangバージョン**を使うことで、ストックベンダーモジュールとのバイナリ互換性が保証され、KMI (Kernel Module Interface) の破損を回避できます。

## 3. 内蔵WiFiモニターモード (実験的)

gen4m WLANドライバにはスニファー/radiotapサポートコードがありますが、ストックのMakefileでは**MT6985のみ有効**になっています。

### ドライバソースに存在するもの

```
modules/connectivity/wlan/core/gen4m/
├── nic/radiotap.c                  # Radiotapヘッダ構築
├── include/nic/radiotap.h          # Radiotap構造体
├── include/config.h                # CFG_SUPPORT_SNIFFER_RADIOTAPフラグ
├── common/wlan_oid.c               # wlanoidSetIcsSniffer() — ファームウェアスニファーコマンド
├── os/linux/gl_hook_api.c          # モニターモードを含むNetdevオペレーション
└── Makefile                        # CONFIG_SNIFFER_RADIOTAPはMT6985のみで有効
```

### MT6655での有効化方法

`modules/connectivity/wlan/core/gen4m/Makefile` を編集:

```diff
 ifneq ($(filter MT6655,$(MTK_COMBO_CHIP)),)
 ccflags-y:=$(filter-out -UMT6655,$(ccflags-y))
 ccflags-y += -DMT6655
+CONFIG_SNIFFER_RADIOTAP=y
 ifeq ($(MTK_ANDROID_WMT), y)
```

これにより以下が有効になります:
- `CFG_SUPPORT_SNIFFER_RADIOTAP` コンパイルフラグ
- `CFG_SUPPORT_PDMA_SCATTER` (DMAスキャッター用)
- `radiotap.o` のモジュールへのコンパイル
- ファームウェアスニファーコマンドパス (`MCU_UNI_CMD_SNIFFER`)

### コードパスの動作

スニファーモードが有効な場合:

1. **ドライバ側:** `wlanoidSetIcsSniffer()` がWiFiファームウェアに `MCU_UNI_CMD_SNIFFER` を送信
2. **ファームウェア側:** ファームウェアがサポートしていれば、チップがスニファーモードに切り替わり、radiotapヘッダ付きの生802.11フレームを配信
3. **カーネル側:** `radiotap.c` が `tcpdump` や `airodump-ng` 等のツール用に適切なradiotapヘッダを構築

### 注意事項

- **ファームウェアの受け入れは未確認。** ドライバはファームウェアに `MCU_UNI_CMD_SNIFFER` を送信しますが、MT6655のファームウェアはこれを黙って無視するかエラーを返す可能性があります。
- **デフォルトではエラーログなし。** `wlanoidSetIcsSniffer()` の前後にデバッグプリントを追加して、コマンドが成功するか確認してください:
  ```c
  // wlan_oid.c内、コマンド送信後:
  DBGLOG(INIT, INFO, "Sniffer command result: %d\n", rStatus);
  ```
- **パケットインジェクション (TX) はファームウェアのリバースエンジニアリングなしではほぼ確実に非対応**です。
- **テスト方法:** 有効化・ビルド後、以下を試してください:
  ```bash
  su
  # ドライバがスニファー機能を公開しているか確認
  cat /proc/net/wlan/status
  # iwでモニターモード設定を試行
  ip link set wlan0 down
  iw dev wlan0 set type monitor
  ip link set wlan0 up
  ```
- **代替手段:** モニターモードが動作しない場合は、外部USB WiFiアダプターを使用してください ([外部WiFiアダプター](external-wifi.md) 参照)。

## 4. カーネルビルド

### Kleaf/Bazel使用 (推奨)

```bash
cd kernel

# 環境変数の設定
export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r450784e/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# Kleafでビルド
tools/bazel run //common:kernel_aarch64_dist
```

### build.sh使用 (レガシーフォールバック)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export KERNEL_DIR=kernel
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r450784e/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

build/build.sh
```

### MediaTek固有のビルドトラブルシューティング

| 問題 | 対処 |
|-------|-----|
| `MTK_PLATFORM not defined` | `build.config.*` で正しいプラットフォーム変数を確認 |
| `Cannot find DTS include` | MediaTekのDTSファイルは `arch/arm64/boot/dts/mediatek/` にある場合がある — インクルードを確認 |
| モジュールバージョン不一致 | カーネルとモジュールのリポジトリが同じブランチ/タグであることを確認 |
| `CONFIG_MTK_*` エラー | MediaTekベンダー設定 — defconfigで正しい値を確認 |

## 5. WLANモジュールのビルド

WiFiドライバはコンパイル済みカーネルに対して別途ビルドする必要があります:

```bash
cd modules/connectivity/wlan/core/gen4m

export ARCH=arm64
export LLVM=1
export KERNEL_SRC=../../../../../kernel/out

make -C ${KERNEL_SRC} M=$(pwd) \
  LLVM=1 ARCH=arm64 \
  MTK_COMBO_CHIP=MT6655 \
  MTK_ANDROID_WMT=y \
  WLAN_CHIP_ID=6886 \
  modules
```

出力: `wlan_drv_gen4m.ko`

### モジュールの検証

```bash
# モジュールがビルドされたか確認
ls -la wlan_drv_gen4m.ko

# モジュール情報の確認
modinfo wlan_drv_gen4m.ko

# スニファーを有効にした場合、radiotapシンボルを確認
nm wlan_drv_gen4m.ko | grep -i radiotap
# CONFIG_SNIFFER_RADIOTAP=y が有効であればradiotap関連シンボルが表示される
```

## 6. フラッシュ

Phone (2a) はカーネルイメージに **`init_boot`** を使用します:

```bash
# ステップ1: 現在のinit_bootをバックアップ (初回フラッシュ前に一度だけ)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# ステップ2: ブートローダーに再起動
adb reboot bootloader

# ステップ3: ビルドしたカーネルをフラッシュ
fastboot flash init_boot <path-to-built-init_boot.img>
fastboot reboot
```

WLANモジュールの置き換え:

```bash
adb push wlan_drv_gen4m.ko /sdcard/
adb shell su -c "mount -o rw,remount /vendor"
adb shell su -c "cp /sdcard/wlan_drv_gen4m.ko /vendor/lib/modules/wlan_drv_gen4m.ko"
adb shell su -c "chmod 644 /vendor/lib/modules/wlan_drv_gen4m.ko"
adb shell su -c "mount -o ro,remount /vendor"
adb reboot
```

> **重要:** 置き換え前にオリジナルの `wlan_drv_gen4m.ko` をバックアップしてください:
> ```bash
> adb shell su -c "cp /vendor/lib/modules/wlan_drv_gen4m.ko /sdcard/stock_wlan_drv_gen4m.ko"
> adb pull /sdcard/stock_wlan_drv_gen4m.ko
> ```

## 7. フラッシュ後の検証

```bash
# カーネルバージョンの確認
adb shell uname -r

# USB ConfigFSの確認
adb shell su -c "ls /config/usb_gadget/"

# WLANモジュールのロード確認
adb shell su -c "lsmod | grep wlan"

# WiFiが動作しているか確認 (通常モード)
adb shell su -c "ip link show wlan0"

# スニファーパッチを適用した場合、カーネルログでradiotapを確認
adb shell su -c "dmesg | grep -i radiotap"
```

## 8. NetHunter Proのインストール

[NetHunter Proインストール](nethunter-install.md) を参照。

## 9. 外部WiFiアダプター (代替手段)

内蔵WiFiのモニターモードが動作しない場合 (MT6655では想定内)、ビルドしたカーネルに対してrtl8812auをクロスコンパイルしてください:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=<path-to-kernel-out> \
  modules
```

出力: `88XXau.ko` — OTG経由でRTL8812AUベースのUSBアダプターを接続後にロードしてください。

推奨アダプターと詳細なセットアップについては [外部WiFiアダプター](external-wifi.md) を参照。
