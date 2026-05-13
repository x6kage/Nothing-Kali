# 外部WiFiアダプタ

Nothing phoneでモニターモードとパケットインジェクションを使用するための、外部USB WiFiアダプタの選択、セットアップ、使用に関するガイド。

## なぜ外部アダプタが必要か？

内蔵WiFiのモニターモードは、Phone (3)とPhone (4a) Pro（カーネルパッチ適用時）でのみ利用可能である。その他のデバイスでは、無線ペネトレーションテストに外部USB WiFiアダプタが必要となる。内蔵モニターモードが使えるデバイスでも、外部アダプタには以下の利点がある：

- **信頼性の高いパケットインジェクション** — 内蔵WiFiファームウェアはモニターモードでの送信を制限する場合がある
- **デュアルラジオ運用** — 内蔵ラジオでWiFi接続を維持しながら外部でモニタリング
- **より高い送信電力** — 一部の外部アダプタにはアンプと外部アンテナが搭載されている
- **帯域の選択** — 2.4GHz、5GHz、または両方に最適化されたアダプタを選択可能

## 推奨アダプタ

### Tier 1：最良の選択

| アダプタ | チップセット | 帯域 | ドライバ | モニター | インジェクション | 価格帯 |
|---------|---------|-------|--------|:---:|:---:|-------------|
| **Alfa AWUS036ACH** | RTL8812AU | 2.4 + 5 GHz | rtl8812au | ✅ | ✅ | 約$50 |
| **Alfa AWUS036ACHM** | RTL8812AU | 2.4 + 5 GHz | rtl8812au | ✅ | ✅ | 約$45 |
| **Alfa AWUS036ACM** | MT7612U | 2.4 + 5 GHz | mt76 | ✅ | ✅ | 約$40 |

### Tier 2：低価格オプション

| アダプタ | チップセット | 帯域 | ドライバ | モニター | インジェクション | 価格帯 |
|---------|---------|-------|--------|:---:|:---:|-------------|
| **Panda PAU09** | RT5572 | 2.4 + 5 GHz | rt2800usb | ✅ | ✅ | 約$20 |
| **TP-Link TL-WN722N v1** | AR9271 | 2.4 GHzのみ | ath9k_htc | ✅ | ✅ | 約$15 |
| **Alfa AWUS036NHA** | AR9271 | 2.4 GHzのみ | ath9k_htc | ✅ | ✅ | 約$25 |

### Tier 3：WiFi 6/6E（上級者向け）

| アダプタ | チップセット | 帯域 | ドライバ | モニター | インジェクション | 備考 |
|---------|---------|-------|--------|:---:|:---:|-------|
| **Alfa AWUS036AXML** | MT7921AU | 2.4 + 5 + 6 GHz | mt76 | ✅ | ⚠️ | WiFi 6E、インジェクション制限あり |
| **Netgear A8000** | MT7921AU | 2.4 + 5 + 6 GHz | mt76 | ✅ | ⚠️ | WiFi 6E |

> **WiFi 6Eアダプタに関する注意：** モニターモードは動作するが、mt76ドライバでのパケットインジェクションサポートはまだ成熟途上である。信頼性の高いインジェクションにはTier 1のアダプタを推奨する。

### アダプタの選び方

| ユースケース | 最適な選択 | 理由 |
|----------|-------------|-----|
| WPA/WPA2クラッキング | Alfa AWUS036ACH | デュアルバンド、高送信電力、信頼性の高いインジェクション |
| ポータブル／旅行用 | Alfa AWUS036ACHM | コンパクトな形状、ACHと同じチップセット |
| 低予算／学習用 | Panda PAU09またはTP-Link TL-WN722N v1 | 安価で十分なサポート |
| WiFi 6Eターゲット | Alfa AWUS036AXML | 6 GHz帯サポート |
| 最大互換性 | Alfa AWUS036ACM | mt76はカーネルサポートが優れている |

## ハードウェアセットアップ

### USB OTG接続

Nothing phoneはUSB OTGをサポートしている。必要なもの：

1. **USB-C OTGアダプタ**（USB-C オス → USB-A メス）
2. OTGアダプタに接続した**USB WiFiアダプタ**

選択肢：
- シンプルなUSB-C to USB-A OTGアダプタ（約$5）
- USB-Aポート付きUSB-Cハブ（アダプタ使用中の充電が可能）
- USB-C to Micro-USB OTGケーブル（古いアダプタ用）

### USB OTGの動作確認

```bash
# アダプタを接続してから確認
adb shell su -c "dmesg | tail -20"
# USBデバイスの列挙メッセージを探す

adb shell su -c "lsusb"
# アダプタが表示されるはず（例：RTL8812AUの場合 "0bda:8812"）
```

## ドライバのセットアップ

### RTL8812AU（Realtek）

最も一般的に使用されるアダプタのチップセット。カーネルツリー外のモジュールのビルドが必要。

#### ビルドホストでのクロスコンパイル

```bash
# aircrack-ngメンテナンスフォークをクローン
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au

# カスタムカーネルに対してビルド
make ARCH=arm64 LLVM=1 \
  KSRC=<path-to-kernel-out-directory> \
  modules

# 出力: 88XXau.ko
```

またはヘルパースクリプトを使用：

```bash
../../scripts/build-rtl8812au.sh <path-to-kernel-out>
```

#### デバイスへのロード

```bash
# モジュールをプッシュ
adb push 88XXau.ko /sdcard/

# ロード（一時的 — 次の再起動まで）
adb shell su -c "insmod /sdcard/88XXau.ko"

# 確認
adb shell su -c "lsmod | grep 88XXau"
adb shell su -c "ip link"    # wlan1を探す
```

#### 永続化

Magiskモジュールを作成：

```bash
adb shell
su

mkdir -p /data/adb/modules/rtl8812au/system/vendor/lib/modules/
cp /sdcard/88XXau.ko /data/adb/modules/rtl8812au/system/vendor/lib/modules/

cat > /data/adb/modules/rtl8812au/module.prop << 'EOF'
id=rtl8812au
name=RTL8812AU WiFi Driver
version=1.0
versionCode=1
author=Nothing-Kali
description=RTL8812AU driver for external WiFi monitor mode
EOF

cat > /data/adb/modules/rtl8812au/post-fs-data.sh << 'EOF'
#!/system/bin/sh
insmod /vendor/lib/modules/88XXau.ko
EOF
chmod 755 /data/adb/modules/rtl8812au/post-fs-data.sh
```

### MT7612U / MT7921AU（MediaTek）

mt76ドライバはLinuxカーネルに標準で組み込まれている。カスタムカーネルのビルドに `CONFIG_MT76_USB=m` と `CONFIG_MT7612U=m` が含まれていれば、ドライバはすでに利用可能な場合がある。

```bash
# mt76モジュールが存在するか確認
adb shell su -c "find /vendor/lib/modules/ -name '*mt76*'"

# 存在する場合、アダプタを接続すれば自動的にロードされるはず
# 存在しない場合、ソースからビルド：
cd kernel
make O=out M=drivers/net/wireless/mediatek/mt76 modules
```

### AR9271 / RT5572（Atheros / Ralink）

これらのチップセットはカーネル内蔵ドライバ（`ath9k_htc`、`rt2800usb`）を使用しており、通常Androidカーネルに含まれている。特別な操作なしで動作する場合がある。

```bash
# アダプタを接続して確認
adb shell su -c "dmesg | grep -i 'ath9k\|rt2800\|usb'"
adb shell su -c "ip link"
```

ドライバがロードされない場合、カーネルビルドで関連するCONFIGオプションが有効になっていることを確認：

```
CONFIG_ATH9K_HTC=m        # AR9271用
CONFIG_RT2800USB=m         # RT5572用
```

## モニターモードの使用

### 基本セットアップ

```bash
su

# 外部インターフェースを特定
ip link
# 内蔵WiFi: wlan0
# 外部アダプタ: 通常はwlan1

# モニターモードに設定
ip link set wlan1 down
iw dev wlan1 set type monitor
ip link set wlan1 up

# 確認
iw dev wlan1 info
# type should show "monitor"
```

### チャンネル選択

```bash
# 特定のチャンネルを設定
iw dev wlan1 set channel 6          # 2.4 GHz channel 6
iw dev wlan1 set channel 36         # 5 GHz channel 36
iw dev wlan1 set channel 36 HT40+   # 40 MHz width
iw dev wlan1 set channel 36 80MHz    # 80 MHz width (if supported)
```

### よく使うツール

```bash
# ネットワーク探索
airodump-ng wlan1

# 特定のネットワークをターゲット（チャンネル6、BSSIDフィルタ）
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w capture wlan1

# 認証解除（許可されたテストのみ）
aireplay-ng -0 5 -a AA:BB:CC:DD:EE:FF wlan1

# WPAハンドシェイクキャプチャ + クラック
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w handshake wlan1
# （ハンドシェイクのキャプチャを待つ）
aircrack-ng -w /usr/share/wordlists/rockyou.txt handshake-01.cap

# 自動監査
wifite --interface wlan1

# パッシブパケットキャプチャ
tcpdump -i wlan1 -w /sdcard/capture.pcap
```

### デュアルラジオ運用

外部アダプタの最大の利点の1つ：内蔵ラジオでWiFi接続を維持しながら、外部でペネトレーションテストを行う。

```bash
# 内蔵 (wlan0): 自宅WiFiに接続してインターネット利用
# 外部 (wlan1): モニターモードでペンテスト

ip link set wlan1 down
iw dev wlan1 set type monitor
ip link set wlan1 up

# 内蔵WiFiはインターネット、データ転送等に引き続き使用可能
# 外部WiFiは独立してパケットをキャプチャ
```

## トラブルシューティング

### アダプタが検出されない

```bash
# USB列挙を確認
adb shell su -c "dmesg | grep -i usb"
adb shell su -c "lsusb"

# lsusbにアダプタが表示されない場合：
# - 別のOTGアダプタ/ケーブルを試す
# - 開発者オプションでUSB OTGが有効か確認
# - 一部のアダプタは電力消費が大きい — 電源付きUSBハブを使用
```

### モジュールがロードされない

```bash
# エラーを確認
adb shell su -c "dmesg | tail -20"

# よくある問題：
# "version magic mismatch" → モジュールが異なるカーネルに対してビルドされている
# "Unknown symbol" → 依存モジュールが不足
# "Operation not permitted" → SELinuxがブロック → 試す: setenforce 0
```

### モニターモードが失敗

```bash
# モニターがサポートされたモードに含まれているか確認
adb shell su -c "iw phy phy1 info | grep -A 10 'Supported interface modes'"

# rfkillを確認
adb shell su -c "rfkill list"
# アダプタがソフトブロックされている場合: rfkill unblock all
```

### 信号が弱い／パフォーマンスが低い

- アダプタのアンテナ接続を確認
- 別のUSB OTGアダプタを試す（シールドが不十分なものがある）
- USB延長ケーブルを使用してアダプタをスマートフォン本体から離す
- 送信電力ブーストを有効化（アダプタ依存）：
  ```bash
  iw dev wlan1 set txpower fixed 3000    # 30 dBm (check regulatory limits)
  ```
