# macOS 環境セットアップ

macOSからNothing phoneにNetHunter Pro用カスタムカーネルをビルド・フラッシュするためのガイド。

## 概要: 何にmacOSネイティブを使い、何にLinux VMが必要か

| 作業 | macOS単体 | Linux VM / Docker |
|------|:---:|:---:|
| adb / fastboot (フラッシュ) | ✅ | ✅ |
| ブートローダーアンロック | ✅ | ✅ |
| NetHunter Pro zipの転送 | ✅ | ✅ |
| **カーネルビルド** | ❌ | ✅ |
| **カーネルモジュールビルド** | ❌ | ✅ |
| **rtl8812auビルド** | ❌ | ✅ |

カーネルビルドにはLinux x86_64環境が必須 (AOSP clangがLinuxバイナリのため)。macOSではadb/fastbootによるフラッシュとNetHunterインストールが可能。

> **Apple Silicon (M1/M2/M3/M4) の注意:** カーネルビルドのクロスコンパイラはx86_64 Linux向け。Apple Siliconではx86_64 Linux VM (UTM/OrbStack等) またはクラウドビルド環境が必要。

## 1. ADB / Fastboot のインストール

### Homebrew経由 (推奨)

```bash
# Homebrewがなければインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Android Platform Toolsをインストール
brew install android-platform-tools

# 確認
adb version
fastboot --version
```

### 手動インストール

1. [Android SDK Platform Tools for macOS](https://developer.android.com/tools/releases/platform-tools) をダウンロード
2. 展開して任意の場所に配置 (例: `~/Library/Android/platform-tools`)
3. PATHに追加:
   ```bash
   # ~/.zshrc に追加
   export PATH="$HOME/Library/Android/platform-tools:$PATH"
   ```
4. `source ~/.zshrc` で反映

### USB接続の確認

macOSはドライバ不要でadb/fastbootが動作する:

```bash
# デバイスを接続し、USBデバッグを有効にした状態で
adb devices
```

`unauthorized` と出る場合は端末側でUSBデバッグ許可を承認する。

> **USB-C to USB-C ケーブルの注意:** 一部のUSB-Cケーブルはデータ非対応。adbが認識しない場合はUSB-A to USB-Cケーブルを試す。

## 2. カーネルビルド環境

### 方法A: OrbStack (推奨 — Apple Silicon対応)

[OrbStack](https://orbstack.dev/) は軽量なLinux VM + Docker環境。Apple Siliconでもx86_64エミュレーション可能。

```bash
# OrbStackインストール後
orb create ubuntu kernel-build --arch amd64

# VMに入る
orb shell kernel-build

# ビルド環境セットアップ (VM内)
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves
```

> **注意:** `--arch amd64` は必須。AOSP clangプリビルトはx86_64 Linuxバイナリ。ARM64 Linux VMでは動かない。Apple SiliconではRosetta変換により動作するが、ビルド速度は低下する。

### 方法B: UTM (無料)

[UTM](https://mac.getutm.app/) で Ubuntu 22.04 x86_64 VMを作成:

1. UTMをダウンロード・インストール
2. Ubuntu 22.04 Server (amd64) ISOをダウンロード
3. 新規VM作成:
   - **Emulate** (Apple Silicon) または **Virtualize** (Intel Mac)
   - メモリ: 8 GB以上
   - ディスク: 150 GB以上
   - CPU: 4コア以上
4. Ubuntu をインストール後、ビルド依存パッケージをインストール

### 方法C: Docker (ビルドのみ)

```bash
# Docker Desktop for Macをインストール後
docker run -it --platform linux/amd64 \
  -v ~/nothing-kernel:/workspace \
  ubuntu:22.04 bash

# コンテナ内
apt update && apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves
```

> **Docker の制限:** Bazelビルドはメモリとディスクを大量に使う。Docker Desktop のリソース制限を引き上げること (Settings → Resources → メモリ 8GB+, ディスク 150GB+)。

### 方法D: クラウドビルド

ローカルマシンの性能が不足する場合:

- **GitHub Codespaces** — ブラウザからLinux環境でビルド
- **GCP / AWS の一時VM** — e2-standard-8 (8 vCPU, 32GB RAM) で15〜30分でビルド完了
- **Gitpod** — 無料枠でも軽めのビルドは可能

## 3. ビルド成果物の転送

VM/Docker内でビルドした `init_boot.img` をmacOS側に持ってくる:

### OrbStack

```bash
# VM内のファイルはmacOSから直接アクセス可能
# Finder: OrbStack → kernel-build → ファイルブラウザ
# またはターミナルから:
orb push kernel-build:/home/ubuntu/kernel/out/dist/init_boot.img ~/Desktop/
```

### Docker

```bash
# -v でマウントしたディレクトリに出力があればそのまま
ls ~/nothing-kernel/out/dist/init_boot.img

# またはコンテナからコピー
docker cp <container_id>:/workspace/kernel/out/dist/init_boot.img ~/Desktop/
```

### UTM

UTMのVM内でホストとの共有フォルダを設定するか、`scp` で転送:

```bash
# VM内から
scp init_boot.img <mac-user>@<mac-ip>:~/Desktop/
```

## 4. フラッシュ手順 (macOS)

```bash
# ブートローダーに入る
adb reboot bootloader

# バックアップ (初回のみ)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img ~/Desktop/backup/

# カスタムカーネルをフラッシュ
fastboot flash init_boot ~/Desktop/init_boot.img
fastboot reboot

# NetHunter zipを転送
adb push ~/Downloads/nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
```

## 5. 復旧 (macOS)

```bash
# 電源 + 音量下 でfastbootモードに入る
fastboot flash init_boot ~/Desktop/backup/stock_init_boot_a.img
fastboot reboot
```

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| `adb devices` で何も表示されない | USBケーブルを変える。USB-A to USB-Cアダプタ経由で試す |
| `fastboot devices` で何も表示されない | `sudo fastboot devices` を試す。macOSのセキュリティ設定でUSBアクセスを許可 |
| OrbStackのx86_64 VMが遅い | Apple Siliconでのx86_64エミュレーションは本来の30〜50%程度の速度。Bazelビルドは1〜2時間かかる場合がある |
| Dockerでメモリ不足 | Docker Desktop → Settings → Resources → メモリを12GB+に |
| `brew install` が失敗 | `brew update && brew upgrade` を先に実行 |
| macOS Ventura+でadbが「開発元を確認できない」 | システム設定 → プライバシーとセキュリティ → 「このまま許可」 |

## Intel Mac vs Apple Silicon

| | Intel Mac | Apple Silicon (M1+) |
|---|---|---|
| adb/fastboot | ✅ ネイティブ動作 | ✅ Rosettaで動作 |
| Linux VM (ネイティブx86_64) | ✅ 高速 (VT-x) | ❌ エミュレーション (遅い) |
| Linux VM (arm64) | ❌ | ✅ 高速だがAOSP clang非対応 |
| Docker x86_64 | ✅ 高速 | ⚠️ Rosetta変換で動作 (遅い) |
| クラウドビルド | ✅ 推奨 | ✅ **最も推奨** |

**Apple Siliconユーザーへの推奨:** adb/fastbootはローカルで実行し、カーネルビルドはクラウド環境 (GitHub Codespaces等) または十分なメモリを割り当てたOrbStack x86_64 VMで行うのが最も快適。
