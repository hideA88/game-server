FROM game-server-base:latest

# 環境変数の設定
ENV GAME_NAME=Rust
ENV GAME_ID=258550
ENV GAME_PARAMS="-batchmode -nographics -logfile /steamcmd/games/Rust/server.log +server.port 28015 +server.queryport 28017 +rcon.port 28016 +rcon.password ${RCON_PASSWORD:-changeme} +server.hostname \"${SERVER_NAME}\" +server.description \"${SERVER_DESCRIPTION}\" +server.maxplayers ${MAX_PLAYERS:-50} +server.worldsize ${WORLD_SIZE:-3000} +server.seed ${SEED:-0} +server.saveinterval ${SAVE_INTERVAL:-300}"

# ロケールの設定
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
RUN apt update && apt install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# ボリュームの設定
VOLUME ["/steamcmd/games/Rust", "/backup"]
