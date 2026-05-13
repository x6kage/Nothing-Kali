# Phone (4a) Pro — NetHunter Pro カーネルビルド

| | |
|---|---|
| **コードネーム** | FroggerPro |
| **SoC** | Qualcomm Snapdragon 7 Gen 4 (SM7750) |
| **アーキテクチャ** | arm64 |
| **WiFiチップ** | WCN7850 (FastConnect 7800, Wi-Fi 7) |
| **WiFiドライバ** | ath12k |
| **カーネル** | Linux 6.6 (`android15-6.6`) |
| **ツールチェイン** | AOSP Clang `r510928` (`LLVM=1`) |
| **ビルドシステム** | Kleaf / Bazel |
| **モニターモード** | 🔧 パッチ適用可能 — Phone (3) と同じWCN7850 + ath12k |

> **Phone (3) とWiFiハードウェアを共有。** どちらもカーネル6.6上でWCN7850チップとath12kドライバを使用します。アップストリームのモニターモードパッチは両方のデバイスに対して同一またはほぼ同一の結果で適用できます。

## ソース

| リポジトリ | ブランチ |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750) | `sm7750/b/FroggerPro` |

## WiFiモニターモード

Phone (4a) Proは Phone (3) と**同じWCN7850 WiFiチップとath12kドライバ**を使用します。アップストリームath12kモニターモードパッチシリーズ (13パッチ、2025年4月) は両方のデバイスに適用可能です。

完全なパッチ適用手順、コンフリクト解決ガイド、ファームウェア互換性の詳細については、**[Phone (3) — WCN7850モニターモードの有効化](phone-3.md#3-wcn7850モニターモードの有効化)** を参照してください。

### 概要

1. `drivers/net/wireless/ath/ath12k/hw.c` で `supports_monitor = true` に切り替え
2. [13パッチのWCN7850モニターモードシリーズ](http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html) をバックポート
3. 両方のステップが必要 — フラグの切り替えだけではクラッシュする

Phone (3) と Phone (4a) Pro はどちらも同じAOSP clangバージョン (`r510928`) のカーネル6.6を使用しているため、パッチは同一またはほぼ同一のコンフリクトで適用されるはずです。

### Phone (3) との潜在的な相違点

WiFiハードウェアとドライバは同一ですが、SM7750 SoCでは以下がわずかに異なる場合があります:

- デバイスツリー設定 (SoCが異なる → プラットフォームDTSが異なる)
- ベンダーカーネルパッチ (QualcommがSoCごとに異なるベンダーパッチを出荷する場合がある)
- ath12kファームウェアバージョン (ファームウェアを確認 — 下記参照)

```bash
# Phone (4a) Proのファームウェアバージョンを確認
adb shell ls /vendor/firmware/ath12k/WCN7850/hw2.0/
adb shell su -c "dmesg | grep ath12k | grep firmware"
```

## 1. ビルド環境

### ホスト要件

- Ubuntu 22.04以上 (x86_64)
- ディスク空き容量 150GB以上
- RAM 16GB以上 (32GB推奨)

### 依存パッケージ

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves bazel
```

### ソースの取得

```bash
mkdir nothing-4a-pro-kernel && cd nothing-4a-pro-kernel

git clone -b sm7750/b/FroggerPro --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750.git kernel

# AOSP Clang r510928 (Phone 3と同じ)
# Nothing-Kaliリポジトリをクローン済みの場合:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r510928
# 手動の場合:
mkdir -p prebuilts/clang/host/linux-x86
# https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/ からダウンロード
```

## 2. カーネル設定

### Defconfig

Phone (4a) Pro はQualcomm `sun` プラットフォーム (Phone 3と同じ) を使用します。defconfigは以下から構成されます:

```
gki_defconfig                          # GKIベース
  + vendor/sun_perf.config             # Qualcomm sunプラットフォーム設定
  + vendor/FroggerPro.config           # Nothing Phone (4a) Pro デバイス設定
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

defconfigの読み込み後:

```bash
./scripts/enable-nethunter-configs.sh . out
```

### モニターモードパッチ

[Phone (3) — WCN7850モニターモードの有効化](phone-3.md#3-wcn7850モニターモードの有効化) と同一の手順に従います:

1. **フラグの切り替え:** `drivers/net/wireless/ath/ath12k/hw.c` を編集し、WCN7850の `supports_monitor = true` に設定
2. **パッチのダウンロード:** ath12kメーリングリストから13パッチシリーズを取得
3. **パッチの適用:** 各パッチを順番に `git am`
4. **コンフリクトの解決:** Phone (3) と同じコンフリクト箇所 — `dp_mon.c`、`hw.c`、`hal.c`

> **ヒント:** Phone (3) のカーネルツリーに既にパッチを適用済みの場合、結合パッチを生成してここに適用できます:
> ```bash
> # Phone (3) ツリーでパッチ適用後:
> git format-patch HEAD~14..HEAD -o ../shared-patches/
> # Phone (4a) Pro ツリーで:
> for p in ../shared-patches/*.patch; do git am "$p"; done
> ```

## 3. カーネルビルド

### Kleaf/Bazel使用 (推奨)

```bash
cd kernel

# sun (SM7750) プラットフォーム、perfバリアントでビルド
python3 build_with_bazel.py -t sun perf
```

出力は `out/msm-kernel-sun-perf/dist/` に生成されます。

### レガシーmake使用 (フォールバック)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r510928/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# defconfigの構成
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/sun_perf.config \
  arch/arm64/configs/vendor/FroggerPro.config

# NetHunter設定の有効化
./scripts/enable-nethunter-configs.sh . out

# ビルド
make O=out -j$(nproc)
```

### ビルドの検証

```bash
# 出力の確認
ls -la out/dist/init_boot.img 2>/dev/null || ls -la out/arch/arm64/boot/Image*

# USB ConfigFSの確認
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config

# モニターモードフラグの確認
grep "supports_monitor" out/.config 2>/dev/null
# またはコンパイル済みソースを確認:
grep -r "supports_monitor" drivers/net/wireless/ath/ath12k/hw.c

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

## 5. モニターモードの検証

```bash
adb shell su -c "ip link set wlan0 down"
adb shell su -c "iw dev wlan0 set type monitor"
adb shell su -c "ip link set wlan0 up"
adb shell su -c "iw dev wlan0 info"
# 期待値: type monitor
```

### モニターモードが失敗する場合

```bash
# サポートされるインターフェースモードを確認
adb shell su -c "iw phy phy0 info | grep -A 10 'Supported interface modes'"

# カーネルログを確認
adb shell su -c "dmesg | grep -i ath12k | tail -30"

# ファームウェアを確認
adb shell su -c "ls /vendor/firmware/ath12k/WCN7850/hw2.0/"
```

[Phone (3) のトラブルシューティング](phone-3.md#6-モニターモードの検証) と [トラブルシューティング](troubleshooting.md) で詳細を参照してください。

## 6. NetHunter Proのインストール

[NetHunter Proインストール](nethunter-install.md) を参照。

## 7. 外部WiFi (オプション)

内蔵モニターモードが動作していても、外部アダプターは信頼性の高いパケットインジェクションを提供します:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

推奨アダプターと使用方法については [外部WiFiアダプター](external-wifi.md) を参照。

## Phone (3) との相違点

| 項目 | Phone (3) | Phone (4a) Pro |
|--------|----------|---------------|
| コードネーム | Metroid | FroggerPro |
| SoC | SM8735 (Snapdragon 8s Gen 4) | SM7750 (Snapdragon 7 Gen 4) |
| カーネルリポジトリ | `android_kernel_msm-6.6_nothing_sm8735` | `android_kernel_msm-6.6_nothing_sm7750` |
| ブランチ | `sm8735/b/mr` | `sm7750/b/FroggerPro` |
| WiFiチップ | WCN7850 (同一) | WCN7850 (同一) |
| WiFiドライバ | ath12k (同一) | ath12k (同一) |
| カーネルバージョン | 6.6 (同一) | 6.6 (同一) |
| Clangバージョン | `r510928` (同一) | `r510928` (同一) |
| モニターモードパッチ | 適用可能 ✅ | 同じパッチが適用可能 ✅ |
