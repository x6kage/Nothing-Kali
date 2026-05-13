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

カーネルをビルドする場合はWSL2が必須。フラッシュだけならWindows単体でOK。

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

## 2. WSL2 セットアップ (カーネルビルド用)

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
