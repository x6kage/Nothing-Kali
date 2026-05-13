# Nothing-Kali

**[English version](README.md)**

> Nothing & CMFデバイス向け Kali NetHunter Pro カーネルビルド・インストールガイド

Nothingスマートフォンを日常使いのまま、ポータブルなペネトレーションテスト環境に変える。

---

## クイックスタート

1. **[デバイスサポート](#デバイスサポート)** で自分のデバイスの対応状況を確認
2. **[カーネルビルド概要](guides/ja/kernel-build-overview.md)** で何を変更するのか、なぜ必要なのかを理解
3. **[デバイス別ガイド](#デバイス別カーネルビルド)** に従ってカーネルをビルド・フラッシュ
4. **[NetHunter Pro](guides/ja/nethunter-install.md)** をインストール

## デバイスサポート

| デバイス | コードネーム | SoC | WiFiチップ | ドライバ | カーネル | モニターモード | ステータス |
|---------|------------|-----|-----------|--------|--------|:---:|---------|
| Phone (1) | Spacewar | Snapdragon 778G+ | WCN6750 | ath11k | 5.4 | ✅ | 対応済 ([DroidSpace Kernel](https://github.com/ExTV/android_kernel_msm-5.4_nothing_sm7325)) |
| Phone (2) | Pong | Snapdragon 8+ Gen 1 | WCN6855 | ath11k | 5.10 | ❌ | ファームウェア制限 |
| Phone (2a) Series | Pacman | Dimensity 7200 Pro | MT6655 (Connac3) | gen4m | 5.15 | ⚠️ | [実験的](guides/ja/phone-2a.md) |
| Phone (3a) / (3a) Pro | Asteroids | Snapdragon 7s Gen 3 | WCN6750 | ath11k | 6.1 | ❌ | [USB HIDのみ](guides/ja/phone-3a.md) |
| Phone (3) | Metroid | Snapdragon 8s Gen 4 | WCN7850 (FC 7800) | ath12k | 6.6 | 🔧 | [パッチ適用可](guides/ja/phone-3.md) |
| Phone (4a) | Frogger | Snapdragon 7s Gen 3 | WCN6750 | ath11k | 6.1 | ❌ | [USB HIDのみ](guides/ja/phone-4a.md) |
| Phone (4a) Pro | FroggerPro | Snapdragon 7 Gen 4 | WCN7850 (FC 7800) | ath12k | 6.6 | 🔧 | [パッチ適用可](guides/ja/phone-4a-pro.md) |

### 凡例

- ✅ NetHunter対応コミュニティカーネルが存在
- 🔧 upstreamドライバパッチあり — カーネルビルドが必要
- ⚠️ ドライバコードは存在するが未テスト — 実験的
- ❌ ファームウェア制限 — 内蔵WiFiモニターモード不可 (外部USBアダプタが必要)

### ペンテスト目的でデバイスを選ぶなら

| 優先事項 | おすすめ | 理由 |
|---------|---------|------|
| 内蔵WiFiモニターモード | **Phone (3)** または **Phone (4a) Pro** | WCN7850 + ath12kドライバにupstreamパッチあり |
| 低予算 + USB HID攻撃 | **Phone (2a)** | 最も安価、USB ConfigFS完全対応 |
| 既に持っている | 対応デバイスなら何でも | USB HID + Kali chrootは全デバイスで動作 |

## アーキテクチャ

全てのNothing phoneは **arm64 (aarch64)** です。[公式ダウンロードページ](https://www.kali.org/get-kali/#kali-mobile) から **NetHunter Pro Generic arm64** を選択してください。

## ガイド

### まずここから

- **[カーネルビルド概要 — 何をしているのか](guides/ja/kernel-build-overview.md)** — 何が変わるか、何が変わらないか、ビルドの失敗と復旧方法

### デバイス別カーネルビルド

- [Phone (2a) Series — MT6886 / gen4m](guides/ja/phone-2a.md)
- [Phone (3) — SM8735 / ath12k / WCN7850](guides/ja/phone-3.md)
- [Phone (3a) / (3a) Pro — SM7635 / ath11k](guides/ja/phone-3a.md)
- [Phone (4a) — SM7635 / ath11k](guides/ja/phone-4a.md)
- [Phone (4a) Pro — SM7750 / ath12k / WCN7850](guides/ja/phone-4a-pro.md)

### 共通

- [NetHunter Pro インストール](guides/ja/nethunter-install.md) — ARM64確認、ダウンロード、インストール
- [外部WiFiアダプタ](guides/ja/external-wifi.md)
- [トラブルシューティング](guides/ja/troubleshooting.md)
- [セキュリティとオペレーション上の考慮事項](guides/ja/security.md)

### ビルド環境セットアップ

- [Windows セットアップ](guides/ja/setup-windows.md) — ADB/Fastboot、WSL2 / クラウドビルド
- [macOS セットアップ](guides/ja/setup-macos.md) — Homebrew、OrbStack / UTM / Docker

## 前提条件

全デバイス共通:

1. **ブートローダーアンロック** — [Nothing Archiveガイド](https://spike0en.github.io/nothing_archive/docs/guides#unlocking-bootloader) 参照
2. **Root権限** (Magisk / KernelSU / KernelSU Next)
3. **パーティションバックアップ** — カスタムカーネルをフラッシュする前に `persist`, `nvram` 等を必ずバックアップ
4. **ビルド環境** — Linux x86_64:
   - AOSP prebuilt clang (デバイスにより異なる — [カーネルビルド概要](guides/ja/kernel-build-overview.md) 参照)
   - `mkbootimg`, `lz4`, `dtc`
   - RAM 16 GB以上、ディスク 100〜150 GB
   - **Windows:** [Windowsセットアップガイド](guides/ja/setup-windows.md) (WSL2 またはクラウドビルド)
   - **macOS:** [macOSセットアップガイド](guides/ja/setup-macos.md) (OrbStack / UTM / Docker)

### ビルド環境クイックセットアップ

```bash
# Ubuntu 22.04+ / Debian 12+
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev \
  git curl python3 python3-pip lz4 device-tree-compiler zip unzip \
  repo rsync cpio kmod

# デバイスに合ったclangをダウンロード
./scripts/setup-clang.sh r510928    # Phone (3) / Phone (4a) Pro
./scripts/setup-clang.sh r487747c   # Phone (3a) / Phone (4a)
./scripts/setup-clang.sh r450784e   # Phone (2a) Series
```

## カーネルソース (NothingOSS)

| デバイス | カーネルソース | カーネルモジュール |
|---------|-------------|----------------|
| Phone (2a) Series | [android_kernel_5.15_nothing_mt6886](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) | [android_kernel_modules_nothing_mt6886](https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886) |
| Phone (3a) / (3a) Pro | [android_kernel_msm-6.1_nothing_sm7635](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) | — |
| Phone (3) | [android_kernel_msm-6.6_nothing_sm8735](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735) | — |
| Phone (4a) | [android_kernel_msm-6.1_nothing_sm7635](https://github.com/NothingOSS/android_kernel_msm-6.1_nothing_sm7635) (`sm7635/b/mr_Frogger`) | — |
| Phone (4a) Pro | [android_kernel_msm-6.6_nothing_sm7750](https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm7750) | — |

## 機能マトリックス

NetHunter Proをビルド・インストール後に各デバイスで使える機能:

| 機能 | 全デバイス | Phone (3) / (4a) Pro | Phone (2a) |
|-----|:---------:|:--------------------:|:-----------:|
| USB HIDキーボード/マウス攻撃 | ✅ | ✅ | ✅ |
| DuckyScript実行 | ✅ | ✅ | ✅ |
| Kali chroot (Metasploit, Nmap等) | ✅ | ✅ | ✅ |
| RNDIS USBテザリング | ✅ | ✅ | ✅ |
| NetHunter KeX (デスクトップ) | ✅ | ✅ | ✅ |
| 内蔵WiFiモニターモード | ❌ | 🔧 パッチ適用可 | ⚠️ 実験的 |
| 内蔵WiFiパケットインジェクション | ❌ | ⚠️ FW制限あり | ❌ |
| 外部USB WiFi (モニター + インジェクション) | ✅ | ✅ | ✅ |
| Bluetooth (Ubertooth) | ✅ | ✅ | ✅ |

## FAQ

### 安全？文鎮化しない？

恒久的な文鎮化のリスクは極めて低い。変更するのはカーネルイメージのみ — パーティションテーブル、ベースバンドファームウェア、ユーザーデータには触れない。カスタムカーネルで起動しなくなった場合、fastboot (電源 + 音量下) で [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) のストックイメージをフラッシュすれば復旧できる。詳細は [復旧手順](guides/ja/troubleshooting.md) を参照。

### 普段使いのスマホとして使い続けられる？

はい。通話、SMS、WiFi (通常モード)、Bluetooth、カメラ、指紋認証、NFC — 全て以前通り動作する。唯一壊れるのはOTAアップデートで、ストックカーネルに戻せば再びアップデート可能。詳細は [カーネルビルド概要](guides/ja/kernel-build-overview.md) を参照。

### Root化は必要？

はい。NetHunterが機能するにはRoot権限 (Magisk, KernelSU, KernelSU Next) が必要。カーネルモジュールのロード、USBガジェット設定、WiFiモード切替にRootが必要。

### モニターモードが❌のデバイスでもNetHunterは使える？

もちろん。WiFiモニターモードは一機能に過ぎない。USB HID攻撃 (BadUSB / DuckyScript)、Metasploit/Nmap/Burp等の完全なKali Linuxツールセット、RNDISネットワーキング、Bluetoothツールはモニターモード無しで動作する。ワイヤレス攻撃には[外部USB WiFiアダプタ](guides/ja/external-wifi.md)を使用できる。

### NetHunter, NetHunter Lite, NetHunter Proの違いは？

| バリアント | 必要なもの | カスタムカーネル | USB HID | WiFiツール |
|-----------|----------|:---:|:---:|:---:|
| **NetHunter Pro** | ブートローダーアンロック + Root + カスタムカーネル | ✅ | ✅ | ✅ (カーネル対応時) |
| **NetHunter (Rootless)** | 不要 | ❌ | ❌ | ❌ |
| **NetHunter Lite** | Rootのみ | ❌ | ❌ | 限定的 |

本プロジェクトは **NetHunter Pro** に焦点を当てている。USB HID攻撃とカスタムカーネル機能をサポートする唯一のバリアントのため。

### ストックに戻せる？

いつでも可能。fastbootで [Nothing Archive](https://spike0en.github.io/nothing_archive/docs/firmware) のストック `init_boot.img` (または `boot.img`) をフラッシュすれば元の状態に戻る。OTAアップデートも再び動作する。

## 参考リンク

### Nothing Archive

本プロジェクトは [**Nothing Archive**](https://spike0en.github.io/nothing_archive/) ([GitHub](https://github.com/spike0en/nothing_archive)) のデータとガイドを基盤としている。Nothing Archiveは Nothing & CMFファームウェア、ガイド、アフターマーケット開発リソースのコミュニティハブ:

- [ブートローダーアンロック / Root / フラッシュガイド](https://spike0en.github.io/nothing_archive/docs/guides)
- [OTAファームウェアダウンロード](https://spike0en.github.io/nothing_archive/docs/firmware) と復旧用[ストックブートイメージ](https://spike0en.github.io/nothing_archive/docs/firmware)
- [公式カーネルソースインデックス](https://spike0en.github.io/nothing_archive/docs/official#kernel-sources)
- [デバイスカタログ](https://spike0en.github.io/nothing_archive/docs/devices) (コードネーム、型番、SoC情報)
- [アフターマーケット開発チャンネル](https://spike0en.github.io/nothing_archive/docs/guides#aftermarket-development)

カスタムカーネルをフラッシュする前に、必ず [Nothing Archiveバックアップガイド](https://spike0en.github.io/nothing_archive/docs/guides#backing-up-essential-partitions) に従ってパーティションをバックアップすること。

### Kali NetHunter

- [Kali NetHunter — 新デバイスへのポーティング](https://www.kali.org/docs/nethunter/porting-nethunter/)
- [Kali NetHunter — Kernel Builder](https://www.kali.org/docs/nethunter/porting-nethunter-kernel-builder/)
- [NetHunter Kernel Patches](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels)
- [NetHunter Project (Installer)](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project)

### 既存のNothing向けNetHunter成果

- [DroidSpace Kernel](https://github.com/ExTV/android_kernel_msm-5.4_nothing_sm7325) — Phone (1)用カスタムカーネル (NetHunter + Docker対応, ExTV作)
- [nethunter-spacewar](https://github.com/ExTV/nethunter-spacewar) — Phone (1) NetHunter Magiskモジュール (ExTV作)

### Upstream WiFiドライバリソース

- [ath12kメーリングリスト](http://lists.infradead.org/pipermail/ath12k/) — WCN7850向けモニターモードパッチ
- [mt76ドライバ (upstream)](https://github.com/openwrt/mt76) — upstream MediaTek WiFiドライバ (gen4mとは別だが参考になる)
- [rtl8812au (aircrack-ng fork)](https://github.com/aircrack-ng/rtl8812au) — Realtek外部USB WiFiドライバ

## コントリビュート

貢献歓迎:

- **ビルドをテストした** — Issue で結果を報告 (成功/失敗、ログ、ファームウェアバージョン)
- **ビルドエラーの修正を見つけた** — PRでエラーの説明と修正を提出
- **新デバイスに対応した** — `guides/` (EN) と `guides/ja/` (JP) にガイドを追加するPRを提出
- **ファームウェア研究** — ❌デバイスのモニターモード有効化に関する発見は貴重

## 免責事項

> 本プロジェクトはNothing Technology LimitedおよびOffensive Security / Kali Linuxとは無関係です。
> カスタムカーネルのフラッシュはデバイスの文鎮化リスクを伴い、OEM保証を無効にします。自己責任で行ってください。
> 変更を加える前に必ず全パーティションをバックアップしてください。
> 本ツールセットは認可されたセキュリティテストおよび教育目的にのみ使用してください。

## ライセンス

MIT
