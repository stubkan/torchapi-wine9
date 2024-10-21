FROM debian:bookworm-20240513-slim

WORKDIR /root

# ARG only available during build
# never env DEBIAN_FRONTEND=noninteractive !!
ARG DEBIAN_FRONTEND=noninteractive
ARG WINEBRANCH=stable
ARG WINEVERSION=9.0.0.0~bookworm-1

ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV WINEPREFIX=/root/server
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

RUN \
  dpkg --add-architecture i386 && \
  apt-get -qq -y update && \
  apt-get upgrade -y -qq && \
  apt-get install -y -qq software-properties-common curl gnupg2 wget && \
  # add repository keys
  mkdir -pm755 /etc/apt/keyrings && \
  wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
  # add repositories
  echo "deb http://ftp.debian.org/debian bookworm main non-free" > /etc/apt/sources.list.d/non-free.list && \
  wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
  apt-get install -y procps htop winbind x11vnc net-tools openbox
RUN \
  apt-get update -qq && \
  echo steam steam/question select "I AGREE" | debconf-set-selections && \
  echo steam steam/license note '' | debconf-set-selections && \
  apt-get install -qq -y \
  libfaudio0:i386 \
  libfaudio0 
RUN \ 
  apt-get install -qq -y --install-recommends \
  winehq-${WINEBRANCH}=${WINEVERSION} \
  wine-${WINEBRANCH}-i386=${WINEVERSION} \
  wine-${WINEBRANCH}-amd64=${WINEVERSION} \
  wine-${WINEBRANCH}=${WINEVERSION} \
  steamcmd \
  xvfb \
  cabextract && \
  curl -L https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks > /usr/local/bin/winetricks && \
  chmod +x /usr/local/bin/winetricks 

# Winetricks (This block uses most of the build time)
RUN \
  adduser wine && \
  mkdir /scripts
COPY ./winetricks.sh /scripts
RUN \
  chmod +x /scripts/winetricks.sh && \
  mkdir /wineprefix /app  && \
  chown -R wine:wine /wineprefix /app

WORKDIR /app
RUN \
  runuser -u wine -- bash -c 'WINEARCH=win64 WINEPREFIX=/wineprefix /scripts/winetricks.sh' && \

  # Remove stuff we do not need anymore to reduce docker size
  apt-get remove -qq -y \
  gnupg2 \
  software-properties-common && \
  apt-get autoremove -qq -y && \
  apt-get -qq clean autoclean && \
  rm -rf /var/lib/{apt,dpkg,cache,log}/
  
COPY entrypoint.sh /root/
ENTRYPOINT /root/entrypoint.sh

