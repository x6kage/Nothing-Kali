# Phone (3a) / (3a) Pro — NetHunter Pro カーネルビルド

| | |
|---|---|
| **コードネーム** | Asteroids / AsteroidsPro |
| **SoC** | Qualcomm Snapdragon 7s Gen 3 (SM7635) |
| **アーキテクチャ** | arm64 |
| **WiFiチップ** | WCN6750 (FastConnect, Wi-Fi 6E) |
| **WiFiドライバ** | ath11k (`supports_monitor = false`) |
| **カーネル** | Linux 6.1 (`android14-6.1`) |
| **ツールチェイン** | AOSP Clang `r487747c` (`LLVM=1`) |
| **ビルドシステム** | Kleaf / Bazel |
| **モニターモード** | ❌ ブロック — ファームウェア制限、アップストリームの回避策なし |

> **Phone (4a) と同一プラットフォーム。** Phone (4a) (コードネーム Frogger) は同一SoCとWiFiチップを使用しますが、カーネルブランチが異なります。相違点については [Phone (4a)](phone-4a.md) を参照してください。

## ソース

| リポジトリ | ブランチ |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | `sm7635/b/mr` |

## WiFiモニターモードの状況

WCN6750 WiFiチップはath11kドライバで `supports_monitor = false` が設定されています。これはカーネルソースの `drivers/net/wireless/ath/ath11k/core.c` で確認できます:

```c
/* wcn6750 hw1.0 */
.supports_monitor = false,
```

これは**ファームウェア制限**です — WCN6750のファームウェアはモニターモードHALインターフェースを実装していません。WCN7850 (ath12k) とは異なり、有効化するためのアップストリームパッチは存在しません。

### なぜフラグを切り替えるだけではダメなのか?

アップストリームパッチが完全なモニターモード実装を提供するWCN7850とは異なり、WCN6750の制限はより深いレベルにあります:

- ファームウェアがモニターモードリングディスクリプタを公開していない
- モニターモード用のHAL (Hardware Abstraction Layer) インターフェースがファームウェアに実装されていない
- `supports_monitor = true` に切り替えると、ファームウェアが理解できないモニターリングをドライバが初期化しようとし、クラッシュを引き起こす

### モニターモードなしでも使える機能

**内蔵WiFiのモニターモードは不可能です。** しかし、NetHunter Proは依然として非常に有用です:

| 機能 | 状態 | 詳細 |
|---------|:------:|---------|
| USB HID攻撃 (DuckyScript) | ✅ | 完全なキーボード/マウスエミュレーション |
| USB RNDISネットワーキング | ✅ | USBケーブル経由のネットワーク |
| Kali chroot (Metasploit, Nmap等) | ✅ | フルKali Linuxツールセット |
| NetHunter KeX (デスクトップ) | ✅ | VNC経由のフルデスクトップ |
| 外部USB WiFi (モニター + インジェクション) | ✅ | USB OTGアダプター経由 |
| Bluetooth攻撃 (Ubertooth) | ✅ | Ubertooth USBハードウェア経由 |
| 内蔵WiFi (マネージドモード) | ✅ | 通常のWiFiは問題なく動作 |

## 1. ビルド環境

### ホスト要件

- Ubuntu 22.04以上 (x86_64)
- ディスク空き容量 120GB以上
- RAM 16GB以上 (並列ビルドには32GB推奨)

### 依存パッケージ

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves bazel
```

### ソースの取得

```bash
mkdir nothing-3a-kernel && cd nothing-3a-kernel

git clone -b sm7635/b/mr --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635.git kernel

# AOSP Clang r487747c
# Nothing-Kaliリポジトリをクローン済みの場合:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r487747c
# 手動の場合:
mkdir -p prebuilts/clang/host/linux-x86
# https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/ からダウンロード
```

## 2. カーネル設定

### Defconfig

Phone (3a) はQualcomm `pineapple` プラットフォームを使用します。defconfigはレイヤーから構成されます:

```
gki_defconfig                              # GKIベース
  + vendor/pineapple_GKI.config            # Qualcomm pineappleプラットフォーム設定
  + vendor/Asteroids.config                # Nothing Phone (3a) デバイス設定
```

Kleaf/Bazelでは、ビルドシステムが自動的に構成します。レガシー `make` ビルドの場合:

```bash
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/pineapple_GKI.config \
  arch/arm64/configs/vendor/Asteroids.config
```

> **Phone (3a) Pro** は代わりに `AsteroidsPro.config` を使用します。正確な名前は `arch/arm64/configs/vendor/` を確認してください。

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

## 3. カーネルビルド

### Kleaf/Bazel使用 (推奨)

```bash
cd kernel

# pineapple (SM7635) プラットフォーム、gkiバリアントでビルド
python3 build_with_bazel.py -t pineapple gki
```

出力は `out/msm-kernel-pineapple-gki/dist/` に生成されます。

### レガシーmake使用 (フォールバック)

```bash
cd kernel

export ROOT_DIR=$(pwd)/..
export LLVM=1
export ARCH=arm64
export CLANG_PREBUILT_BIN=${ROOT_DIR}/prebuilts/clang/host/linux-x86/clang-r487747c/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# defconfigの構成
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/pineapple_GKI.config \
  arch/arm64/configs/vendor/Asteroids.config

# NetHunter設定の有効化
./scripts/enable-nethunter-configs.sh . out

# ビルド
make O=out -j$(nproc)
```

### ビルド出力の検証

```bash
# 出力ファイルの確認
ls -la out/dist/init_boot.img 2>/dev/null || ls -la out/arch/arm64/boot/Image*

# USB ConfigFSが設定に含まれているか確認
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config
# 期待値: CONFIG_USB_CONFIGFS_F_HID=y

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
# カーネルバージョンが変わったか確認
adb shell uname -r

# USB ConfigFSが利用可能か確認
adb shell su -c "ls /config/usb_gadget/"

# WiFiが動作しているか確認 (マネージドモード)
adb shell su -c "iw dev wlan0 info"
```

## 6. NetHunter Proのインストール

[NetHunter Proインストール](nethunter-install.md) を参照。

## 7. 外部WiFiアダプター (WiFi攻撃に必須)

内蔵WiFiはモニターモードに対応していないため、無線ペネトレーションテストには外部USBアダプターが必須です。

### rtl8812auドライバのビルド

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

出力: `88XXau.ko`

### ロードとテスト

```bash
# USB OTG経由でアダプターを接続後:
adb push 88XXau.ko /sdcard/
adb shell su -c "insmod /sdcard/88XXau.ko"
adb shell su -c "ip link"        # wlan1を確認
adb shell su -c "iw dev wlan1 set type monitor"
adb shell su -c "ip link set wlan1 up"
adb shell su -c "iw dev wlan1 info"   # type: monitorと表示されるはず
```

### 推奨USB WiFiアダプター

| アダプター | チップセット | ドライバ | モニター + インジェクション | 備考 |
|---------|---------|--------|:---:|-------|
| Alfa AWUS036ACH | RTL8812AU | rtl8812au | ✅ | デュアルバンド、高出力に最適 |
| Alfa AWUS036ACHM | RTL8812AU | rtl8812au | ✅ | より小型のフォームファクター |
| Alfa AWUS036ACM | MT7612U | mt76 | ✅ | 良好なカーネルサポート |
| Panda PAU09 | RT5572 | rt2800usb | ✅ | 低予算向けオプション |

詳細なセットアップと比較については [外部WiFiアダプター](external-wifi.md) を参照。
