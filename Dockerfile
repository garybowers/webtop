#########################################
### Build guacd 
#########################################
FROM ubuntu:jammy as guacdbuilder

ENV DEBIAN_FRONTEND=noninteractive
ARG GUACD_VERSION=1.5.0
RUN apt-get update -yq && \
    apt-get install -yq --no-install-recommends \
        ca-certificates \
	autoconf \
	automake \
	checkinstall \
	freerdp2-dev \
	g++ \
	gcc \
	git \
	libavcodec-dev \
	libavutil-dev \
	libcairo2-dev \
	libjpeg-turbo8-dev \
	libogg-dev \
	libossp-uuid-dev \
	libpulse-dev \
	libssl-dev \
	libswscale-dev \
	libtool \
	libvorbis-dev \
	libwebsockets-dev \
	libwebp-dev \
	make

RUN mkdir -p /tmp/guacd && \
    git clone https://github.com/apache/guacamole-server.git /tmp/guacd && \
    cd /tmp/guacd && \
    git checkout ${GUACD_VERSION} && \
    autoreconf -fi && \
    ./configure --prefix=/usr && \
    make -j 4 && \
    mkdir -p /tmp/out && \
    PREFIX=/usr checkinstall -y -D --nodoc --pkgname guacd --pkgversion "${GUACD_VERSION}" --pakdir /tmp --exclude "/usr/share/man","/usr/include","/etc" && \
    mv /tmp/guacd_${GUACD_VERSION}-*.deb /tmp/out/guacd_${GUACD_VERSION}.deb

#########################################
### Build Web Client
#########################################

FROM ubuntu:focal as nodebuilder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq && \
    apt-get install -y \
	gnupg \
	curl && \
     curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
     echo 'deb https://deb.nodesource.com/node_14.x focal main'	> /etc/apt/sources.list.d/nodesource.list && \
     apt-get update && \
     apt-get install -yq --no-install-recommends \
	g++ \
	gcc \
	libpam0g-dev \
	make \
	nodejs

RUN mkdir -p /gclient && \
    curl -o /tmp/gclient.tar.gz -L "https://github.com/linuxserver/gclient/archive/1.1.2.tar.gz" && \
    tar xf /tmp/gclient.tar.gz -C /gclient/ --strip-components=1 && \
    cd /gclient && \
    npm install


#########################################
### Build XRDP
#########################################

FROM ubuntu:focal as xrdpbuilder

ARG XRDP_PULSE_VERSION=v0.7
ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list && \
    apt update && \
    apt install -qy \
	build-essential \
	devscripts \
	dpkg-dev \
	git \
	libpulse-dev \
	pulseaudio && \
    apt build-dep -y \
    	pulseaudio \
	xrdp

RUN mkdir -p /buildout/var/lib/xrdp-pulseaudio-installer && \
    tmp=$(mktemp -d); cd "$tmp" && \
    pulseaudio_version=$(dpkg-query -W -f='${source:Version}' pulseaudio|awk -F: '{print $2}') && \
    pulseaudio_upstream_version=$(dpkg-query -W -f='${source:Upstream-Version}' pulseaudio) && \
    set -- $(apt-cache policy pulseaudio | fgrep -A1 '***' | tail -1) && \
    mirror=$2 && \
    suite=${3#*/} && \
    dget -u "$mirror/pool/$suite/p/pulseaudio/pulseaudio_$pulseaudio_version.dsc" && \
    cd "pulseaudio-$pulseaudio_upstream_version" && \
    ./configure && \
    cd - && \
    git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git && \
    cd pulseaudio-module-xrdp && \
    git checkout ${XRDP_PULSE_VERSION} && \
    ./bootstrap && \ 
    ./configure PULSE_DIR="$tmp/pulseaudio-$pulseaudio_upstream_version" && \
    make -j 2 && \
    install -t "/buildout/var/lib/xrdp-pulseaudio-installer" -D -m 644 src/.libs/*.so

RUN cd /tmp && \
    apt-get source xrdp && \
    cd xrdp-* && \
    sed -i 's/--enable-fuse/--disable-fuse/g' debian/rules && \
    debuild -b -uc -us && \
    cp -ax ../xrdp_*.deb /buildout/xrdp.deb

#########################################
### Build Desktop Base
#########################################

FROM ubuntu:jammy as webtopbase

ARG GUACD_VERSION=1.5.0
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=guacdbuilder /tmp/out /tmp/out
COPY --from=nodebuilder /gclient /usr/local/gclient
COPY --from=xrdpbuilder /buildout /tmp/out

RUN apt update && \
    apt install -qy \ 
	apt-transport-https \
	apt-utils \
	ca-certificates \
	curl \
	dbus-x11 \
	gawk \
	gnupg2 \
	libfuse2 \
	libx11-dev \
	libxfixes3 \
	libxml2 \
	libssl-dev \
	libxrandr2 \
	openssh-client \
	pulseaudio \
	software-properties-common \
	sudo \
	x11-apps \
	x11-xserver-utils \
	xfonts-base \
	xorgxrdp \
	xrdp \
	xserver-xorg-core \
	xserver-xorg-video-intel \
	xserver-xorg-video-amdgpu \
	xserver-xorg-video-ati \
	xutils \
	zlib1g \
	lsb-release \
	libcairo2-dev \
        xterm \
        libfreerdp2-2 \
	libfreerdp-client2-2 \
	libossp-uuid16 \
        obconf \
	openbox \
        wget

RUN curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_14.x jammy main' > /etc/apt/sources.list.d/nodesource.list && \
    echo 'deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_14.x jammy main' >> /etc/apt/sources.list.d/nodesource.list && \
    apt update -y && \
    apt install -qy nodejs && \
    cd /tmp && \
    wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1-1ubuntu2.1~18.04.21_amd64.deb && \
    dpkg -i libssl1.1_1.1.1-1ubuntu2.1~18.04.21_amd64.deb && \
    dpkg -i /tmp/out/xrdp.deb && \
    dpkg -i /tmp/out/guacd_${GUACD_VERSION}.deb && \
    WEBSOCAT_RELEASE=$(curl -sX GET "https://api.github.com/repos/vi/websocat/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]'); \
    curl -o /usr/bin/websocat -fL "https://github.com/vi/websocat/releases/download/${WEBSOCAT_RELEASE}/websocat.x86_64-unknown-linux-musl" && \
    chmod +x /usr/bin/websocat && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* \
           /var/tmp/* \
           /tmp/*
    
EXPOSE 3000

FROM webtopbase

RUN apt update && \
    apt install -yq --no-install-recommends \
	supervisor \
	vim \
	git \
        dolphin \
        kate \
        kubuntu-desktop \
        konsole \
        kmix \
        firefox

ADD /root /
