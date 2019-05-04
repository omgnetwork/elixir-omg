all: clean build-child_chain-prod build-watcher-prod

WATCHER_IMAGE_NAME      ?= "omisego/watcher:latest"
CHILD_CHAIN_IMAGE_NAME      ?= "omisego/child_chain:latest"
IMAGE_BUILDER   ?= "omisegoimages/elixir-omg-builder:v1.2"
IMAGE_BUILD_DIR ?= $(PWD)

ENV_DEV         ?= env MIX_ENV=dev
ENV_TEST        ?= env MIX_ENV=test
ENV_PROD        ?= env MIX_ENV=prod

#
# Setting-up
#

deps: deps-elixir-omg

deps-elixir-omg:
	mix deps.get

.PHONY: deps deps-elixir-omg

#
# Cleaning
#

clean: clean-elixir-omg

clean-elixir-omg:
	rm -rf _build/
	rm -rf deps/


.PHONY: clean clean-elixir-omg

#
# Linting
#

format:
	mix format

check-format:
	mix format --check-formatted 2>&1

check-credo:
	$(ENV_TEST) mix credo 2>&1

check-dialyzer:
	$(ENV_TEST) mix dialyzer --halt-exit-status 2>&1

.PHONY: format check-format check-credo

#
# Building
#


build-child_chain-prod: deps-elixir-omg
	$(ENV_PROD) mix do compile, release --name child_chain

build-child_chain-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, release dev --name child_chain

build-watcher-prod: deps-elixir-omg
	$(ENV_PROD) mix do compile, release --name watcher

build-watcher-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, release dev --name watcher

build-test: deps-elixir-omg
	$(ENV_TEST) mix compile

.PHONY: build-prod build-dev build-test

#
# Testing
#

test: test-elixir-omg

test-elixir-omg-watcher: build-test
	$(ENV_TEST) mix test

.PHONY: test test-elixir-omg

#
# Docker
#

docker-child_chain-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(CHILD_CHAIN_IMAGE_NAME) \
		-c "cd /app && make build-child_chain-prod"

docker-watcher-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(WATCHER_IMAGE_NAME) \
		-c "cd /app && make build-watcher-prod"

docker-child_chain-build:
	docker build -f Dockerfile.child_chain \
		--build-arg release_version=$$(awk '/umbrella_version:/ { gsub(/[^0-9a-z\.\-]+/, "", $$2); print $$2 }' $(PWD)/mix.exs) \
		--cache-from $(CHILD_CHAIN_IMAGE_NAME) \
		-t $(CHILD_CHAIN_IMAGE_NAME) \
		.
docker-watcher-build:
	docker build -f Dockerfile.watcher \
		--build-arg release_version=$$(awk '/umbrella_version:/ { gsub(/[^0-9a-z\.\-]+/, "", $$2); print $$2 }' $(PWD)/mix.exs) \
		--cache-from $(WATCHER_IMAGE_NAME) \
		-t $(WATCHER_IMAGE_NAME) \
		.

docker: docker-child_chain-prod docker-child_chain-build docker-wacher-prod docker-watcher-build

docker-push: docker
	docker push $(CHILD_CHAIN_IMAGE_NAME)
	docker push $(WATCHER_IMAGE_NAME)

.PHONY: docker docker-child_chain-prod docker-child_chain-build docker-watcher-prod docker-watcher-build docker-push
