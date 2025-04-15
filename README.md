# Game Server

自宅用ゲームサーバー環境のDocker構成です。

## 構成

- Minecraft Bedrock Edition Server
- その他のゲームサーバー（予定）

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
cp .env.example .env
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
  - 19132/udp: IPv4 gameplay
  - 19133/udp: IPv6 gameplay
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
   - 19132/udp (IPv4)
   - 19133/udp (IPv6)
2. ルーターでポートフォワーディングの設定が必要な場合があります
3. 初回起動時はサーバーの初期化に少し時間がかかる場合があります
4. ワールドデータの権限を適切に設定してください：
```bash
chmod -R 777 games/minecraft/data/worlds/
```
5. サーバーは16GBのメモリを使用可能ですが、ホストマシンのメモリが十分にあることを確認してください

## ライセンス
MIT
