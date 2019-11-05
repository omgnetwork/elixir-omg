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
RUN cd /home/node/plasma-contracts && git reset --hard a6d870f4562b359bece7bea01643e4a6b567b5a9
RUN cd /home/node/plasma-contracts && npm install
RUN cd /home/node/plasma-contracts/plasma_framework && npm install
