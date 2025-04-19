FROM ubuntu:24.04

# マルチアーキテクチャのサポートを有効化
RUN dpkg --add-architecture i386 && \
    apt update && \
    apt install -y \
    lib32gcc-s1 \
    lib32stdc++6 \
    libsdl2-2.0-0 \
    libsdl2-2.0-0:i386 \
    curl \
    wget \
    tar \
    bzip2 \
    gzip \
    unzip \
    less \
    && rm -rf /var/lib/apt/lists/*

# SteamCMDのインストール
RUN mkdir -p /steamcmd \
    && cd /steamcmd \
    && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# ワークディレクトリの設定
WORKDIR /steamcmd

# 環境変数の設定
ENV STEAMCMD_HOME=/steamcmd
ENV PATH=$PATH:$STEAMCMD_HOME

# スクリプトの追加
COPY scripts/entrypoint.sh /steamcmd/entrypoint.sh
RUN chmod +x /steamcmd/entrypoint.sh

# ボリュームの設定
VOLUME ["/steamcmd/games"]

# エントリーポイントの設定
ENTRYPOINT ["/steamcmd/entrypoint.sh"] 