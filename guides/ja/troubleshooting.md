# トラブルシューティング

Nothing-Kaliカーネルのビルド、フラッシュ、およびNetHunterの使用における一般的な問題と解決策。

## ビルドの問題

### ツールチェーン／コンパイラ

| 症状 | 原因 | 解決策 |
|---------|-------|----------|
| `clang: not found` | ClangがPATHにない | `export PATH=.../clang-rXXX/bin:$PATH` |
| `incompatible pointer type` | Clangバージョンが間違っている | `build.config.constants` に記載された正確なバージョンを使用 |
| `CONFIG_LTO_CLANG: unmet dependency` | LTOが設定されていない | `CONFIG_LTO=y` と `CONFIG_LTO_CLANG_THIN=y` を有効化 |
| `BTF: .tmp_vmlinux.btf: pahole not found` | dwarves未インストール | `sudo apt install dwarves` |
| `openssl/bio.h: No such file` | OpenSSL開発ヘッダー未インストール | `sudo apt install libssl-dev` |
| `elf.h: No such file` | libelfヘッダー未インストール | `sudo apt install libelf-dev` |
| `bison: command not found` | ビルド依存関係が不足 | `sudo apt install bison flex` |

### defconfig／設定

| 症状 | 原因 | 解決策 |
|---------|-------|----------|
| `No rule to make target '...defconfig'` | defconfig名が間違っている | `ls arch/arm64/configs/` で利用可能な設定を確認 |
| `make defconfig` 後に設定オプションが反映されない | 依存関係が満たされていない | `make menuconfig` でオプションの依存関係を確認 |
| defconfig後に `.config` が空 | 出力ディレクトリが間違っている | `O=out` が作業ディレクトリと一致していることを確認 |
| `CONFIG_USB_CONFIGFS_F_HID` が利用できない | USBガジェットの依存関係が不足 | 先に `CONFIG_USB_GADGET=y` を有効化 |

### ビルドシステム

| 症状 | 原因 | 解決策 |
|---------|-------|----------|
| `WORKSPACE not found`（Bazel） | 作業ディレクトリが間違っている | WORKSPACEファイルが存在するカーネルルートから実行 |
| `bazel: command not found` | Bazel未インストール | https://bazel.build/install/ubuntu からインストール |
| `repo: command not found` | Repoツール未インストール | `sudo apt install repo` または `pip install repo` |
| Pythonバージョンエラー | Pythonバージョンが間違っている | Python 3.8以上が利用可能であることを確認 |
| ビルド中にディスク容量不足 | ディスク不足 | 100〜150 GBの空きが必要。古いビルドを削除：`rm -rf out/` |
| メモリ不足（OOM killed） | RAM不足 | 並列ジョブ数を減らす：`-j$(nproc)` の代わりに `make -j4` |

### KMI／モジュールの問題

| 症状 | 原因 | 解決策 |
|---------|-------|----------|
| `KMI symbol ... not exported` | KMI違反 | `CONFIG_TRIM_UNUSED_KSYMS=n` を設定 |
| `depmod: FATAL: Module not found` | モジュールパスが間違っている | `make INSTALL_MOD_PATH=... modules_install` を使用 |
| `version magic mismatch` | モジュール/カーネルの不一致 | 同じカーネルに対してモジュールを再ビルド |
| ベンダーモジュールがロードされない | 誤ったコンパイラによるKMI破壊 | 正確なAOSP clangバージョンを使用 |

## フラッシュの問題

### Fastboot

| 症状 | 原因 | 解決策 |
|---------|-------|----------|
| `fastboot: command not found` | Platform tools未インストール | Android SDK platform-toolsをインストール |
| `< waiting for any device >` | デバイスがfastbootモードでない | 電源 + 音量ダウンを10秒間長押し |
| `FAILED (remote: not allowed)` | ブートローダーがロック状態 | 先にブートローダーをアンロック（[Nothing Archiveガイド](https://spike0en.github.io/nothing_archive/docs/guides#unlocking-bootloader)） |
| `FAILED (remote: flash is not allowed for init_boot)` | Fastbootフラッシュがロック | ブートローダーで `fastboot flashing unlock` を実行 |
| `sparse_file_read_normal: sparse file not found` | イメージ形式が間違っている | 正しい.imgファイルをフラッシュしていることを確認 |
| フラッシュは成功するがデバイスが起動しない | カーネルビルドの不良 | ストックイメージをフラッシュして復旧（下記参照） |

### A/Bパーティション

Nothing phoneはA/Bパーティションスキームを使用している。フラッシュ方法に影響する：

```bash
# 現在のアクティブスロットを確認
fastboot getvar current-slot

# 特定のスロットにフラッシュ
fastboot flash init_boot_a init_boot.img
fastboot flash init_boot_b init_boot.img

# または両方のスロットにフラッシュ
fastboot flash init_boot init_boot.img  # アクティブスロットにフラッシュ
fastboot --set-active=other
fastboot flash init_boot init_boot.img  # もう一方のスロットにフラッシュ
```

## リカバリ手順

### ブートループ（Nothingロゴで停止）

1. **fastbootに入る：** 電源 + 音量ダウンを10〜15秒間長押し
2. **USBを接続**してPCに繋ぐ
3. **fastboot接続を確認：**
   ```bash
   fastboot devices
   ```
4. **ストックのinit_bootをフラッシュ：**
   ```bash
   # バックアップを使用
   fastboot flash init_boot stock_init_boot_a.img
   fastboot reboot
   ```
5. バックアップがない場合、[Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware)からダウンロード

### フラッシュ後に画面が真っ暗

1. **強制再起動：** 電源を15秒間長押し
2. Nothingロゴで再起動してループする場合 → 上記のブートループ手順に従う
3. 通常通り再起動する場合 → カーネルは動作しているが、他に問題がある可能性

### fastbootに入れない

1. **長押し：** 電源 + 音量ダウンを30秒間（10秒ではなく）
2. それでもダメな場合、バッテリーが完全に消耗するのを待つ（数時間かかる場合あり）
3. 数分充電してから、再度電源 + 音量ダウンを試す
4. デバイスが充電中（LEDインジケーター）であれば、fastbootにアクセスできるはず

### フラッシュ後にWiFiが動作しない

カスタムカーネルにWLANモジュールの不一致がある可能性：

```bash
# WLANモジュールがロードされているか確認
adb shell su -c "lsmod | grep wlan"

# カーネルログでWLANエラーを確認
adb shell su -c "dmesg | grep -i -E 'wlan|ath11k|ath12k|gen4m'"

# モジュールバージョンの不一致がある場合、ストックモジュールを復元
adb shell su -c "mount -o rw,remount /vendor"
adb push stock_wlan_module.ko /sdcard/
adb shell su -c "cp /sdcard/stock_wlan_module.ko /vendor/lib/modules/<module_name>.ko"
adb shell su -c "mount -o ro,remount /vendor"
adb reboot
```

### 完全なストック復元

ストックに完全復元する（すべての変更を元に戻す）：

1. [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware)からフルストックファームウェアをダウンロード
2. すべてのパーティションをフラッシュ：
   ```bash
   adb reboot bootloader
   fastboot flash init_boot stock_init_boot.img
   fastboot flash boot stock_boot.img       # 該当する場合
   fastboot reboot
   ```
3. root解除（必要に応じて）：
   - **Magisk：** Magisk Managerを開く → Uninstall → Complete Uninstall
   - **KernelSU：** ストックカーネルをフラッシュするか、KernelSU Managerでアンインストール
4. ブートローダーの再ロック（必要に応じて — データが消去される）：
   ```bash
   fastboot flashing lock
   ```

## NetHunterの問題

### 「Your kernel does not support USB ConfigFS!」

カーネルがConfigFSオプション付きでビルドされていない。確認方法：

```bash
adb shell su -c "grep USB_CONFIGFS /proc/config.gz 2>/dev/null" | gunzip
# または
adb shell su -c "zcat /proc/config.gz | grep USB_CONFIGFS"
```

オプションが設定されていない場合、すべての `CONFIG_USB_CONFIGFS_*` オプションを有効にしてカーネルを再ビルドする。

### NetHunterアプリのクラッシュ／空白画面

```bash
# アプリデータをクリア
adb shell pm clear com.offsec.nethunter

# rootが動作しているか確認
adb shell su -c "id"
# 表示: uid=0(root)

# NetHunterを再フラッシュ
adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/
# Magisk/KernelSU経由でフラッシュ
```

### Kali Chrootの問題

| 症状 | 解決策 |
|---------|----------|
| chrootが起動しない | ストレージ容量を確認：`df -h /data` |
| chrootのダウンロードに失敗 | 手動でダウンロードしてADB経由でプッシュ |
| chroot内で `apt update` が失敗 | DNSを確認：`echo "nameserver 8.8.8.8" > /etc/resolv.conf` |
| chroot内で権限エラー | NetHunterアプリにroot権限が付与されていることを確認 |
| chrootが破損 | 削除して再インストール：`rm -rf /data/local/nhsystem/kali*` |

### Metasploitの問題

```bash
# データベースが起動しない
nethunter
service postgresql start
msfdb reinit

# 起動が遅い
# Metasploitは多くのモジュールをロードする — スマートフォンのハードウェアでは初回起動に2〜5分かかる
# msfconsole -q でクワイエット（高速）起動を使用

# メモリ不足
# スマートフォンのRAMは限られている — Metasploit実行前に他のアプリを閉じる
```

## WiFiモニターモードの問題

### モニターモードコマンドが失敗

```bash
# エラー: "Operation not supported"
# モニターがサポートされたタイプに含まれているか確認
adb shell su -c "iw phy phy0 info | grep -A 20 'Supported interface modes'"

# エラー: "Device or resource busy"
# 別のプロセスがインターフェースを使用中
adb shell su -c "iw dev"
# 干渉するプロセスを終了
adb shell su -c "airmon-ng check kill"

# エラー: "Operation not permitted"
# SELinuxがブロックしている
adb shell su -c "getenforce"
# 一時的にpermissiveに設定：
adb shell su -c "setenforce 0"
```

### モニターモードは動作するがパケットがキャプチャできない

```bash
# チャンネルを確認 — 間違ったチャンネルにいる可能性
adb shell su -c "iw dev wlan0 info"

# 特定のチャンネルを試す
adb shell su -c "iw dev wlan0 set channel 6"

# tcpdumpで確認
adb shell su -c "tcpdump -i wlan0 -c 10"
# 出力がない場合、ドライバ/ファームウェアがパケットを配信していない

# ath12kの場合：ファームウェアログを確認
adb shell su -c "dmesg | grep ath12k"
```

### モニターモード移行時のカーネルパニック

これは通常、モニターモードパッチが完全に適用されていないことを意味する：

1. すべての13個のパッチが適用されていることを確認（WCN7850デバイスの場合）
2. `dmesg` で具体的なパニックメッセージを確認
3. よくある原因：パッチ10（radiotap構築）がスキップされたか、未解決のコンフリクトがある
4. すべてのパッチを正しく適用して再ビルド

## パフォーマンスのヒント

### ビルド速度

```bash
# ccacheを使用してリビルドを高速化
sudo apt install ccache
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
ccache -M 50G

# 並列ビルド（nprocまたは特定の数を使用）
make O=out -j$(nproc)

# RAMが不足する場合、ジョブ数を減らす
make O=out -j4
```

### スマートフォン上でのNetHunterパフォーマンス

- 重いツールを実行する前に不要なアプリを閉じる
- ストレージが限られている場合、フルの代わりにミニマルchrootを使用
- 長時間のタスク（パスワードクラッキング）では、スマートフォンを充電しながらスリープを無効にする
- 負荷の高い操作中はファン/クーラーを使用 — スマートフォンはサーマルスロットリングする可能性がある
- より良いターミナル体験のためにPCからSSH経由で接続：
  ```bash
  # NetHunter chroot内で：
  service ssh start
  # PCから：
  ssh root@<phone-ip>
  ```

## ヘルプを求める

ここに記載されていない問題が発生した場合：

1. **`dmesg` を確認** — カーネルログにはほぼ常に答えがある
   ```bash
   adb shell su -c "dmesg | tail -50"
   ```
2. [Nothing-Kali GitHub](https://github.com/x6kage/Nothing-Kali/issues)で**既存のissueを検索**
3. 以下の情報を含めて**新しいissueを作成**：
   - デバイスモデルとNothing OSバージョン
   - カーネルソースのブランチとコミットハッシュ
   - 完全なエラーメッセージまたは `dmesg` の出力
   - 再現手順
