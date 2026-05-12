# Kernel Build Overview — What You're Actually Doing

## NetHunter Proとは何をしているのか

NetHunter Proは **Androidを置き換えない**。ストックのAndroidカーネルソースをベースに、ペネトレーションテストに必要な機能を **追加** してリビルドするだけ。

### 変わるもの / 変わらないもの

| | 変わらない (Stock通り) | 追加される |
|---|---|---|
| **通話/SMS** | ✅ そのまま | — |
| **WiFi (通常接続)** | ✅ そのまま | モニターモード (切替時のみ) |
| **Bluetooth** | ✅ そのまま | — |
| **カメラ** | ✅ そのまま | — |
| **アプリ** | ✅ そのまま | NetHunter app + Kali chroot |
| **指紋認証** | ✅ そのまま | — |
| **USB充電** | ✅ そのまま | USB HID (keyboard/mouse emulation) |
| **OTAアップデート** | ❌ 動かなくなる | — |

**OTAアップデート** はカスタムカーネルを入れると失敗するが、[Nothing Archiveのガイド](https://spike0en.github.io/nothing_archive/docs/guides#ota-sideloading)に従ってストックイメージを復元すれば再度アップデート可能。

### 技術的に何をやっているか

```
┌─────────────────────────────────────────────────┐
│                 Android OS (Nothing OS)          │
│   (アプリ、UI、電話、カメラ — すべてそのまま)      │
├─────────────────────────────────────────────────┤
│   Kali chroot (/data/local/nhsystem/)           │  ← NetHunterが追加
│   (Metasploit, Nmap, aircrack-ng, etc.)         │
├─────────────────────────────────────────────────┤
│              Android Kernel (カスタム)            │
│  ┌─────────────────────────────────────────────┐│
│  │ ストック機能 (そのまま)                       ││
│  │ + CONFIG_USB_CONFIGFS_F_HID (USB HID攻撃)  ││  ← 追加
│  │ + CONFIG_SNIFFER_RADIOTAP (WiFiモニター)    ││  ← 追加 (Phone 2aの場合)
│  │ + ath12k monitor mode patches               ││  ← 追加 (Phone 3/4a Proの場合)
│  └─────────────────────────────────────────────┘│
├─────────────────────────────────────────────────┤
│                Hardware                          │
└─────────────────────────────────────────────────┘
```

WiFiの動作:
- **普段:** `managed` mode → 普通にWiFi接続、ブラウジング、アプリ通信
- **ペンテスト時:** `monitor` mode に手動切替 → パケットキャプチャ、deauth等
- **戻す:** `managed` mode に切り替えれば元通り

## カーネルビルドが難しい理由と対処法

### 1. ツールチェーン

**問題:** 正しいコンパイラバージョンを使わないとビルドが通らないか、通っても起動しない。

**対処:** NothingOSSの `build.config.constants` に正確なバージョンが記載されている。そこに書いてあるものを使う。

| デバイス | Clang Version | 取得元 |
|---------|---------------|--------|
| Phone (2a) | `r450784e` | [AOSP clang prebuilts](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/) |
| Phone (3a/4a) | `r487747c` | 同上 |
| Phone (3/4a Pro) | `r510928` | 同上 |

```bash
# 例: r510928 をダウンロード
mkdir -p prebuilts/clang/host/linux-x86
cd prebuilts/clang/host/linux-x86
wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r510928.tar.gz
mkdir clang-r510928 && tar xzf clang-r510928.tar.gz -C clang-r510928
```

> clangプリビルトの正確なダウンロード方法はバージョンにより異なる。tarballが見つからない場合は `repo init` で Android kernel manifest ごと取得する方法が確実:
>
> ```bash
> repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6
> repo sync -c --no-tags
> ```

### 2. defconfig が見つからない

**問題:** `arch/arm64/configs/` に何があるかわからない。

**対処:**

```bash
ls arch/arm64/configs/ | grep -i -E 'nothing|vendor|gki'
```

GKIカーネルの場合、`gki_defconfig` をベースに vendor fragment を重ねる構成が多い:

```bash
# ベース + vendor fragment
make O=out gki_defconfig vendor/nothing_defconfig
```

見つからない場合、現在のデバイスから抽出:

```bash
adb shell su -c "cat /proc/config.gz" | gunzip > running_config
cp running_config arch/arm64/configs/extracted_defconfig
make O=out extracted_defconfig
```

### 3. Kleaf/Bazel vs build.sh

NothingOSSカーネルはKleaf (Bazel) ベースのビルドシステムを使用。

**Bazelが動く場合 (推奨):**

```bash
tools/bazel run //common:kernel_aarch64_dist
```

**Bazelが動かない場合 (レガシー):**

```bash
export LLVM=1
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_PREBUILT_BIN=$(pwd)/../prebuilts/clang/host/linux-x86/clang-rXXXXXX/bin
export PATH=${CLANG_PREBUILT_BIN}:${PATH}

# defconfig
make O=out <device_defconfig>

# ConfigFS を有効化
./scripts/config --file out/.config \
  -e USB_CONFIGFS \
  -e USB_CONFIGFS_SERIAL \
  -e USB_CONFIGFS_ACM \
  -e USB_CONFIGFS_RNDIS \
  -e USB_CONFIGFS_EEM \
  -e USB_CONFIGFS_ECM \
  -e USB_CONFIGFS_NCM \
  -e USB_CONFIGFS_MASS_STORAGE \
  -e USB_CONFIGFS_F_HID

# ビルド
make O=out -j$(nproc)
```

### 4. ビルドエラーの対処

**よくあるエラーと対処:**

| エラー | 原因 | 対処 |
|--------|------|------|
| `clang: not found` | PATHにclangが通っていない | `export PATH=...clang-rXXX/bin:$PATH` |
| `incompatible pointer type` | clangバージョン不一致 | `build.config.constants` の正確なバージョンを使う |
| `CONFIG_LTO_CLANG: unmet dependency` | LTO設定不足 | `CONFIG_LTO_CLANG_THIN=y` を設定 |
| `KMI symbol ... not exported` | KMI違反 | `CONFIG_TRIM_UNUSED_KSYMS=n` にする |
| `depmod: FATAL: Module ... not found` | モジュールパスの不整合 | `make O=out INSTALL_MOD_PATH=... modules_install` |

### 5. ビルド出力物と何をフラッシュするか

```
out/
├── arch/arm64/boot/
│   ├── Image              # カーネルイメージ
│   ├── Image.lz4          # lz4圧縮版
│   └── dts/               # デバイスツリー
├── init_boot.img          # ← これをフラッシュ (多くのデバイス)
├── boot.img               # ← 一部のデバイスではこっち
└── *.ko                   # カーネルモジュール
```

**何をフラッシュするか:**

| デバイス | フラッシュ対象 | コマンド |
|---------|-------------|---------|
| Phone (2a) | `init_boot` | `fastboot flash init_boot init_boot.img` |
| Phone (3a/4a) | `init_boot` | `fastboot flash init_boot init_boot.img` |
| Phone (3) | `init_boot` or `boot` | デバイスのパーティションレイアウトを確認 |
| Phone (4a) Pro | `init_boot` or `boot` | 同上 |

### 6. 失敗しても復旧できる

カスタムカーネルで起動しなくなっても:

1. **fastbootは生きている** — 電源 + 音量下でbootloaderモードに入れる
2. [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) からストックブートイメージをダウンロード
3. `fastboot flash init_boot stock_init_boot.img` でストックに戻す
4. 再起動 → 元通り

**ブリックのリスクは極めて低い** — カーネルを入れ替えるだけで、パーティションテーブルやベースバンドには触れないため。
