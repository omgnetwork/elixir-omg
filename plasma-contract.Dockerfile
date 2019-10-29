FROM node:8.16-alpine

MAINTAINER OmiseGO Engineering <eng@omise.co>

WORKDIR /home/node

RUN apk add --update \
    python \
    python-dev \
    py-pip \
    build-base \
		git

RUN git clone https://github.com/omisego/plasma-contracts.git
RUN cd /home/node/plasma-contracts && git reset --hard ea36f5ff46ab72ec5c281fa0a3dffe3bcc83178b
RUN cd /home/node/plasma-contracts && npm install
RUN cd /home/node/plasma-contracts/plasma_framework && npm install
