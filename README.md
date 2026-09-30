# Game Server

自宅用ゲームサーバー環境のDocker構成です。

## 構成

- Minecraft Bedrock Edition Server
- Rust Dedicated Server
- ARK: Survival Ascended Dedicated Server
- Palworld Dedicated Server
- WireGuardを使用したさくらVPS固定IPv4プロキシ

## ネットワーク公開

v6プラス環境から、さくらVPSの固定IPv4を経由してPalworldを公開する構成とインストール手順は、[さくらVPS経由でPalworldを公開する](docs/sakura-vps-palworld-proxy.md)を参照してください。ゲーム別の公開ポートは[ゲーム別プロキシポート](docs/game-proxy-ports.md)で管理します。

Minecraft Bedrock Editionも同じWireGuardトンネルで公開できます。`ports.d/minecraft.ports`を有効にし、VPS側・自宅側の両方で`ENABLED_GAMES=palworld,minecraft`を設定してから、各WireGuard導入スクリプトを再実行してください。VPSのさくらパケットフィルターでは、NetherNetのシグナリング用`19132/tcp`、NetherNetのゲーム通信用`19140-19149/udp`、互換用の`19132/udp`、およびMCXboxBroadcastを使う場合は`30000-30009/udp`を許可します。

## ディレクトリ構造

```
game-server/
├── docker-compose.yml
├── .env
├── games/
│   ├── minecraft/
│   │   ├── data/
│   │   │   └── worlds/  # ワールドデータを配置
│   │   └── ...
│   └── other-game/
│       ├── Dockerfile
│       └── ...
└── shared/
    └── logs/
```

## セットアップ

1. リポジトリをクローン
```bash
git clone <repository-url>
cd game-server
```

2. 環境変数の設定
```bash
cp .env.template .env
# .envファイルを編集して必要な設定を行う
```

3. ワールドデータの配置
```bash
# worldsディレクトリがなければ作成
mkdir -p games/minecraft/data/worlds/

# 既存のワールドデータがある場合、以下のディレクトリにコピー
# games/minecraft/data/worlds/your_world_name/
```

4. サーバーの起動
```bash
docker-compose up -d
```

## 各ゲームサーバーの設定

### Minecraft Bedrock Edition Server
- ポート:
  - 19132/tcp: NetherNetシグナリング
  - 19140-19149/udp: NetherNetゲーム通信（プレイヤーごとに1ポート、`MINECRAFT_PUBLIC_IP`で広告）
  - 19132/udp: IPv4 gameplay（互換用）
  - 19133/udp: IPv6 gameplay（互換用）
  - 30000-30009/udp: MCXboxBroadcast のNetherNet ICE通信
- データディレクトリ: `games/minecraft/data/`
- ワールドデータディレクトリ: `games/minecraft/data/worlds/`
- メモリ設定:
  - 最大: 16GB
  - 予約: 4GB
- 設定可能な環境変数:
  - GAMEMODE: ゲームモード（survival, creative, adventure）
  - DIFFICULTY: 難易度（peaceful, easy, normal, hard）
  - LEVEL_NAME: ワールド名（worldsディレクトリ内のフォルダ名と一致させる）
  - ALLOW_CHEATS: チートの許可（true/false）
  - MAX_PLAYERS: 最大プレイヤー数
  - ONLINE_MODE: オンラインモード（true/false）
  - WHITE_LIST: ホワイトリストの有効化（true/false）

#### 外部から接続する

PC版はBedrock Editionを使用し、サーバー追加画面で`VPS固定IPv4`と`19132`を指定します。Java EditionはこのBedrockサーバーへ直接参加できません。

PlayStation版は任意の外部Bedrockサーバーを手入力する公式機能がないため、WireGuardによる公開だけでは参加できません。この構成ではMCXboxBroadcastが専用Microsoft/Xboxアカウントを参加可能なセッションとして公開します。PS5の利用者はそのアカウントをMicrosoft/Xboxフレンドに追加し、Minecraftの「フレンド」タブから参加します。BDS 1.26.5x以降はNetherNetのみ対応で、接続ごとに別のUDPポートを交渉します。`SERVER_UDP_PORTS`で19140-19149/udpに固定し、`.env`の`MINECRAFT_PUBLIC_IP`（VPS固定IPv4）を広告しないと、VPS経由の参加者は転送後に接続できません。MCXboxBroadcastの認証トークンは`config/mcxboxbroadcast/`に保存され、Git管理の対象外です。

## サーバー管理

### ログの確認
```bash
docker-compose logs minecraft
```

### サーバーの状態確認
```bash
docker-compose ps minecraft
```

### サーバーの再起動
```bash
docker-compose restart minecraft
```

### サーバーの停止
```bash
docker-compose stop minecraft
```

## ワールドデータの管理

### 既存ワールドの移行
1. 既存のワールドデータを`games/minecraft/data/worlds/`ディレクトリにコピー
2. `.env`ファイルの`MINECRAFT_LEVEL_NAME`をワールド名に設定
3. サーバーを再起動

### バックアップ
- ワールドデータは `games/minecraft/data/worlds/` ディレクトリに保存されます
- 定期的なバックアップを推奨します

## 注意事項

1. ファイアウォールで以下のポートが開放されていることを確認してください
   - 19132/tcp (NetherNetシグナリング)
   - 19140-19149/udp (NetherNetゲーム通信)
   - 19132/udp (IPv4互換用)
   - 19133/udp (IPv6互換用)
   - 30000-30009/udp (MCXboxBroadcast ICE)
2. ルーターでポートフォワーディングの設定が必要な場合があります
3. 初回起動時はサーバーの初期化に少し時間がかかる場合があります
4. ワールドデータの権限を適切に設定してください：
```bash
chmod -R 777 games/minecraft/data/worlds/
```
5. サーバーは16GBのメモリを使用可能ですが、ホストマシンのメモリが十分にあることを確認してください

## ライセンス
MIT
