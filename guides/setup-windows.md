# Windows 環境セットアップ

Windows PCからNothing phoneにNetHunter Pro用カスタムカーネルをビルド・フラッシュするためのガイド。

## 概要: 何にWindowsを使い、何にLinuxが必要か

| 作業 | Windows単体 | WSL2 (Linux) |
|------|:---:|:---:|
| adb / fastboot (フラッシュ) | ✅ | ✅ |
| ブートローダーアンロック | ✅ | ✅ |
| NetHunter Pro zipの転送 | ✅ | ✅ |
| **カーネルビルド** | ❌ | ✅ |
| **カーネルモジュールビルド** | ❌ | ✅ |
| **rtl8812auビルド** | ❌ | ✅ |

カーネルをビルドする場合はLinux環境 (WSL2 or クラウド) が必須。フラッシュだけならWindows単体でOK。

## 1. ADB / Fastboot のインストール

### 方法A: Android SDK Platform Tools (推奨)

1. [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools) からWindows版をダウンロード
2. 任意のフォルダに展開 (例: `C:\platform-tools`)
3. システム環境変数のPATHに追加:
   - `Win + X` → `システム` → `システムの詳細設定` → `環境変数`
   - `Path` を編集 → `C:\platform-tools` を追加
4. コマンドプロンプトまたはPowerShellで確認:
   ```
   adb version
   fastboot --version
   ```

### 方法B: winget (Windows 11)

```powershell
winget install Google.PlatformTools
```

### USBドライバ

Nothing phoneをadb/fastbootで認識させるにはUSBドライバが必要:

1. デバイスをUSBで接続
2. `設定 → 開発者向けオプション → USBデバッグ` を有効化
3. ドライバが自動インストールされない場合:
   - [Google USB Driver](https://developer.android.com/studio/run/win-usb) をインストール
   - または [Universal ADB Driver](https://adb.clockworkmod.com/) を使用
4. 確認:
   ```
   adb devices
   ```
   デバイスが表示されればOK。`unauthorized` と出る場合は端末側でUSBデバッグ許可を承認する。

### Fastbootモードでの接続確認

```
adb reboot bootloader
fastboot devices
```

デバイスが表示されない場合:
- USBケーブルを変える (充電専用ケーブルではダメ)
- 別のUSBポート (USB 2.0ポート推奨) を試す
- デバイスマネージャーでドライバを確認

## 2. カーネルビルド環境の選択

カーネルビルドにはLinux x86_64環境が必要。PCのスペックに応じて方法を選ぶ:

| 方法 | 必要スペック | ビルド時間目安 | 推奨 |
|------|-------------|---------------|:---:|
| **WSL2 (ローカル)** | RAM 16GB+, ディスク 150GB+, 4コア+ | 15〜60分 | ✅ ハイスペックPC |
| **クラウド (GitHub Codespaces)** | ブラウザが動けばOK | 15〜30分 | ✅ **低スペックPC** |
| **クラウド (GCP/AWS一時VM)** | ブラウザ + クレカ | 10〜20分 | 最速 |
| **Docker Desktop + WSL2** | RAM 16GB+, ディスク 150GB+ | WSL2と同等 | 環境隔離したい場合 |

### 低スペックPCの場合

RAM 8GB以下、ディスク空き100GB未満、またはCPUが2コアの場合、ローカルでのカーネルビルドは **OOMキルやビルド時間数時間のリスクがある**。以下を推奨:

1. **adb/fastboot のみローカルにインストール** (セクション1の手順)
2. **カーネルビルドはクラウドで実行** (セクション2B)
3. **ビルド成果物 (`init_boot.img`) をダウンロードしてローカルでフラッシュ**

この場合、WSL2のセットアップ (セクション2A) はスキップしてよい。

### 2A. WSL2 セットアップ (ローカルビルド)

> **スキップ可:** クラウドビルド (2B) を使う場合はこのセクションは不要。

カーネルビルドにはLinux環境が必要。WSL2 (Windows Subsystem for Linux 2) を使う。

### WSL2 のインストール

PowerShell (管理者) で:

```powershell
wsl --install -d Ubuntu-22.04
```

再起動後、Ubuntuが起動してユーザー作成を求められる。

### ディスク容量の確保

カーネルビルドには100–150 GBの空きが必要。WSL2のデフォルトvhdxサイズが小さい場合は拡張する:

```powershell
# WSL2を停止
wsl --shutdown

# vhdxのパスを確認 (通常: %LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu22.04...\LocalState\ext4.vhdx)
# diskpartで拡張
diskpart
select vdisk file="C:\Users\<USER>\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04onWindows_79rhkp1fndgsc\LocalState\ext4.vhdx"
expand vdisk maximum=200000
exit

# WSL2内でリサイズ
wsl
sudo resize2fs /dev/sdc 200G
```

### ビルド環境のセットアップ

WSL2 Ubuntu内で:

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves
```

以降のカーネルビルド手順は各デバイスガイドの通り。WSL2内のパスで作業する。

### WSL2 から adb/fastboot を使う

WSL2内から直接USBデバイスにアクセスするには `usbipd-win` が必要:

```powershell
# Windows側 (PowerShell 管理者)
winget install usbipd
```

```bash
# WSL2側
sudo apt install linux-tools-generic hwdata
sudo update-alternatives --install /usr/local/bin/usbip usbip /usr/lib/linux-tools/*-generic/usbip 20
```

```powershell
# デバイスを接続後、PowerShellで:
usbipd list                    # BUSID確認
usbipd bind --busid <BUSID>    # バインド
usbipd attach --wsl --busid <BUSID>   # WSLにアタッチ
```

WSL2内で `adb devices` が使えるようになる。

> **簡単な方法:** WSL2ではカーネルビルドのみ行い、adb/fastbootはWindows側のコマンドプロンプトで実行する。ビルド成果物は `/mnt/c/Users/<USER>/...` 経由でWindows側からアクセスできる。

```bash
# WSL2内でビルド後、Windowsアクセス可能な場所にコピー
cp out/dist/init_boot.img /mnt/c/Users/<USER>/Desktop/
```

Windows側で:
```
cd C:\Users\<USER>\Desktop
fastboot flash init_boot init_boot.img
```

### 2B. クラウドビルド (低スペックPC / ローカルにLinux環境を作りたくない場合)

ブラウザだけあればカーネルビルドが可能。ビルド成果物をダウンロードしてローカルのadb/fastbootでフラッシュする。

#### GitHub Codespaces (推奨)

GitHubアカウントがあれば無料枠で利用可能 (月120コア時間):

1. [github.com/codespaces](https://github.com/codespaces) にアクセス
2. **New codespace** → **Blank template** → マシンタイプ **4-core** 以上を選択
3. ターミナルが開いたらビルド環境をセットアップ:

```bash
sudo apt update
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod dwarves

# 以降はデバイスガイドの手順通りにカーネルをクローン・ビルド
# 例: Phone (2a)
git clone -b mt6886/Pacman/v --depth=1 \
  https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886.git kernel
```

4. ビルド完了後、成果物をダウンロード:
   - Codespaceのファイルエクスプローラから `init_boot.img` を右クリック → **Download**
   - またはターミナルで: `gh codespace cp remote:kernel/out/dist/init_boot.img .` (ローカル側で実行)

#### Google Cloud Shell

Googleアカウントがあれば無料で使える (e2-small, 一時的):

1. [shell.cloud.google.com](https://shell.cloud.google.com/) にアクセス
2. ターミナルでビルド環境セットアップ → ビルド
3. `cloudshell download init_boot.img` でローカルにダウンロード

> **注意:** Cloud Shellのディスクは5GBしかない永続領域 + 一時領域。大きなカーネルツリーは一時領域に置く。セッション終了で消える。

#### GCP / AWS の一時VM (最速)

予算がある場合:

```bash
# GCP: e2-standard-8 (8 vCPU, 32GB RAM) — ビルド15分程度
gcloud compute instances create kernel-build \
  --machine-type=e2-standard-8 \
  --boot-disk-size=200GB \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud

# AWS: c5.2xlarge (8 vCPU, 16GB RAM)
aws ec2 run-instances \
  --instance-type c5.2xlarge \
  --image-id ami-0xxx  # Ubuntu 22.04 AMI
```

ビルド後に `scp` でダウンロードし、VMを削除すれば数十円程度。

#### クラウドビルドの流れ

```
┌──────────────────────────┐     ┌──────────────────────────┐
│     クラウド環境          │     │     ローカル Windows     │
│                          │     │                          │
│  1. カーネルソース取得    │     │                          │
│  2. defconfig設定        │     │                          │
│  3. ビルド               │     │                          │
│  4. init_boot.img生成    │────→│  5. ダウンロード          │
│                          │     │  6. fastboot flash       │
│                          │     │  7. NetHunter install    │
└──────────────────────────┘     └──────────────────────────┘
```

## 3. フラッシュ手順 (Windows)

```
:: ブートローダーに入る
adb reboot bootloader

:: バックアップ (初回のみ)
adb shell su -c "dd if=/dev/block/by-name/init_boot_a of=/sdcard/stock_init_boot_a.img"
adb pull /sdcard/stock_init_boot_a.img C:\Users\<USER>\Desktop\backup\

:: カスタムカーネルをフラッシュ
fastboot flash init_boot init_boot.img
fastboot reboot

:: NetHunter zipを転送
adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
```

## 4. 復旧 (Windows)

起動しなくなった場合:

```
:: 電源 + 音量下 を長押しでfastbootモードに入る
:: ストックイメージをフラッシュ
fastboot flash init_boot stock_init_boot_a.img
fastboot reboot
```

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| `adb devices` で何も表示されない | USBドライバ再インストール、USBデバッグの許可確認 |
| `fastboot devices` で何も表示されない | Google USB Driverインストール、USBポート変更 |
| WSL2で `apt install` が遅い | WSL2のDNS設定: `/etc/resolv.conf` に `nameserver 8.8.8.8` |
| WSL2のディスクが足りない | 上記のvhdx拡張手順を実行 |
| `adb push` が遅い | USB 3.0ポートを使用、MTPモードからファイル転送モードに切替 |
| Windowsのウイルス対策がビルドを遅くする | WSL2のファイルシステム (`/home/...`) 内で作業する (Windows側の `/mnt/c/` は遅い) |
| WSL2のビルドがOOM (メモリ不足) で止まる | `.wslconfig` でメモリ制限を緩和するか、`make -j2` でジョブ数を減らす。根本的にはクラウドビルド (2B) を推奨 |
| PCのRAMが8GB以下 | WSL2でのビルドは厳しい。クラウドビルド (2B) を使用 |
| ディスク空きが100GB未満 | カーネルツリーだけで50〜80GB必要。外付けSSDにWSL2を移動するか、クラウドビルドを使用 |
| WSL2でBazelがクラッシュする | メモリ不足の可能性大。`--jobs=2` オプションを追加するか、クラウドビルドへ |
