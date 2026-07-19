# さくらVPS経由でゲームサーバーを公開する

## 目的と構成

GMO光アクセスのv6プラス環境にある自宅ゲームサーバーから、固定IPv4を持つさくらVPSへWireGuardトンネルを常時接続します。VPSの固定IPv4で受けたゲーム通信を、自宅のゲームサーバーへ転送します。現在はPalworldだけを有効化します。

自宅側からVPSへWireGuard接続を開始するため、自宅側のIPv4アドレスが変化してもDDNSは不要です。

```text
友人のPalworldクライアント
        |
        | VPS_PUBLIC_IP:9680/udp
        v
さくらVPS public NIC
        |
        | nftables DNAT + SNAT
        v
  wg0: 10.77.0.1/30
        |
        | WireGuard (51820/udp)
        v
自宅 game-server wg0: 10.77.0.2/30
        |
        | Docker published ports 9680-9681/udp
        v
  palworld-server
```

VPSでSNATも行うため、自宅側にインターネット向けのポリシールーティングは追加しません。この簡易構成では、Palworldから見た接続元IPがVPSのWireGuardアドレスになる場合があります。

## 公開するポート

| 場所 | プロトコル/ポート | 用途 |
| --- | --- | --- |
| VPS | UDP 51820 | WireGuard待受 |
| VPS | UDP 9680 | Palworldゲーム通信 |
| VPS | UDP 9681 | Palworld Query通信 |
| 自宅 | UDP 9680/9681 | WireGuard内からPalworldへ転送 |

Palworld REST APIの8212/TCPとRCONはインターネットへ公開しません。
ゲームごとのポート定義、Rustの追加方法、用途一覧は[ゲーム別プロキシポート](game-proxy-ports.md)を参照してください。

## 前提

- VPSと自宅ゲームサーバーの両方がUbuntuまたはDebian系Linuxであること
- 両方で`sudo`を使用できること
- VPSへSSH接続できること
- 自宅ゲームサーバー上でPalworldが`9680/udp`と`9681/udp`を待ち受けていること
- VPSの固定IPv4が分かっていること
- VPS上の既存ファイアウォール構成を把握していること

スクリプトはWireGuard、nftables、wireguard-toolsをAPTでインストールします。

## 秘密情報の扱い

次の情報はGitへコミットしません。

- `infra/wireguard/vps.env`
- `infra/wireguard/home.env`
- WireGuard秘密鍵とPresharedKey
- 生成済みの`wg0.conf`

秘密鍵は各ホストの`/etc/wireguard/<interface>.key`に生成されます。秘密鍵をホスト間でコピーしないでください。相手へ渡すのは`.pub`の公開鍵だけです。

```bash
chmod 600 infra/wireguard/vps.env
chmod 600 infra/wireguard/home.env
```

## セットアップの流れ

1. VPSを初期化し、VPS公開鍵を取得
2. VPS公開鍵を使って自宅側を設定し、自宅公開鍵を取得
3. 自宅公開鍵をVPSへ設定
4. トンネルとポート転送を検証
5. 家庭外の回線からPalworldへ接続

## 1. VPS側の準備

VPSへこのリポジトリを配置し、envサンプルをコピーします。

```bash
cp infra/wireguard/vps.env.example infra/wireguard/vps.env
chmod 600 infra/wireguard/vps.env
```

`vps.env`を編集します。

```dotenv
WG_INTERFACE=wg0
WG_PORT=51820
WG_VPS_ADDRESS=10.77.0.1/30
WG_HOME_ADDRESS=10.77.0.2/32
VPS_PUBLIC_INTERFACE=
ENABLED_GAMES=palworld
HOME_PUBLIC_KEY=
MANAGE_UFW=false
```

`VPS_PUBLIC_INTERFACE`が空なら、デフォルトルートから自動判定します。既存のUFWをこのスクリプトから変更する場合だけ`MANAGE_UFW=true`にします。

```bash
sudo scripts/wireguard/install-vps.sh infra/wireguard/vps.env
```

このスクリプトはパッケージ導入、鍵生成、IPv4 forwarding、DNAT/SNAT、systemd自動起動、既存設定のバックアップを行います。表示されたVPS公開鍵を控えます。後から確認する場合は次を実行します。

```bash
sudo cat /etc/wireguard/wg0.pub
```

## 2. さくらVPSのパケットフィルター

さくらVPSコントロールパネルのパケットフィルターを利用する場合は、少なくとも次を許可します。

- SSH: 現在利用しているTCPポート
- WireGuard: UDP 51820
- Palworld: UDP 9680
- Palworld Query: UDP 9681
公開対象は `scripts/wireguard/list-ports.sh infra/wireguard/vps.env` でゲーム名・用途付きの一覧として確認できます。

さくらVPSのパケットフィルターはIPv4のみが対象です。OS側のUFWやnftablesと併用する場合、両方で通信が許可されている必要があります。

SSHの許可を確認する前に既存ファイアウォールを有効化・初期化しないでください。スクリプトは既存nftablesルールをflushせず、専用の`inet game_proxy`テーブルだけを管理します。

## 3. 自宅game-server側の準備

```bash
cp infra/wireguard/home.env.example infra/wireguard/home.env
chmod 600 infra/wireguard/home.env
```

`home.env`へVPSの固定IPv4と、手順1で取得したVPS公開鍵を設定します。

```dotenv
WG_INTERFACE=wg0
WG_HOME_ADDRESS=10.77.0.2/30
WG_VPS_ADDRESS=10.77.0.1/32
WG_PORT=51820
WG_MTU=1380
VPS_PUBLIC_IP=203.0.113.10
VPS_PUBLIC_KEY=REPLACE_WITH_VPS_PUBLIC_KEY
ENABLED_GAMES=palworld
MANAGE_UFW=false
```

`203.0.113.10`は例示用アドレスなので、実際のVPS固定IPv4へ置き換えます。

```bash
sudo scripts/wireguard/install-home.sh infra/wireguard/home.env
sudo cat /etc/wireguard/wg0.pub
```

自宅側のスクリプトも、WireGuardからDocker公開ポートへ転送できるようにIPv4 forwardingを有効化します。自宅側はVPSの固定IPv4へ接続し、`PersistentKeepalive = 25`でNATマッピングを維持します。通常のインターネット通信はWireGuardへ流さず、従来のデフォルトルートを使います。

自宅側でUFWを使用している場合に`MANAGE_UFW=true`を設定すると、スクリプトはWireGuardからDocker公開ポートへ届く転送通信を`ufw route allow`で許可します。UFW以外のファイアウォールを使用している場合は、同等のFORWARD許可を別途設定してください。

## 4. VPSへ自宅peerを登録

VPS側の`infra/wireguard/vps.env`で、自宅側公開鍵を設定します。

```dotenv
HOME_PUBLIC_KEY=REPLACE_WITH_HOME_PUBLIC_KEY
```

VPS側で次を実行します。

```bash
sudo scripts/wireguard/configure-vps-peer.sh infra/wireguard/vps.env
```

WireGuardは対等なpeerですが、この構成ではVPSが待受側、自宅サーバーが接続開始側です。自宅側の変動するグローバルIPv4をVPSへ設定する必要はありません。

## 5. 動作確認

VPS側:

```bash
sudo scripts/wireguard/verify-vps.sh infra/wireguard/vps.env
```

自宅側:

```bash
sudo scripts/wireguard/verify-home.sh infra/wireguard/home.env
```

`wg show`で`latest handshake`が最近の時刻であり、送受信バイト数が増えることを確認します。

VPSでパケットを確認する場合:

```bash
sudo tcpdump -ni any 'udp port 51820 or udp port 9680 or udp port 9681'
```

自宅側:

```bash
sudo tcpdump -ni wg0 'udp port 9680 or udp port 9681'
```

最終確認は携帯テザリングなど家庭外のIPv4回線から行います。

```text
VPSの固定IPv4:9680
```

家庭内LANからVPS固定IPv4へ接続するだけでは外部経路やVPSパケットフィルターを完全には検証できないため、必ず別回線でも確認します。

## 再起動と日常運用

```bash
sudo systemctl status wg-quick@wg0
sudo systemctl restart wg-quick@wg0
sudo wg show
```

VPSのnftablesルール:

```bash
sudo nft list table inet game_proxy
sudo systemctl status game-proxy-nftables.service
```

## トラブルシューティング

### handshakeがない

1. 自宅側の`VPS_PUBLIC_IP`と`VPS_PUBLIC_KEY`を確認
2. VPS側で51820/UDPが許可されているか確認
3. VPSで`sudo ss -ulnp | grep 51820`を確認
4. 双方の`AllowedIPs`を確認
5. 双方の時刻同期を確認

### handshakeはあるがPalworldへ接続できない

1. 自宅LAN内からPalworldへ接続できることを再確認
2. 自宅側で`sudo scripts/wireguard/verify-home.sh infra/wireguard/home.env`を実行し、すべてのポートが待受中であることを確認
3. VPSのnftables counterが増えるか確認
4. VPSと自宅の両方でtcpdumpを取得
5. UFWが有効なら`sudo ufw status verbose`と`sudo ufw status routed`を確認

### 通信が不安定

`WG_MTU=1380`を初期値としています。断片化が疑われる場合は1280から1420の範囲で調整します。VPSのCPU、帯域、パケットロスも確認します。

## 再実行と切り戻し

スクリプトは再実行可能です。既存設定は変更前に`.bak.<UTC timestamp>`としてバックアップされます。

```bash
# VPS基本設定・NAT変更
sudo scripts/wireguard/install-vps.sh infra/wireguard/vps.env

# VPS peer公開鍵変更
sudo scripts/wireguard/configure-vps-peer.sh infra/wireguard/vps.env

# 自宅側設定変更
sudo scripts/wireguard/install-home.sh infra/wireguard/home.env
```

誤操作を防ぐため、自動アンインストールスクリプトは用意していません。切り戻す場合はSSH接続を維持したまま実施します。

```bash
sudo systemctl disable --now wg-quick@wg0
sudo systemctl disable --now game-proxy-nftables.service
```

専用サービスの停止時に`inet game_proxy`テーブルも削除されます。完全に削除する場合は、停止後に次の専用ファイルだけを削除します。

```bash
sudo rm /etc/systemd/system/game-proxy-nftables.service
sudo rm /usr/local/sbin/apply-game-proxy-nftables
sudo rm /etc/nftables.d/game-proxy.nft
sudo systemctl daemon-reload
```

`net.ipv4.ip_forward`をDockerや別VPNが利用している可能性があるため、用途を確認せず無効化しないでください。WireGuardを停止しても、自宅LAN内のPalworldとセーブデータには影響しません。

## セキュリティ上の注意

- WireGuard秘密鍵をGit、チャット、共有ストレージへ載せない
- VPSのSSHは公開鍵認証を使う
- Palworldのサーバー・管理パスワードを定期的に変更する
- REST API 8212/TCPを公開しない
- さくらVPSのパケットフィルターはIPv6を保護しないため、IPv6もOS側で確認する
- 鍵が漏洩した場合は該当peerの鍵を再生成し、両側の公開鍵を更新する

## 参考資料

- [GMOとくとくBB: v6プラスとMAP-E](https://help.gmobb.jp/faq/faq_detail.html?id=1021042)
- [GMOとくとくBB: v6プラスの固定IP](https://help.gmobb.jp/faq/faq_detail.html?id=1021010)
- [さくらのVPS: パケットフィルター](https://manual.sakura.ad.jp/vps/network/packetfilter.html)
- [Ubuntu Server: WireGuard VPN](https://documentation.ubuntu.com/server/how-to/wireguard-vpn/)
- [Ubuntu Server: WireGuard troubleshooting](https://ubuntu.com/server/docs/wireguard-vpn-troubleshooting/)
