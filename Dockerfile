FROM ubuntu:jammy as builder

ARG GUACD_VERSION=1.5.0
RUN apt-get update && \
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


FROM ubuntu:jammy

RUN apt update && \
	apt install -q -y --no-install-recommends guacd supervisor xrdp xfce4 xfce4-goodies curl pulseaudio

