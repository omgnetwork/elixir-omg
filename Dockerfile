FROM ubuntu:18.04

MAINTAINER Jake Bunce <jake@omise.co>

ARG USER=elixir-user
ARG GROUP=elixir-user
ARG UID=1000
ARG GID=1000
ARG HOME=/home/$USER

RUN groupadd --gid "${GID}" "${USER}" && \
    useradd \
      --uid ${UID} \
      --gid ${GID} \
      --create-home \
      --shell /bin/bash \
      ${USER}

ARG BUILD_PACKAGES="build-essential autoconf libtool libgmp3-dev libssl-dev wget gettext cmake"

RUN apt-get update \
  && apt-get install -y software-properties-common \
  && add-apt-repository -y ppa:ethereum/ethereum \
  && apt-get update \
  && apt-get install -y $BUILD_PACKAGES \
  sudo \
  git \
  python3-pip \
  python3-dev \
  curl \
  sysstat \
  bpfcc-tools

RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb \
  && dpkg -i erlang-solutions_1.0_all.deb \
  && apt-get update \
  && apt-get install -y esl-erlang=1:21.2.3-1 \
  elixir=1.8.0-1

RUN rm erlang-solutions_1.0_all.deb

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN usermod -aG sudo elixir-user

WORKDIR /home/elixir-user/elixir-omg/

RUN wget https://github.com/ethereum/solidity/releases/download/v0.4.25/solc-static-linux \
  && chmod +x solc-static-linux \
  && sudo mv solc-static-linux /bin/solc \
  && sudo chmod 755 /bin/solc

RUN sudo -H pip3 install --upgrade pip \
  && sudo -H -n ln -s /usr/bin/python3 python \
  && sudo -H -n pip3 install requests gitpython retry

COPY . /home/elixir-user/elixir-omg/

RUN chown -R elixir-user:elixir-user /home/elixir-user

USER elixir-user

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV HEX_HTTP_TIMEOUT=240

RUN mix do local.hex --force, local.rebar --force

RUN mix deps.clean --all
RUN mix deps.get

RUN mix compile

USER root

RUN deluser elixir-user sudo

RUN apt-get purge -y

USER elixir-user

ENTRYPOINT ["./launcher.py"]
