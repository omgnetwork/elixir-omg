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
RUN cd /home/node/plasma-contracts && git checkout 7b8a2643568556c1d126749724666bc37edc8141
RUN cd /home/node/plasma-contracts && npm install
RUN cd /home/node/plasma-contracts/plasma_framework && npm install
