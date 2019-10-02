#!/usr/bin/env bash


build_all() {
  docker build -t omg-erlang-env --target omg-erlang-env - < docker/Dockerfile.omg-erlang-env \
    && docker build -t omg-elixir-env - < docker/Dockerfile.omg-elixir-env \
    && docker build -t omg-base-env --target omg-base-env -f docker/Dockerfile.omg-base-env . \
    && docker build -t omg-dev-env --target omg-dev-env - < docker/Dockerfile.omg-dev-env \
    && docker build --build-arg SERVICE=child_chain --build-arg RELEASE_VERSION=0.2.2+ --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-env-child_chain -f docker/Dockerfile.omg-service-env . \
    && docker build --build-arg SERVICE=watcher --build-arg RELEASE_VERSION=0.2.2+ --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-env-watcher -f docker/Dockerfile.omg-service-env . \
    && docker build --build-arg SERVICE=child_chain --build-arg RELEASE_VERSION=0.2.2+ --build-arg PORT=9656 --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-release-child_chain -f docker/Dockerfile.omg-service-release . \
    && docker build --build-arg SERVICE=watcher --build-arg RELEASE_VERSION=0.2.2+ --build-arg PORT=7434 --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-release-watcher -f docker/Dockerfile.omg-service-release .
}

build_erlang() {
  docker build -t omg-erlang-env --target omg-erlang-env - < docker/Dockerfile.omg-erlang-env
}

build_elixir() {
  docker build -t omg-elixir-env --target omg-elixir-env - < docker/Dockerfile.omg-elixir-env
}

build_rocksdb() {
  docker build -t omg-rocksdb-env --target omg-rocksdb-env - < docker/Dockerfile.omg-rocksdb-env
}

build_base() {
  docker build -t omg-base-env --target omg-base-env -f docker/Dockerfile.omg-base-env .
}

build_dev() {
  docker build -t omg-dev-env --target omg-dev-env -f docker/Dockerfile.omg-dev-env .
}

build_child_chain_dev() {
  docker build --build-arg SERVICE=child_chain --build-arg RELEASE_VERSION=0.2.2+ --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-env-child_chain -f docker/Dockerfile.omg-service-env .
}

build_watcher_dev() {
  docker build --build-arg SERVICE=watcher --build-arg RELEASE_VERSION=0.2.2+ --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-env-watcher -f docker/Dockerfile.omg-service-env .
}

build_child_chain_release() {
  docker build --build-arg SERVICE=child_chain --build-arg RELEASE_VERSION=0.2.2+ --build-arg PORT=9656 --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-release-child_chain -f docker/Dockerfile.omg-service-release .
}

build_watcher_release() {
 docker build --build-arg SERVICE=watcher --build-arg RELEASE_VERSION=0.2.2+ --build-arg PORT=7434 --build-arg SHA=`git rev-parse --short=7 HEAD` -t omg-service-release-watcher -f docker/Dockerfile.omg-service-release .
}

"$@"
