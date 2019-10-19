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
RUN cd /home/node/plasma-contracts && git checkout fb7109a9e823b998c20484deac8609cda425218a 
RUN cd /home/node/plasma-contracts && npm install
RUN cd /home/node/plasma-contracts/plasma_framework && npm install
