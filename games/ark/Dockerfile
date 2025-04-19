FROM ubuntu:24.04

# 環境変数の設定
ENV GAME_NAME=ARK
ENV GAME_ID=2430930

# ロケールの設定
ENV LANG=ja_JP.UTF-8
ENV LANGUAGE=ja_JP:ja
ENV LC_ALL=ja_JP.UTF-8

# Arguments defining arkuser's uid and gid
ENV         PUID=1001
ENV         PGID=1001


RUN         set -ex; \
            dpkg --add-architecture i386; \
            apt update; \
            apt install -y --no-install-recommends wget curl jq iproute2 procps software-properties-common dbus lib32gcc-s1

# ロケールの設定
RUN apt update && apt install -y locales language-pack-ja && \
    locale-gen ja_JP.UTF-8 && \
    update-locale LANG=ja_JP.UTF-8 && \
    dpkg-reconfigure -f noninteractive locales


# Download steamcmd
RUN         set -ex; \
            mkdir -p /opt/steamcmd; \
            cd /opt/steamcmd; \
            curl "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -


# Uncomment to remove unnecessary files to reduce image size
# REDUCE_IMAGE_SIZE=1

# Various files
ENV         LOG_FILE=/opt/arkserver/ShooterGame/Saved/Logs/ShooterGame.log
ENV         PID_FILE=/opt/arkserver/.server.pid

ENV         STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/arkuser/.steam/steam
ENV         STEAM_COMPAT_DATA_PATH=/home/arkuser/.steam/steam/steamapps/compatdata/${GAME_ID}


# Use users group for unraid
RUN         groupadd -g $PGID arkuser && useradd -d /home/arkuser -u $PUID -g $PGID -G users -m arkuser
RUN         mkdir /opt/arkserver

# Download Proton GE
RUN         set -ex; \
            curl -sLOJ "$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep browser_download_url | cut -d\" -f4 | egrep .tar.gz)"; \
            tar -xzf GE-Proton*.tar.gz -C /usr/local/bin/ --strip-components=1; \
            rm GE-Proton*.*

# Proton Fix machine-id
RUN         set -ex; \
            rm -f /etc/machine-id; \
            dbus-uuidgen --ensure=/etc/machine-id; \
            rm /var/lib/dbus/machine-id; \
            dbus-uuidgen --ensure

# Install rcon
RUN         set -ex; \
            cd /tmp/; \
            curl -sSL https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz > rcon.tar.gz; \
            tar xvf rcon.tar.gz; \
            mv rcon-0.10.3-amd64_linux/rcon /usr/local/bin/

ENV         TINI_VERSION=v0.19.0

# Install tini
ARG         TINI_VERSION
ADD         https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN         chmod +x /tini

# Set permissions
RUN         set -ex; \
            chown -R arkuser:arkuser /opt/arkserver; \
            chown -R arkuser:arkuser /opt/steamcmd

COPY --chown=arkuser --chmod=755 ./scripts/start.sh /opt/start.sh
COPY --chown=arkuser --chmod=755 ./scripts/manager /opt/manager
RUN         ln -s /opt/manager/manager.sh /usr/local/bin/manager

USER        arkuser
WORKDIR     /opt/arkserver/

#on startup enter start.sh script
ENTRYPOINT ["/tini", "--", "/opt/start.sh"]

# ボリュームの設定
VOLUME ["/steamcmd/games/ARK", "/backup"]
