# Phone (3) — NetHunter Pro カーネルビルド

| | |
|---|---|
| **コードネーム** | Metroid |
| **SoC** | Qualcomm Snapdragon 8s Gen 4 (SM8735) |
| **アーキテクチャ** | arm64 |
| **WiFiチップ** | WCN7850 (FastConnect 7800, Wi-Fi 7) |
| **WiFiドライバ** | ath12k |
| **カーネル** | Linux 6.6 (`android15-6.6`) |
| **ツールチェイン** | AOSP Clang `r510928` (`LLVM=1`) |
| **ビルドシステム** | Kleaf / Bazel |
| **モニターモード** | 🔧 パッチ適用可能 — アップストリームath12kがWCN7850サポートを追加 (2025年4月) |

> **内蔵WiFiペンテストに最適なデバイス** — WCN7850はアップストリームLinuxで十分にメンテナンスされた最新のWi-Fi 7チップです。Phone (4a) Proも同じWiFiチップとドライバを共有しています。

## ソース

| リポジトリ | ブランチ |
|------|--------|
| [Kernel](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735) | `sm8735/b/mr` |

## 1. ビルド環境

### ホスト要件

- Ubuntu 22.04以上 (x86_64)
- ディスク空き容量 150GB以上 (QualcommカーネルツリーはMediaTekより大きい)
- RAM 16GB以上 (32GB推奨)

### 依存パッケージ

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves

# Bazel (Kleaf用)
sudo apt install -y bazel
```

### ソースの取得

```bash
mkdir nothing-3-kernel && cd nothing-3-kernel

git clone -b sm8735/b/mr --depth=1 \
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735.git kernel

# AOSP Clang r510928
# Nothing-Kaliリポジトリをクローン済みの場合:
#   path/to/Nothing-Kali/scripts/setup-clang.sh r510928
# 手動の場合:
mkdir -p prebuilts/clang/host/linux-x86
# https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/ からr510928をダウンロード
# またはAndroid CIビルドアーティファクトから取得
```

### なぜAOSP Clangなのか?

カーネル設定は `LLVM=1` と `CLANG_VERSION=r510928` を指定しています。これはAndroid NDK clangとは**異なります**:

- **NDK clang** はAndroidユーザースペースを対象としています (Bionic libc、Android sysrootにリンク)。NDK clangでカーネルをコンパイルすると、失敗するか微妙に壊れたバイナリが生成されます。
- **AOSPプリビルトclang** はカーネルビルド用に設定されたベアメタルコンパイラであり、Nothing/Qualcommがストックカーネルのビルドとテストに使用したものと一致します。
- GKI (Generic Kernel Image) カーネルはKMIシンボルチェックを強制します — 異なるコンパイラを使用するとKMI互換性が壊れ、ベンダーモジュールのロードが不可能になる場合があります。

## 2. カーネル設定

### Defconfig

Phone (3) はQualcomm `sun` プラットフォームを使用します。defconfigはレイヤーから構成されます:

```
gki_defconfig                          # GKIベース (arch/arm64/configs/ 内)
  + vendor/sun_perf.config             # Qualcomm sunプラットフォーム設定
  + vendor/Metroid.config              # Nothing Phone (3) デバイス設定
```

Kleaf/Bazel (推奨) では、正しいターゲット (`sun`) とバリアント (`perf`) を指定すると、ビルドシステムが自動的にdefconfigを構成します。

レガシー `make` ビルドの場合、手動で構成します:

```bash
# GKIベースから開始
make O=out gki_defconfig

# ベンダーフラグメントをマージ
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/sun_perf.config \
  arch/arm64/configs/vendor/Metroid.config
```

### USB ConfigFS (NetHunter HIDガジェット)

defconfigの読み込み後、USB ConfigFSを有効化します:

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

またはヘルパースクリプトを使用:

```bash
./scripts/enable-nethunter-configs.sh . out
```

## 3. WCN7850モニターモードの有効化

ストックのNothingOSSカーネルでは、`drivers/net/wireless/ath/ath12k/hw.c` 内のWCN7850に対して `supports_monitor = false` が設定されています。アップストリームLinuxは2025年4月に完全なモニターモードサポートを追加しました。

### 必要な変更の概要

モニターモードの有効化には2つのことが必要です:
1. hw_paramsの `supports_monitor` フラグを切り替える
2. 実際のモニターモードデータパスを追加する13パッチの実装シリーズをバックポートする

> **警告:** フラグの切り替えだけ (パッチなし) では、モニターモードに入ろうとした際にクラッシュまたはサイレント障害が発生します。両方のステップが必要です。

### ステップA: hw_paramsフラグの切り替え

`drivers/net/wireless/ath/ath12k/hw.c` を編集し、WCN7850のhw_paramsを見つけます:

```diff
 		.interface_modes = BIT(NL80211_IFTYPE_STATION) |
 				   BIT(NL80211_IFTYPE_AP),
-		.supports_monitor = false,
+		.supports_monitor = true,
```

### ステップB: 13パッチのモニターモードシリーズをバックポート

**パッチソース:** [\[PATCH ath-next 00/13\] wifi: ath12k: add monitor mode support for WCN7850](http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html)

シリーズの内容:

| # | パッチ | 目的 |
|---|-------|---------|
| 01 | configure mon ring | モニターステータス用リング設定 |
| 02 | mon ring interrupt | モニターリングの割り込み設定 |
| 03 | reap mon dest ring | モニター宛先リングの処理 |
| 04 | reap mon status ring | モニターステータスリングの処理 |
| 05 | mon mode handler | メインモニターモードハンドラ |
| 06 | init mon params | モニターパラメータの初期化 |
| 07 | mon ring offsets WCN7850 | WCN7850固有のリングオフセット |
| 08 | pkt offset WCN7850 | パケットオフセット処理 |
| 09 | dp_mon WCN7850 init | データパスモニター初期化 |
| 10 | radiotap construction | HW TLVからradiotapヘッダを構築 |
| 11 | NL80211 monitor iface | モニターインターフェースタイプの登録 |
| 12 | supports_monitor = true | フラグの切り替え (ステップAで完了済み) |
| 13 | cleanup / test | テストと検証 |

### メーリングリストからパッチをダウンロード

```bash
cd kernel
mkdir -p patches/monitor-mode

# メーリングリストアーカイブから各パッチをダウンロード
# パッチはカバーレターからリンクされています:
# http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html
#
# 各フォローアップメッセージ (01/13 から 13/13) にパッチが含まれています。
# 以下のように保存してください:
#   patches/monitor-mode/0001-configure-mon-ring.patch
#   patches/monitor-mode/0002-mon-ring-interrupt.patch
#   ...
#   patches/monitor-mode/0013-cleanup-test.patch
```

> **ヒント:** `b4` ツールを使用してシリーズ全体をダウンロードできます:
> ```bash
> pip install b4
> b4 am http://lists.infradead.org/pipermail/ath12k/2025-April/006757.html -o patches/monitor-mode/
> ```

### パッチの適用

```bash
cd kernel

# すべてのパッチを順番に適用
for p in patches/monitor-mode/00*.patch; do
  echo "Applying: $p"
  git am "$p"
  if [ $? -ne 0 ]; then
    echo "CONFLICT in $p — resolve manually"
    echo "After resolving: git am --continue"
    echo "To skip this patch: git am --skip"
    echo "To abort all: git am --abort"
    break
  fi
done
```

### パッチコンフリクトの解決

NothingOSSカーネルにはアップストリームath12kコードの上にQualcommベンダーパッチがあるため、コンフリクトが発生する可能性があります。一般的なコンフリクト箇所:

| ファイル | 典型的なコンフリクト | 解決方法 |
|------|-----------------|------------|
| `dp_mon.c` | 関数シグネチャの変更 | Qualcommバージョンを維持し、新しいモニター関数を追加 |
| `hw.c` | hw_params構造体のレイアウト | Qualcommの追加とモニターフィールドの両方をマージ |
| `hal.c` | リングディスクリプタ定義 | 既存のものと並行して新しいモニターリング定義を追加 |
| `core.h` | 構造体メンバーの追加 | モニター関連メンバーを構造体に追加 |
| `dp.h` | データパス構造体の変更 | Qualcommとモニターの両方の追加をマージ |

一般的なコンフリクト解決戦略:

```bash
# コンフリクト発生時:
git status                          # コンフリクトしているファイルを確認
vim <conflicted-file>               # エディタで開く

# コンフリクトマーカーを探す:
# <<<<<<< HEAD        (NothingOSS/Qualcommバージョン)
# =======
# >>>>>>> patch        (アップストリームパッチバージョン)

# 通常: Qualcomm固有のコードを維持しつつ、新しいモニターコードを追加する
# アップストリームパッチは新しい関数を追加するため、ベンダーコードと共存可能

git add <resolved-file>
git am --continue
```

### パッチシリーズの理解

各パッチの内容を理解したい方向け:

**パッチ01–04 (リングセットアップ):** WiFiチップがキャプチャしたパケットを配信するために使用するハードウェアディスクリプタリングを設定します。WCN7850には初期化が必要な専用モニターモードリングがあります。

**パッチ05–06 (ハンドラ/パラメータ):** モニターリングからのパケットを処理するソフトウェアハンドラを設定し、チャネル、帯域幅などのパラメータを初期化します。

**パッチ07–09 (WCN7850固有):** WCN7850ハードウェア固有のリングオフセットとデータパス初期化。これらの値はチップのデータシートから取得されています。

**パッチ10 (Radiotap):** キャプチャされたフレームからのハードウェア固有のTLV (Type-Length-Value) メタデータを、Wireshark/tcpdumpが理解できる標準radiotapヘッダに変換します。

**パッチ11–13 (インターフェース/フラグ/クリーンアップ):** nl80211 (Linux WiFi設定API) にモニターインターフェースタイプを登録し、`supports_monitor` フラグを切り替え、クリーンアップを行います。

### ファームウェア互換性

パッチはファームウェア `WLAN.HMT.1.0.c5-00481-QCAHMTSWPL_V1.0_V2.0_SILICONZ-3` で検証されています。デバイスのファームウェアを確認してください:

```bash
adb shell ls /vendor/firmware/ath12k/WCN7850/hw2.0/
```

ファームウェアバージョンが大幅に異なる場合、モニターモードが動作しないか、ファームウェアのアップデートが必要になる場合があります。ファームウェアファイル:

| ファイル | 目的 |
|------|---------|
| `amss.bin` | メインWiFiファームウェア |
| `m3.bin` | M3ファームウェア |
| `board-2.bin` | ボードデータファイル |
| `regdb.bin` | 規制データベース |

> **注意:** WCN7850のファームウェアアップデートは通常Nothing OS OTAアップデートで配信されます。より新しいファームウェアが必要な場合は、[Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) 経由でより新しいNothing OSビルドから抽出する必要があるかもしれません。

## 4. カーネルビルド

### Kleaf/Bazel使用 (推奨)

```bash
cd kernel

# sun (SM8735) プラットフォーム、perfバリアントでビルド
python3 build_with_bazel.py -t sun perf
```

出力は `out/msm-kernel-sun-perf/dist/` に生成されます。`init_boot.img` または `boot.img` を探してください。

### レガシーmake使用 (フォールバック)

Bazelが動作しない場合:

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
  arch/arm64/configs/vendor/Metroid.config

# NetHunter設定の有効化
./scripts/enable-nethunter-configs.sh . out

# ビルド
make O=out -j$(nproc)
```

### レガシーmakeからinit_boot.imgを生成

Bazelではなく `make` でビルドした場合、ビルドシステムが自動的に `init_boot.img` を生成しないことがあります。`mkbootimg` が必要です:

```bash
# mkbootimgのインストール (Android platform toolsまたはbuild toolsから)
pip install mkbootimg
# またはクローン: git clone https://android.googlesource.com/platform/system/tools/mkbootimg

# init_boot.imgの作成
mkbootimg \
  --header_version 4 \
  --kernel out/arch/arm64/boot/Image.lz4 \
  --output out/init_boot.img

# あるいは、ストックinit_bootをテンプレートとして使用:
# ストックinit_bootを展開、カーネルを置き換え、再パック
unpack_bootimg --boot_img stock_init_boot.img --out stock_parts/
mkbootimg \
  --header_version 4 \
  --kernel out/arch/arm64/boot/Image.lz4 \
  --ramdisk stock_parts/ramdisk \
  --output out/init_boot.img
```

> **注意:** GKI init_bootのフォーマットはデバイスによって異なります。不明な場合は、ストックイメージに対して `unpack_bootimg` を使用して正確なフォーマットを確認し、カスタムカーネルで再パックしてください。

### Qualcomm固有のビルドノート

| トピック | 詳細 |
|-------|--------|
| ビルド時間 | 8コアで約30分、16コアで約15分 |
| `vendor_boot.img` | `init_boot.img` と一緒に生成される場合がある — カーネルのみの変更では通常不要 |
| デバイスツリー | QualcommのDTSファイルは `arch/arm64/boot/dts/qcom/` にある |
| `dtbo.img` | デバイスツリーオーバーレイイメージ — デバイスツリーオーバーレイを変更した場合のみフラッシュ |

## 5. フラッシュ

```bash
# まずバックアップ (一度だけ)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img

# ブートローダーに再起動
adb reboot bootloader

# GKIデバイスはbootまたはinit_bootを使用する場合がある — デバイスのパーティションレイアウトを確認
fastboot flash init_boot out/dist/init_boot.img
# または: fastboot flash boot out/dist/boot.img

fastboot reboot
```

### bootとinit_bootの判別方法

```bash
adb shell su -c "ls /dev/block/by-name/ | grep -E 'boot|init_boot'"
# init_boot_a が存在すれば → init_bootを使用
# boot_a のみ存在すれば → bootを使用
```

## 6. モニターモードの検証

```bash
adb shell su -c "ip link set wlan0 down"
adb shell su -c "iw dev wlan0 set type monitor"
adb shell su -c "ip link set wlan0 up"
adb shell su -c "iw dev wlan0 info"
# 表示されるべき: type monitor
```

`iw dev wlan0 set type monitor` コマンドが失敗する場合:

```bash
# カーネルログでエラーを確認
adb shell su -c "dmesg | grep -i ath12k | tail -30"

# サポートされるインターフェースモードにモニターモードが含まれているか確認
adb shell su -c "iw phy phy0 info | grep -A 10 'Supported interface modes'"
# リストに "monitor" が含まれているはず

# rfkillを確認
adb shell su -c "rfkill list"
```

### キャプチャテスト

```bash
# 簡易パケットキャプチャ
adb shell su -c "tcpdump -i wlan0 -c 50 -w /sdcard/test_capture.pcap"
adb pull /sdcard/test_capture.pcap

# PCのWiresharkで開いて802.11フレームがキャプチャされていることを確認

# またはairodump-ngでAP探索
adb shell
su
nethunter
airodump-ng wlan0
```

## 7. NetHunter Proのインストール

[NetHunter Proインストール](nethunter-install.md) を参照。

## 8. 外部WiFiアダプター (オプション)

内蔵WiFiのモニターモードが有効でも、パケットインジェクションはファームウェアにより制限される場合があります。WCN7850のモニターモードはフレーム受信 (RX) を確実にキャプチャしますが、フレームインジェクション (モニターモードでのTX) はファームウェアのサポートに依存しており、不完全な場合があります。

信頼性の高いインジェクションには、rtl8812auをクロスコンパイルしてください:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

make ARCH=arm64 LLVM=1 \
  KSRC=../kernel/out \
  modules
```

推奨アダプターと使用方法については [外部WiFiアダプター](external-wifi.md) を参照。
