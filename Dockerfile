FROM ubuntu:16.04

MAINTAINER Jake Bunce <jake@omise.co>

ARG USER=plasma
ARG GROUP=plasma
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

ARG BUILD_PACKAGES="build-essential autoconf libtool libgmp3-dev libssl-dev wget gettext"

RUN apt-get update \
  && apt-get install -y software-properties-common \
  && add-apt-repository -y ppa:ethereum/ethereum \
  && apt-get update \
  && apt-get install -y $BUILD_PACKAGES \
  sudo \
  git \
  python3-pip \
  python3-dev \
  solc 

RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb \
  && dpkg -i erlang-solutions_1.0_all.deb \
  && apt-get update \
  && apt-get install -y esl-erlang=1:20.3.8.6 \
  elixir=1.6.6-2

RUN rm erlang-solutions_1.0_all.deb

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN usermod -aG sudo plasma

COPY . /home/plasma/elixir-omg/

RUN chown -R plasma:plasma /home/plasma

USER plasma

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8 

WORKDIR /home/plasma/elixir-omg/

RUN sudo -H pip3 install --upgrade pip \
  && sudo -H -n ln -s /usr/bin/python3 python \
  && sudo -H -n pip3 install -r contracts/requirements.txt

WORKDIR /home/plasma/elixir-omg/

RUN mix do local.hex --force, local.rebar --force

RUN mix deps.get 

RUN mix compile

USER root

RUN deluser plasma sudo

RUN apt-get purge -y 

USER plasma

ENTRYPOINT ["/bin/bash"]
