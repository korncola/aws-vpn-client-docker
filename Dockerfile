FROM ubuntu:20.04 as builder

ARG openvpn_version="2.5.1"
ARG resolv_version="master"

WORKDIR /

RUN apt-get update && \
    apt-get install -y \
    curl \
    unzip \
    build-essential \
    autoconf \
    libgnutls28-dev \
    libgnutls28-dev \
    liblzo2-dev \
    libpam0g-dev \
    libtool \
    libssl-dev \
    net-tools

RUN curl -L https://github.com/OpenVPN/openvpn/archive/v${openvpn_version}.zip -o openvpn.zip && \
    unzip openvpn.zip && \
    mv openvpn-${openvpn_version} openvpn

COPY openvpn-v${openvpn_version}-aws.patch openvpn

RUN cd openvpn && \
    patch -p1 < openvpn-v${openvpn_version}-aws.patch && \
    autoreconf -i -v -f && \
    ./configure && \
    make

RUN curl -L https://golang.org/dl/go1.15.4.linux-amd64.tar.gz -o go.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz

ENV PATH=$PATH:/usr/local/go/bin

COPY server.go .

RUN go build server.go

RUN curl -L https://github.com/cmadamsgit/update-systemd-resolved/archive/refs/heads/${resolv_version}.zip -o update-systemd-resolved.zip && \
    unzip update-systemd-resolved.zip && \
    mv /update-systemd-resolved-${resolv_version} /update-systemd-resolved

FROM ubuntu:20.04

ENV TZ="America/Sao_Paulo"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get install -y \
    dnsutils \
    liblzo2-dev \
    openssl \
    net-tools

COPY --from=builder /openvpn/src/openvpn/openvpn /openvpn
COPY --from=builder /server /server
COPY entrypoint.sh /

#COPY update-resolv-conf /etc/openvpn/scripts/
RUN apt-get install -y --no-install-recommends systemd iproute2
COPY --from=builder /update-systemd-resolved/update-systemd-resolved /etc/openvpn/scripts/update-resolv-conf

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
