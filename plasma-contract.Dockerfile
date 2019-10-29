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
RUN cd /home/node/plasma-contracts && git reset --hard 2251299e7e99484c7f07333f6b59c9f7c4c9ab4f
RUN cd /home/node/plasma-contracts && npm install
RUN cd /home/node/plasma-contracts/plasma_framework && npm install
