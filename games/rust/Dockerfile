FROM game-server-base:latest

# 環境変数の設定
ENV GAME_ID=258550
ENV GAME_NAME=Rust

# カスタムスクリプトの追加
COPY scripts/start.sh /steamcmd/games/Rust/scripts/start.sh
RUN chmod +x /steamcmd/games/Rust/scripts/start.sh

# ポートの公開
EXPOSE 28015/udp 28016/udp 28017/udp

# ボリュームの設定
VOLUME ["/steamcmd/games/Rust"] 