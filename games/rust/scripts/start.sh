#!/bin/bash
set -e

# サーバー設定の生成
cat > /steamcmd/games/Rust/server.cfg << EOF
server.hostname "${SERVER_NAME:-Rust Server}"
server.description "${SERVER_DESCRIPTION:-Rust Server}"
server.url "${SERVER_URL:-}"
server.headerimage "${SERVER_HEADER_IMAGE:-}"
server.worldsize "${WORLD_SIZE:-4000}"
server.seed "${SEED:-12345}"
server.maxplayers "${MAX_PLAYERS:-50}"
server.saveinterval "${SAVE_INTERVAL:-300}"
EOF

# サーバーの起動
exec /steamcmd/games/Rust/RustDedicated \
    -batchmode \
    -nographics \
    -logfile /steamcmd/games/Rust/logs/server.log \
    -config /steamcmd/games/Rust/server.cfg 