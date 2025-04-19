#!/bin/bash


# サーバーディレクトリに移動
cd /steamcmd/games/Rust

# サーバー設定の確認
echo "Starting Rust server with the following settings:"
echo "Server Name: ${SERVER_NAME}"
echo "Server Description: ${SERVER_DESCRIPTION}"
echo "Max Players: ${MAX_PLAYERS}"
echo "World Size: ${WORLD_SIZE}"
echo "Seed: ${SEED}"
echo "Save Interval: ${SAVE_INTERVAL}"

# サーバー起動
exec ./RustDedicated \
    -batchmode \
    -nographics \
    -logfile /steamcmd/games/Rust/server.log \
    +server.port 28015 \
    +server.queryport 28017 \
    +rcon.port 28016 \
    +rcon.password "${RCON_PASSWORD:-changeme}" \
    +server.hostname "${SERVER_NAME}" \
    +server.description "${SERVER_DESCRIPTION}" \
    +server.maxplayers "${MAX_PLAYERS:-50}" \
    +server.worldsize "${WORLD_SIZE:-3000}" \
    +server.seed "${SEED:-0}" \
    +server.saveinterval "${SAVE_INTERVAL:-300}" 