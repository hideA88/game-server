# ゲーム別プロキシポート

WireGuardトンネルは全ゲームで共用し、VPSから自宅へ転送するポートだけをゲーム別ファイルで管理します。

## ファイル構成

```text
infra/wireguard/ports.d/
├── palworld.ports
└── rust.ports
```

各行は次の4項目です。

```text
protocol  vps_public_port  home_server_port  purpose
```

Palworldの定義:

```text
# protocol  public_port  home_port  purpose
udp  9680  9680  gameplay
udp  9681  9681  query
```

Rustの定義:

```text
# protocol  public_port  home_port  purpose
udp  5584  5584  gameplay
tcp  5584  5584  optional-tcp
udp  5585  5585  query
```

`purpose`はnftablesのルールコメント、UFWのコメント、一覧表示に使用されます。英数字、ピリオド、コロン、アンダースコア、ハイフンを使用できます。RustのRCON 5586/TCPは管理用なので、標準の公開定義には含めていません。

## ゲームの有効化

VPSと自宅の両方のenvで、同じ`ENABLED_GAMES`を指定します。

Palworldのみ:

```dotenv
ENABLED_GAMES=palworld
```

PalworldとRust:

```dotenv
ENABLED_GAMES=palworld,rust
```

現在の公開予定を確認します。

```bash
scripts/wireguard/list-ports.sh infra/wireguard/vps.env
```

出力例:

```text
GAME         PROTOCOL VPS_PORT     HOME_PORT  PURPOSE
palworld     udp      9680         9680       gameplay
palworld     udp      9681         9681       query
rust         udp      5584         5584       gameplay
rust         tcp      5584         5584       optional-tcp
rust         udp      5585         5585       query
```

この一覧を、さくらVPSのパケットフィルター設定時のチェックリストとしても使用します。

## ゲームを追加する

例として`example-game`を追加する場合:

```bash
cp infra/wireguard/ports.d/palworld.ports infra/wireguard/ports.d/example-game.ports
```

実際のポートと用途へ編集し、両方のenvへゲーム名を追加します。

```dotenv
ENABLED_GAMES=palworld,example-game
```

VPSと自宅でそれぞれインストールスクリプトを再実行します。

```bash
# VPS
sudo scripts/wireguard/install-vps.sh infra/wireguard/vps.env

# 自宅
sudo scripts/wireguard/install-home.sh infra/wireguard/home.env
```

VPS側ではゲーム名と用途を含むnftablesルールが再生成されます。指定していないポートは追加されません。

## 注意事項

- VPS側と自宅側の`ENABLED_GAMES`を一致させる
- Docker Composeで自宅ホストに公開しているポートと`home_port`を一致させる
- さくらVPSのパケットフィルターにも`vps_public_port`を追加する
- REST APIやRCONなど、インターネット公開が不要な管理ポートは定義しない
- RCONを公開する場合は送信元IP制限などの追加保護を行う
- 使わなくなったゲームは`ENABLED_GAMES`から削除し、VPSスクリプトを再実行する
