all: clean build-child_chain-prod build-watcher-prod

WATCHER_IMAGE_NAME      ?= "omisego/watcher:latest"
CHILD_CHAIN_IMAGE_NAME  ?= "omisego/child_chain:latest"
IMAGE_BUILDER   ?= "omisegoimages/elixir-omg-builder:v1.3"
IMAGE_BUILD_DIR ?= $(PWD)

ENV_DEV         ?= env MIX_ENV=dev
ENV_TEST        ?= env MIX_ENV=test
ENV_PROD        ?= env MIX_ENV=prod

#
# Setting-up
#

deps: deps-elixir-omg

deps-elixir-omg:
	HEX_HTTP_TIMEOUT=120 mix deps.get

.PHONY: deps deps-elixir-omg

#
# Cleaning
#

clean: clean-elixir-omg

clean-elixir-omg:
	rm -rf _build/*
	rm -rf deps/*


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
	$(ENV_PROD) mix do compile, distillery.release --name child_chain --verbose

build-child_chain-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, distillery.release dev --name child_chain --verbose

build-watcher-prod: deps-elixir-omg
	$(ENV_PROD) mix do compile, distillery.release --name watcher --verbose

build-watcher-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher --verbose

build-test: deps-elixir-omg
	$(ENV_TEST) mix compile

.PHONY: build-prod build-dev build-test

#
# Testing
#

test: test-elixir-omg

.PHONY: test test-elixir-omg

#
# Documentation
#
changelog:
	github_changelog_generator -u omisego -p elixir-omg

.PHONY: changelog

#
# Docker
#

docker-child_chain-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && if [[ OSX == $(OSFLAG) ]] ; then make clean ; fi && make build-child_chain-prod"

docker-watcher-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && if [[ OSX == $(OSFLAG) ]] ; then make clean ; fi && make build-watcher-prod"

docker-child_chain-build-prod:
	docker build -f Dockerfile.child_chain \
		--build-arg release_version=$$(cat $(PWD)/VERSION) \
		--cache-from $(CHILD_CHAIN_IMAGE_NAME) \
		-t $(CHILD_CHAIN_IMAGE_NAME) \
		.

docker-watcher-build-prod:
	docker build -f Dockerfile.watcher \
		--build-arg release_version=$$(cat $(PWD)/VERSION) \
		--cache-from $(WATCHER_IMAGE_NAME) \
		-t $(WATCHER_IMAGE_NAME) \
		.

docker-watcher: docker-watcher-prod docker-watcher-build-prod
docker-child_chain: docker-child_chain-prod docker-child_chain-build-prod

docker-push: docker
	docker push $(CHILD_CHAIN_IMAGE_NAME)
	docker push $(WATCHER_IMAGE_NAME)

cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up datadog plasma-deployer watcher childchain

stop-cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

### UTILS
OSFLAG := ''
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OSFLAG = OSX
endif
