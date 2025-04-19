#!/bin/bash
set -e

# SteamCMDの更新
echo "Updating SteamCMD..."
/steamcmd/steamcmd.sh +quit

# ゲームのインストール/更新
if [ -n "$GAME_ID" ] && [ -n "$GAME_NAME" ]; then
    echo "Installing/Updating $GAME_NAME..."
    /steamcmd/steamcmd.sh \
        +force_install_dir /steamcmd/games/$GAME_NAME \
        +login anonymous \
        +app_update $GAME_ID \
        +quit
fi

# カスタムスクリプトの実行
if [ -f "/steamcmd/games/$GAME_NAME/scripts/start.sh" ]; then
    echo "Running custom start script..."
    chmod +x /steamcmd/games/$GAME_NAME/scripts/start.sh
    exec /steamcmd/games/$GAME_NAME/scripts/start.sh
else
    # デフォルトの起動コマンド
    echo "Starting game server..."
    exec /steamcmd/games/$GAME_NAME/$GAME_NAME
fi 