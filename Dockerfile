# syntax=docker/dockerfile:experimental

FROM scratch AS packages
COPY release-packages/code-server*.deb /tmp/

FROM debian:11

RUN apt-get update \
 && apt-get install -y \
    curl \
    dumb-init \
    zsh \
    htop \
    locales \
    man \
    nano \
    git \
    git-lfs \
    procps \
    openssh-client \
    sudo \
    vim.tiny \
    lsb-release \
    gnupg \
  && git lfs install \
  && rm -rf /var/lib/apt/lists/*

# Developer tools

# Java
RUN apt-get update && apt-get -y install openjdk-11-jdk maven gradle

# Python
RUN apt-get install -y python3 python3-pip && \
  update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Go
ENV GO_VERSION=1.18.3 \
    GOOS=linux \
    GOARCH="$(dpkg --print-architecture)" \
    GOROOT=/usr/local/go \
    GOPATH=/usr/local/go-packages
ENV PATH=$GOROOT/bin:$GOPATH/bin:$PATH

RUN curl -fsSL https://storage.googleapis.com/golang/go$GO_VERSION.$GOOS-$GOARCH.tar.gz | tar -C /usr/local -xzv

ENV PATH=$PATH:$GOPATH/bin

# CMake
ARG CMAKE_VERSION=3.23.2

RUN CMakeARCH="$(uname -m)" && \
    wget "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-$CMakeARCH.sh" && \
    chmod a+x cmake-$CMAKE_VERSION-linux-$CMakeARCH.sh && \
    ./cmake-$CMAKE_VERSION-linux-$CMakeARCH.sh --prefix=/usr/ --skip-license && \
    rm cmake-$CMAKE_VERSION-linux-$CMakeARCH.sh

# C/C++
# public LLVM PPA, stable version of LLVM
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

# https://wiki.debian.org/Locale#Manually
RUN sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen \
  && locale-gen
ENV LANG=en_US.UTF-8

RUN adduser --gecos '' --disabled-password coder && \
  echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

RUN ARCH="$(dpkg --print-architecture)" && \
    curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-$ARCH.tar.gz" | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

COPY ./entrypoint.sh /usr/bin/entrypoint.sh
RUN --mount=from=packages,src=/tmp,dst=/tmp/packages dpkg -i /tmp/packages/code-server*$(dpkg --print-architecture).deb

# Allow users to have scripts run on container startup to prepare workspace.
# https://github.com/coder/code-server/issues/5177
ENV ENTRYPOINTD=${HOME}/entrypoint.d

EXPOSE 8080
# This way, if someone sets $DOCKER_USER, docker-exec will still work as
# the uid will remain the same. note: only relevant if -u isn't passed to
# docker-run.
USER 1000
ENV USER=coder
WORKDIR /home/coder
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]