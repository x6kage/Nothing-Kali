# カーネルビルド概要 — 実際に何をしているのか

> このガイドでは、カスタムNetHunterカーネルのビルドに関するコンセプトを説明します。デバイス固有のガイドに進む前にお読みください。

## NetHunter Proとは何をしているのか

NetHunter ProはAndroidを**置き換えない**。ストックのAndroidカーネルソースをベースに、ペネトレーションテストに必要な機能を**追加**してリビルドするだけである。スマートフォンとしての機能はそのまま維持され、追加の機能が得られる。

### 変わるもの・変わらないもの

| | 変更なし（ストック） | NetHunterで追加 |
|---|---|---|
| **通話/SMS** | ✅ 通常通り動作 | — |
| **WiFi（通常）** | ✅ 通常通り動作 | モニターモード（手動切替） |
| **Bluetooth** | ✅ 通常通り動作 | — |
| **カメラ** | ✅ 通常通り動作 | — |
| **アプリ** | ✅ 通常通り動作 | NetHunterアプリ + Kali chroot |
| **指紋認証** | ✅ 通常通り動作 | — |
| **NFC** | ✅ 通常通り動作 | — |
| **USB充電** | ✅ 通常通り動作 | USB HID（キーボード/マウスエミュレーション） |
| **OTAアップデート** | ❌ 失敗する | — |
| **SafetyNet/Play Integrity** | ⚠️ 失敗する可能性あり | — |

**OTAアップデート**はカスタムカーネルをフラッシュした後に失敗する。アップデートするには、[Nothing Archive](https://spike0en.github.io/nothing_archive/docs/guides#ota-sideloading)経由でストックカーネルを復元し、OTAを適用してから、カスタムカーネルを再フラッシュする。

**SafetyNet/Play Integrity**はroot化の方法によって失敗する可能性がある。MagiskのZygisk + DenyListでほとんどのアプリからrootを隠せる。KernelSUはデフォルトで検出されにくい。

### アーキテクチャ図

```
┌─────────────────────────────────────────────────────┐
│                  Android OS (Nothing OS)              │
│    (Apps, UI, Phone, Camera — all unchanged)          │
├─────────────────────────────────────────────────────┤
│    Kali chroot (/data/local/nhsystem/)               │  ← NetHunterで追加
│    (Metasploit, Nmap, aircrack-ng, Burp, etc.)       │
├─────────────────────────────────────────────────────┤
│               Android Kernel (Custom Build)           │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Stock functionality (unchanged)                  │ │
│  │ + CONFIG_USB_CONFIGFS_F_HID  (USB HID attacks)  │ │  ← 追加
│  │ + CONFIG_SNIFFER_RADIOTAP    (Phone 2a WiFi)    │ │  ← 追加（デバイス固有）
│  │ + ath12k monitor mode patches (Phone 3/4a Pro)  │ │  ← 追加（デバイス固有）
│  │ + CONFIG_USB_CONFIGFS_RNDIS  (USB networking)   │ │  ← 追加
│  └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│    Firmware (WiFi FW, modem, DSP — NOT modified)     │
├─────────────────────────────────────────────────────┤
│                     Hardware                          │
└─────────────────────────────────────────────────────┘
```

### WiFiモード切替の仕組み

カーネルがモニターモードをサポートしている場合、WiFiは2つの状態で動作する：

- **通常（managedモード）：** WiFiはアクセスポイントに接続し、インターネットを閲覧し、アプリを実行する — ストックと同じ動作。
- **モニターモード：** インターフェースをダウンし、モニターモードに切り替え、再度アップする。この状態では、WiFiチップは範囲内のすべての802.11フレーム（自分のデバイス宛でないフレームを含む）をキャプチャする。
- **切り戻し：** インターフェースをmanagedモードに戻して再接続する。再起動は不要。

```bash
# モニターモードに切り替え
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up

# 確認
iw dev wlan0 info    # type should show "monitor"

# managedモードに戻す
ip link set wlan0 down
iw dev wlan0 set type managed
ip link set wlan0 up
```

> **重要：** モニターモード中は通常のWiFi接続は利用できない。完了したらmanagedモードに戻すこと。

## GKI（Generic Kernel Image）の理解

最新のAndroidデバイス（カーネル5.10以降）は、Googleの**GKIアーキテクチャ**を使用しており、カーネルを以下のように分離している：

```
┌──────────────────────────┐
│     GKI Kernel Image     │  ← 汎用、Google/AOSPから提供
│  (core kernel + drivers) │
├──────────────────────────┤
│   Vendor Kernel Modules  │  ← デバイス固有（Qualcomm/MediaTek/Nothing）
│    (.ko files in /vendor │
│     /lib/modules/)       │
└──────────────────────────┘
```

### GKIがNetHunterビルドに重要な理由

1. **KMI（Kernel Module Interface）：** GKIはカーネルとベンダーモジュール間の安定したインターフェースを強制する。カーネルビルドがKMIシンボルを変更すると、ベンダーモジュール（WiFi、カメラなど）がロードされなくなる。
2. **コンパイラが重要：** ベンダーが使用したものと異なるコンパイラバージョンを使用すると、KMIが暗黙的に破壊される可能性がある。カーネルソースで指定された正確なAOSP clangバージョンを必ず使用すること。
3. **`init_boot` vs `boot`：** GKIデバイスは通常、カーネルを `boot.img` ではなく `init_boot.img` に配置する。フラッシュ前にデバイスのパーティションレイアウトを確認すること。

### ビルドがKMIを破壊するかの確認方法

```bash
# ビルド後、KMI違反を確認
grep "KMI" out/build.log

# シンボルの比較
nm -D out/vmlinux | grep "T " | sort > built_symbols.txt
# ストックカーネルのシンボルが利用可能な場合、比較する
```

## カーネルビルドが失敗する原因（と修正方法）

### 1. ツールチェーン

**問題：** 誤ったコンパイラバージョンを使用すると、ビルドの失敗や起動しないカーネルが生成される。

**修正：** 各NothingOSSカーネルリポジトリの `build.config.constants` ファイルに、正確なAOSP clangバージョンが記載されている。そのバージョンのみを使用すること。

| デバイス | Clangバージョン | Androidブランチ |
|---------|---------------|---------------|
| Phone (2a) | `r450784e` | `android13-5.15` |
| Phone (3a/4a) | `r487747c` | `android14-6.1` |
| Phone (3/4a Pro) | `r510928` | `android15-6.6` |

提供されたスクリプトを使用してダウンロード：

```bash
./scripts/setup-clang.sh r510928   # Downloads to prebuilts/clang/host/linux-x86/
```

または手動でダウンロード：

```bash
mkdir -p prebuilts/clang/host/linux-x86
cd prebuilts/clang/host/linux-x86
wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r510928.tar.gz
mkdir clang-r510928 && tar xzf clang-r510928.tar.gz -C clang-r510928
```

> tarballのURLが機能しない場合（AOSPはプリビルトのホスティングを定期的に再構成する）、Androidカーネルマニフェストで `repo init` を使用する：
>
> ```bash
> repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6
> repo sync -c --no-tags
> ```

#### なぜAOSP Clangで、NDKやGCCではないのか？

| コンパイラ | 用途 | カーネルビルドに使えるか？ |
|----------|---------|:-:|
| **AOSP Clang**（プリビルト） | カーネルビルド | ✅ 正しい選択 |
| **Android NDK Clang** | ユーザースペースのアプリ/ライブラリ | ❌ sysrootもフラグも異なる |
| **システムGCC** (`gcc`) | 一般的なLinux | ⚠️ 動作する可能性はあるがKMI破壊のリスクあり |
| **システムClang** (`apt install clang`) | 一般的な開発 | ⚠️ バージョン不一致、LTO非互換 |

NDKにはユーザースペース向けに設定されたclangが同梱されている（Bionic libcにリンク、Androidのsysroot付き）。これをカーネルビルドに使用すると、壊れたバイナリが生成される。システムGCCは技術的にはカーネルをコンパイルできるが、GKIカーネルは特定のAOSP clangバージョンでテストされている — 他のものを使用するとABI/KMIの不一致が発生し、ベンダーモジュールが暗黙的に失敗するリスクがある。

### 2. defconfigの特定

**問題：** どのdefconfigファイルを使用すればよいか分からない。

**修正：** GKIカーネルは `gki_defconfig` をベースとし、その上に**ベンダーコンフィグフラグメント**を重ねる。正確なフラグメントはデバイスによって異なる：

| デバイス | ベース | プラットフォームフラグメント | デバイスフラグメント |
|--------|------|-------------------|-----------------|
| Phone (2a) | `gki_defconfig` | （MTK Kleafが処理） | — |
| Phone (3) | `gki_defconfig` | `vendor/sun_perf.config` | `vendor/Metroid.config` |
| Phone (3a) | `gki_defconfig` | `vendor/pineapple_GKI.config` | `vendor/Asteroids.config` |
| Phone (4a) | `gki_defconfig` | `vendor/pineapple_GKI.config` | `vendor/Frogger.config` |
| Phone (4a) Pro | `gki_defconfig` | `vendor/sun_perf.config` | `vendor/FroggerPro.config` |

Kleaf/Bazel（推奨）では、ビルドシステムがdefconfigを自動的に組み立てる。レガシーの `make` の場合は手動でマージする：

```bash
# Phone (3)の例：
make O=out gki_defconfig
./scripts/kconfig/merge_config.sh -m -O out \
  out/.config \
  arch/arm64/configs/vendor/sun_perf.config \
  arch/arm64/configs/vendor/Metroid.config
```

ベンダーフラグメントがソースツリーに存在しない場合、デバイスから実行中のconfigを抽出する：

```bash
adb shell su -c "cat /proc/config.gz" | gunzip > running_config
cp running_config arch/arm64/configs/extracted_defconfig
make O=out extracted_defconfig
```

> **ヒント：** 抽出後、`gki_defconfig` とdiffして、Nothingがカスタマイズした箇所を確認する：
> ```bash
> diff <(sort gki_defconfig) <(sort extracted_defconfig) | head -50
> ```

### 3. ビルドシステム：Kleaf/Bazel vs build.sh

NothingOSSカーネルはKleaf（GoogleのBazelベースのビルドシステム）を使用する。従来の `make` ワークフローをヘルメティックビルドでラップしている。

**Bazelが動作する場合（推奨）：**

**MediaTek (Phone 2a)** の場合：
```bash
tools/bazel run //common:kernel_aarch64_dist
```

**Qualcomm (Phone 3, 3a, 4a, 4a Pro)** の場合 — `build_with_bazel.py` を `-t TARGET VARIANT` で使用：
```bash
# Phone (3) / Phone (4a) Pro — "sun" プラットフォーム
python3 build_with_bazel.py -t sun perf

# Phone (3a) / Phone (4a) — "pineapple" プラットフォーム
python3 build_with_bazel.py -t pineapple gki
```

**Bazelが失敗する場合（レガシーフォールバック）：**

```bash
export LLVM=1
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_PREBUILT_BIN=$(pwd)/../prebuilts/clang/host/linux-x86/clang-rXXXXXX/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# defconfigの読み込み
make O=out <device_defconfig>

# NetHunter設定の有効化
../scripts/enable-nethunter-configs.sh . out

# ビルド
make O=out -j$(nproc)
```

### 4. よくあるビルドエラー

| エラー | 原因 | 修正 |
|--------|------|------|
| `clang: not found` | PATHにclangバイナリがない | `export PATH=...clang-rXXX/bin:$PATH` |
| `incompatible pointer type` | Clangバージョンの不一致 | `build.config.constants` に記載された正確なバージョンを使用 |
| `CONFIG_LTO_CLANG: unmet dependency` | LTO設定が不完全 | `CONFIG_LTO_CLANG_THIN=y` と `CONFIG_LTO=y` を設定 |
| `KMI symbol ... not exported` | KMI違反 | `CONFIG_TRIM_UNUSED_KSYMS=n` を設定 |
| `depmod: FATAL: Module ... not found` | モジュールパスの不一致 | `make O=out INSTALL_MOD_PATH=... modules_install` |
| `No rule to make target 'xxx.dtb'` | デバイスツリーソースが見つからない | `arch/arm64/boot/dts/` のベンダー固有サブディレクトリを確認 |
| `error: unused variable` (`-Werror` 使用時) | 厳格な警告フラグ | `-Wno-unused-variable` を追加するかコードを修正 |
| `BTF: .tmp_vmlinux.btf: pahole not found` | `pahole` ツールが未インストール | `sudo apt install dwarves` |
| `openssl/bio.h: No such file` | OpenSSLヘッダーが未インストール | `sudo apt install libssl-dev` |
| `Cannot use CONFIG_CC_STACKPROTECTOR` | コンパイラ/設定の不一致 | AOSP clangがカーネルブランチと一致することを確認 |
| Bazel `WORKSPACE not found` | 作業ディレクトリが間違っている | カーネルルートディレクトリからBazelを実行 |
| `repo: command not found` | `repo` ツールが未インストール | `sudo apt install repo` またはGoogleからインストール |

### 5. ビルド出力とフラッシュ対象

```
out/
├── arch/arm64/boot/
│   ├── Image              # 生カーネルイメージ
│   ├── Image.lz4          # LZ4圧縮カーネルイメージ
│   ├── Image.gz           # Gzip圧縮カーネルイメージ
│   └── dts/               # デバイスツリーblob
│       └── vendor/        # ベンダー固有デバイスツリー
├── init_boot.img          # ← これをフラッシュ（ほとんどのGKIデバイス）
├── boot.img               # ← 一部のデバイスはこちらを使用
├── vendor_boot.img        # ← ベンダーブート（モジュール用に必要な場合あり）
└── *.ko                   # カーネルモジュール
```

**フラッシュ対象：**

| デバイス | 対象パーティション | コマンド |
|---------|-----------------|---------|
| Phone (2a) | `init_boot` | `fastboot flash init_boot init_boot.img` |
| Phone (3a/4a) | `init_boot` | `fastboot flash init_boot init_boot.img` |
| Phone (3) | `init_boot` または `boot` | 先にデバイスのパーティションレイアウトを確認 |
| Phone (4a) Pro | `init_boot` または `boot` | 先にデバイスのパーティションレイアウトを確認 |

デバイスのカーネルがどのパーティションにあるかを確認するには：

```bash
adb shell su -c "ls -la /dev/block/by-name/ | grep -E 'boot|init_boot'"
```

### 6. フラッシュ前のビルド検証

フラッシュする前に、カーネルが正しくビルドされたことを確認する：

```bash
# イメージが存在することを確認
ls -la out/arch/arm64/boot/Image*

# ARM64カーネルであることを確認
file out/arch/arm64/boot/Image
# 期待される出力: "Linux kernel ARM64 boot executable Image"

# 設定が適用されていることを確認
grep "CONFIG_USB_CONFIGFS_F_HID" out/.config
# 期待される出力: CONFIG_USB_CONFIGFS_F_HID=y

# 検証スクリプトを使用
../scripts/verify-kernel.sh out
```

### 7. リカバリ — いつでも元に戻せる

カスタムカーネルが起動しない場合：

1. **Fastbootは常にアクセス可能** — 電源 + 音量ダウンを長押ししてブートローダーモードに入る
2. [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) からストックブートイメージをダウンロード
3. フラッシュ: `fastboot flash init_boot stock_init_boot.img`
4. 再起動 — 元に戻る

**恒久的な文鎮化（ブリック）のリスクは極めて低い。** その理由：

- カーネルイメージのみを置き換える — パーティションテーブルやベースバンドの変更なし
- Fastbootモードはカーネルから独立している — 別パーティションに存在する
- Nothing phoneにはA/Bパーティションスキームがある — スロットAが失敗した場合、ブートローダーがスロットBにフォールバックする可能性がある

### リカバリシナリオ

| シナリオ | 解決策 |
|----------|----------|
| ブートループ（Nothingロゴで停止） | Fastboot → ストックの init_boot をフラッシュ |
| フラッシュ後に画面が真っ暗 | 電源を15秒長押しして強制再起動 → fastboot |
| フラッシュ後にWiFiが動作しない | ベンダーWiFiモジュールの不一致 — ストックをリフラッシュまたはモジュールを再ビルド |
| システムは起動するがランダムにクラッシュ | カーネル設定の問題 — ADB経由で `dmesg` を確認し、修正してリビルド |
| fastbootに入れない | 電源 + 音量ダウンを15秒長押し。それでもダメな場合、バッテリーが完全に消耗するのを待ち、再試行 |

## ビルドワークフローの概要

```
┌─────────────────────────────────────────────────────┐
│ 1. パーティションのバックアップ (persist, nvram,       │
│    boot/init_boot)                                   │
├─────────────────────────────────────────────────────┤
│ 2. カーネルソースのクローン + AOSP clangのダウンロード  │
├─────────────────────────────────────────────────────┤
│ 3. 設定 (defconfig + NetHunter設定)                   │
│    - USB ConfigFSオプション                           │
│    - モニターモードパッチ（デバイス固有）                │
├─────────────────────────────────────────────────────┤
│ 4. ビルド (Kleaf/Bazel or make)                       │
├─────────────────────────────────────────────────────┤
│ 5. 検証 (Image, .config, modulesの確認)               │
├─────────────────────────────────────────────────────┤
│ 6. fastboot経由でフラッシュ                            │
├─────────────────────────────────────────────────────┤
│ 7. NetHunter Proのインストール                        │
├─────────────────────────────────────────────────────┤
│ 8. 検証 (USB HID, WiFiモード, Kali chroot)            │
└─────────────────────────────────────────────────────┘
```

## 次のステップ

- **[デバイス固有ガイド](../../README.md#kernel-build-per-device)** — お使いのスマートフォンのビルド手順に従う
- **[NetHunter Proインストール](nethunter-install.md)** — カスタムカーネルをフラッシュした後にインストール
- **[トラブルシューティング](troubleshooting.md)** — ビルド中またはビルド後に問題が発生した場合
