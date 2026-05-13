# NetHunter Proインストール

USB ConfigFSサポート付きのカスタムカーネルをフラッシュした後の、すべてのNothingデバイス共通のインストール手順。

## 前提条件

- USB ConfigFSガジェットオプションを有効にしたカスタムカーネルがフラッシュ済み（デバイス固有ガイドを参照）
- root権限（Magisk / KernelSU / KernelSU Next）
- ブートローダーがアンロック済み
- USBデバッグが有効化済み（`Settings → Developer options → USB debugging`）
- `adb` と `fastboot` がインストールされたPC
- デバイスに約10 GBの空き容量（フルchrootの場合）

## 1. アーキテクチャの確認

**すべてのNothingデバイスは arm64 (aarch64)** アーキテクチャである。NetHunter Proのダウンロード時に `arm64` を選択すること。

端末上で確認する場合：

```bash
# 方法1: getprop
adb shell getprop ro.product.cpu.abi
# 出力: arm64-v8a  ← これが正しい

# 方法2: uname
adb shell uname -m
# 出力: aarch64  ← これが正しい
```

| 表示 | 意味 | NetHunterの選択 |
|------|------|:---:|
| `arm64-v8a` / `aarch64` | 64-bit ARM | **arm64** ✅ |
| `armeabi-v7a` / `armv7l` | 32-bit ARM | arm（非該当） |
| `x86_64` | Intel/AMD 64-bit | x86_64（非該当） |

> **重要：** `armhf` や `armel` は選ばないこと。Nothing phoneはすべて64-bitである。

## 2. NetHunter Proのダウンロード

公式ダウンロードページ: https://www.kali.org/get-kali/#kali-mobile

### ダウンロード手順

1. ページを開き **NetHunter** セクションまでスクロール
2. 以下を選択：

| 項目 | 選択する値 | 理由 |
|------|-----------|------|
| **Platform** | Android | — |
| **Type** | NetHunter | Proを含むフルバージョン |
| **Architecture** | **arm64** | Nothing phoneはすべてarm64 |

3. ファイル名が `nethunter-generic-arm64-kalifs-full.zip` のようになっていることを確認

### なぜ「Generic」なのか

NetHunter Proのイメージには「デバイス固有」と「Generic」がある：

| タイプ | 説明 | Nothing phoneでは |
|--------|------|:---:|
| **Generic arm64** | 汎用arm64イメージ | ✅ これを使う |
| デバイス固有（Pixel、OnePlus等） | 特定デバイス向け | ❌ Nothing用は無い |

Nothing phone専用のNetHunterイメージは存在しないため、**Generic arm64** を使用する。カスタムカーネルでUSB ConfigFSが有効化されていれば、Genericイメージで全機能が使える。

### イメージバリアント

| バリアント | ファイル名に含まれる語 | サイズ | 内容 | 推奨 |
|---------|----------------------|--------|------|:---:|
| **Full** | `kalifs-full` | ～1.5 GB | 完全なツールセット（Metasploit、Nmap、Burp等） | ✅ |
| **Minimal** | `kalifs-minimal` | ～300 MB | 基本ツールのみ。他は `apt` で追加 | ストレージ節約向け |
| **Nano** | `kalifs-nano` | ～100 MB | 最小限 | 非推奨 |

> ダウンロード後、KaliダウンロードページのSHA256チェックサムと照合すること：
> ```bash
> # Linux / macOS
> sha256sum nethunter-generic-arm64-kalifs-full.zip
> # Windows (PowerShell)
> Get-FileHash nethunter-generic-arm64-kalifs-full.zip -Algorithm SHA256
> ```

## 3. NetHunterのインストール

### 方法A：Magisk Manager経由でフラッシュ（推奨）

1. NetHunter zipをデバイスに転送：
   ```bash
   adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
   ```

2. **Magisk Manager** → **Modules** → **Install from storage** を開く

3. NetHunter zipファイルを選択してフラッシュ

4. **まだ再起動しないこと** — 必要に応じて先にインストール後の確認を行うか、プロンプトが表示されたら再起動する

### 方法B：KernelSU経由でフラッシュ

KernelSUは異なるモジュール形式を使用するが、NetHunterのインストーラはroot化の方法を自動検出する。

1. zipをデバイスに転送：
   ```bash
   adb push nethunter-generic-arm64-kalifs-full.zip /sdcard/Download/
   ```

2. **KernelSU Manager** → **Modules** → **Install from storage** を開く

3. NetHunter zipを選択 — インストーラがKernelSUを検出して自動設定する

4. プロンプトが表示されたら再起動

> **KernelSU注意事項：** NetHunterインストーラがKernelSUを検出できない場合、ターミナルから手動でインストールする必要がある場合がある：
> ```bash
> adb shell
> su
> cd /sdcard/Download/
> unzip nethunter-generic-arm64-kalifs-full.zip -d /tmp/nethunter/
> sh /tmp/nethunter/META-INF/com/google/android/update-binary "" "" /sdcard/Download/nethunter-generic-arm64-kalifs-full.zip
> ```

### 方法C：カスタムリカバリ（TWRP / OrangeFox）経由でフラッシュ

TWRPまたはOrangeFoxがデバイスで利用可能な場合：

1. リカバリモードで起動：
   ```bash
   adb reboot recovery
   ```
2. **Install** → NetHunter zipを選択
3. スワイプしてフラッシュ
4. システムに再起動

> **注意：** カスタムリカバリのサポートはデバイスによって異なる。ほとんどのNothing phoneには公式のTWRPビルドがまだない。方法Aまたは方法Bの方が信頼性が高い。

## 4. 初期セットアップ

再起動後：

1. **NetHunterアプリを開く** — アプリ一覧に表示されるはず

2. プロンプトが表示されたら**すべての権限を付与**：
   - Root権限（Superuser）
   - ストレージ
   - 位置情報（WiFi機能用）
   - 通知（バックグラウンドサービス用）

3. **Kali Chrootのセットアップ：**
   - NetHunterアプリで **Kali Chroot Manager** に移動
   - フラッシュ時にchrootが含まれていなかった場合、ダウンロードする：
     - 最大限のツール環境には **Full chroot** を選択
     - アーキテクチャ：**arm64**
     - ダウンロードと展開を待つ（接続環境に応じて10〜30分かかる場合がある）
   - インストール完了後、**Start Kali Chroot** をタップ

4. **chrootが実行中であることを確認：**
   ```bash
   # NetHunterターミナルまたはrootシェルで：
   su
   nethunter
   cat /etc/os-release
   # 表示: Kali GNU/Linux
   ```

### chroot内の初回設定

```bash
# パッケージリストの更新
apt update

# インストール済みパッケージのアップグレード（任意、時間がかかる）
apt upgrade -y

# よく使うツールがインストールされていなければインストール
apt install -y nmap metasploit-framework aircrack-ng wifite sqlmap john hashcat \
  hydra burpsuite responder seclists wordlists

# Metasploitデータベースのセットアップ
msfdb init
```

## 5. USB HIDガジェットの確認

USB ConfigFSが動作していることをテスト：

```bash
su
ls /config/usb_gadget/
```

ディレクトリが存在しガジェット設定が含まれていれば、USB HIDは機能している。

NetHunterアプリ内で：
1. **USB Arsenal** に移動
2. 「Your kernel does not support USB ConfigFS!」と表示される場合 → カーネルが正しく設定されていない
3. 正常にロードされる場合 → USB HID攻撃の準備完了

### USB HIDクイックテスト

1. USB経由でスマートフォンをターゲットコンピュータに接続
2. NetHunter → **HID Attacks** → **DuckyScript**
3. 簡単なスクリプトを入力：
   ```
   DELAY 2000
   GUI r
   DELAY 500
   STRING notepad
   DELAY 500
   ENTER
   DELAY 1000
   STRING Hello from NetHunter!
   ```
4. **Execute** をタップ — ターゲットコンピュータでメモ帳が開き、テキストが入力されるはず

> **安全上の注意：** USB HIDは自分のマシンでのみテストすること。ターゲットコンピュータはスマートフォンをキーボード/マウスとして認識するため、OS側でこれをブロックする方法はない。

## 6. WiFiモニターモードの確認

### WCN7850デバイス（Phone 3、4a Pro）のath12kパッチ適用時：

```bash
su
ip link set wlan0 down
iw dev wlan0 set type monitor
ip link set wlan0 up
iw dev wlan0 info
```

出力に `type monitor` と表示されれば、内蔵WiFiのモニターモードが動作している。

クイックキャプチャテスト：

```bash
# 10秒間パケットをキャプチャ
tcpdump -i wlan0 -c 100 -w /sdcard/capture.pcap

# またはairodump-ngを使用
airodump-ng wlan0
```

### MT6655デバイス（Phone 2a）のgen4mスニファーパッチ適用時：

gen4mドライバインターフェース経由でスニファーモードが有効化されるか確認する。正確な方法はファームウェアがスニファーコマンドを受け付けるかどうかに依存する。詳細は[Phone (2a)ガイド](phone-2a.md#3-internal-wifi-monitor-mode-experimental)を参照。

### WCN6750デバイス（Phone 3a、4a）の場合：

内蔵WiFiのモニターモードは利用できない。外部USB WiFiアダプタを接続する：

```bash
su
# OTG経由でアダプタを接続した後：
ip link
# wlan1または同様の新しいインターフェースを探す
iw dev wlan1 set type monitor
ip link set wlan1 up
iw dev wlan1 info
```

推奨アダプタとドライバのセットアップについては[外部WiFiアダプタ](external-wifi.md)を参照。

## 7. 外部WiFiドライバのインストール（必要な場合）

デバイス固有ガイドで `88XXau.ko`（rtl8812au）をビルドした場合：

```bash
# モジュールをプッシュ
adb push 88XXau.ko /sdcard/

# ロード（一時的 — 次の再起動まで）
adb shell su -c "insmod /sdcard/88XXau.ko"

# モジュールがロードされたことを確認
adb shell su -c "lsmod | grep 88XXau"
```

### ドライバの再起動後も永続化

**方法A：Magiskモジュール（推奨）**

起動時にドライバをロードするシンプルなMagiskモジュールを作成：

```bash
mkdir -p /data/adb/modules/rtl8812au/system/vendor/lib/modules/
cp /sdcard/88XXau.ko /data/adb/modules/rtl8812au/system/vendor/lib/modules/

# module.propを作成
cat > /data/adb/modules/rtl8812au/module.prop << 'EOF'
id=rtl8812au
name=RTL8812AU WiFi Driver
version=1.0
versionCode=1
author=Nothing-Kali
description=RTL8812AU driver for external WiFi monitor mode
EOF

# post-fs-data.shを作成してモジュールをロード
cat > /data/adb/modules/rtl8812au/post-fs-data.sh << 'EOF'
#!/system/bin/sh
insmod /vendor/lib/modules/88XXau.ko
EOF
chmod 755 /data/adb/modules/rtl8812au/post-fs-data.sh
```

**方法B：直接配置**

```bash
adb shell su -c "mount -o rw,remount /vendor"
adb shell su -c "cp /sdcard/88XXau.ko /vendor/lib/modules/"
adb shell su -c "chmod 644 /vendor/lib/modules/88XXau.ko"
adb shell su -c "mount -o ro,remount /vendor"
```

## 8. NetHunter KeX（デスクトップモード）

NetHunter KeXは、スマートフォン上またはリモートからアクセス可能な完全なKali Linuxデスクトップを提供する：

1. NetHunterアプリ → **KeX Manager**
2. VNCパスワードを設定
3. KeXサーバーを起動
4. 以下の方法で接続：
   - **スマートフォン上：** VNCクライアント（例：AVNC）をインストールし、`localhost:5901` に接続
   - **PCから：** `vncviewer <phone-ip>:5901`

## NetHunter Proで利用可能なツール

適切に設定されたカーネルがあれば、以下のツールにアクセスできる：

| ツール | 必要条件 | 説明 |
|------|----------|-------------|
| USB HIDキーボード/マウス攻撃 | USB ConfigFS ✅ | ターゲットマシンでキーボード/マウスをエミュレート |
| DuckyScript実行 | USB ConfigFS ✅ | 自動キーストロークインジェクションスクリプトの実行 |
| RNDIS / USBテザリング | USB ConfigFS ✅ | USB経由のネットワークインターフェース作成 |
| USBマスストレージエミュレーション | USB ConfigFS ✅ | USBドライブをエミュレート |
| Aircrack-ng / WiFiクラッキング | モニターモードWiFi | WPA/WPA2ハンドシェイクキャプチャとクラッキング |
| Wifite / 自動WiFi監査 | モニターモードWiFi | 自動無線攻撃 |
| Kismet / WiFi偵察 | モニターモードWiFi | パッシブ無線ネットワーク探索 |
| Bluetoothツール（Ubertooth） | Ubertoothハードウェア | BLEスニッフィングと分析 |
| Metasploit Framework | Kali chroot ✅ | エクスプロイトフレームワーク |
| Nmap / ネットワークスキャン | Kali chroot ✅ | ネットワーク探索とポートスキャン |
| Burp Suite / Webテスト | Kali chroot ✅ | Webアプリケーションセキュリティテスト |
| SQLMap / SQLインジェクション | Kali chroot ✅ | 自動SQLインジェクション |
| Responder / LLMNRポイズニング | Kali chroot ✅ | ネットワークプロトコルエクスプロイト |
| John / Hashcat / クラッキング | Kali chroot ✅ | パスワードハッシュクラッキング |
| NetHunter KeX（デスクトップ） | Kali chroot ✅ | VNC経由の完全なKaliデスクトップ |

## トラブルシューティング

### 「Your kernel does not support USB ConfigFS!」

カーネルが必要なCONFIGオプションでビルドされていない。すべての `CONFIG_USB_CONFIGFS_*` オプションを有効にして再ビルドすること。[カーネル設定検証スクリプト](../../scripts/verify-kernel.sh)を参照。

### WiFiアダプタが検出されない

```bash
# USBデバイスの列挙を確認
dmesg | grep -i usb

# モジュールがロードされたか確認
lsmod | grep 88XXau

# 手動ロードを試行
insmod /path/to/88XXau.ko

# カーネルログでエラーを確認
dmesg | tail -20
```

### chrootのインストールに失敗

- 十分なストレージを確認：フルchrootには約5〜10 GBが必要
- まずミニマルchrootを試し、`apt` 経由で個別にツールをインストール
- `/data/local/nhsystem/` のパーミッションを確認：rootが所有者であること
- ダウンロードが失敗する場合、rootfsをKaliから手動でダウンロードして展開：
  ```bash
  wget https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz
  adb push kalifs-arm64-full.tar.xz /sdcard/
  ```

### モニターモードがクラッシュまたは失敗

```bash
# カーネルログでパニック/エラーを確認
dmesg | grep -i -E "ath12k|ath11k|wlan|monitor|panic"

# ath12kの場合：ファームウェアバージョンを確認
ls /vendor/firmware/ath12k/WCN7850/hw2.0/
cat /vendor/firmware/ath12k/WCN7850/hw2.0/board-2.bin.txt 2>/dev/null

# 別のプロセスがインターフェースを使用していないか確認
iw dev
rfkill list
```

### NetHunterアプリが空白画面/クラッシュ

- アプリデータをクリア：`Settings → Apps → NetHunter → Clear Data`
- NetHunter zipを再フラッシュ
- Magisk/KernelSUがアプリにrootを正しく付与しているか確認

### Metasploitデータベースが起動しない

```bash
# chroot内で
service postgresql start
msfdb reinit
```

## 次のステップ

- **[外部WiFiアダプタ](external-wifi.md)** — モニターモード＋インジェクションが保証される外部USB WiFiのセットアップ
- **[セキュリティに関する考慮事項](security.md)** — NetHunter使用時のオペレーショナルセキュリティ
- **[トラブルシューティング](troubleshooting.md)** — 包括的な問題解決ガイド
