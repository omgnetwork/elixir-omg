MAKEFLAGS += --silent
help:
	@echo "Dont Fear the Makefile"
	@echo "*DOCKER DEVELOPMENT*:"
	@echo "make cluster - will start everything for you, but if there are no local images"
	@echo "for Watcher and Child chain tagged with latest they will get pulled from our repository."
	@echo "If you want to use your own image containers for Watcher and Child Chain"
	@echo "use make docker-watcher && make docker-child_chain."
	@echo "For rapid development that replaces containers with your code changes"
	@echo "one can use make watcher-update or make child_chain-update."
	@echo "BARE METAL DEVELOPMENT:"
	@echo "ATTENTION ATTENTION ATTENTION"
	@echo "-----------------------------"
	@echo "This presumes you want to run geth, plasma-deployer and postgres as containers"
	@echo "but Watcher and Child Chain bare metal."
	@echo "make raw-cluster - will start everything for you where Child Chain and Watcher continue running in background."
	@echo "Exported variables are in bin/variables."
	@echo "For rapid development that restarts releases with your code changes"
	@echo "one can use make raw-update-watcher or make raw-update-child_chain."
	@echo "Stop the release with raw-stop-child_chain or raw-stop-watcher."
	@echo "To inject yourself into a running node use raw-remote-child_chain or raw-remote-watcher."

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

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

test:
	mix test --include test --exclude common --exclude watcher --exclude child_chain

test-watcher:
	mix test --include watcher --exclude child_chain --exclude common --exclude test

test-common:
	mix test --include common --exclude child_chain --exclude watcher --exclude test

test-child_chain:
	mix test --include child_chain --exclude common --exclude watcher --exclude test

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

docker-child_chain-build:
	docker build -f Dockerfile.child_chain \
		--build-arg release_version=$$(cat $(PWD)/VERSION)+$$(git rev-parse --short=7 HEAD) \
		--cache-from $(CHILD_CHAIN_IMAGE_NAME) \
		-t $(CHILD_CHAIN_IMAGE_NAME) \
		.

docker-watcher-build:
	docker build -f Dockerfile.watcher \
		--build-arg release_version=$$(cat $(PWD)/VERSION)+$$(git rev-parse --short=7 HEAD) \
		--cache-from $(WATCHER_IMAGE_NAME) \
		-t $(WATCHER_IMAGE_NAME) \
		.

docker-watcher: docker-watcher-prod docker-watcher-build
docker-child_chain: docker-child_chain-prod docker-child_chain-build

docker-push: docker
	docker push $(CHILD_CHAIN_IMAGE_NAME)
	docker push $(WATCHER_IMAGE_NAME)

###OTHER
cluster:
	docker-compose up

update-watcher:
	docker stop elixir-omg_watcher_1
	$(MAKE) docker-watcher
	docker-compose up watcher

update-child_chain:
	docker stop elixir-omg_childchain_1
	$(MAKE) docker-child_chain
	docker-compose up childchain

cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up plasma-deployer watcher childchain

stop-cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

raw-cluster:
	set -e; . ./bin/variables; \
	docker-compose up -d geth postgres plasma-deployer && \
	echo "Building Child Chain" && \
	$(MAKE) build-child_chain-dev && \
	echo "Building Watcher" && \
	$(MAKE) build-watcher-dev && \
	echo "Potential cleanup" && \
	rm -f ./_build/dev/rel/watcher/var/sys.config || true && \
	rm -f ./_build/dev/rel/child_chain/var/sys.config || true && \
	echo "Init Child Chain DB" && \
	_build/dev/rel/child_chain/bin/child_chain init_key_value_db && \
	echo "Init Child Chain DB DONE" && \
	echo "Init Watcher DBs" && \
	_build/dev/rel/watcher/bin/watcher init_key_value_db && \
	_build/dev/rel/watcher/bin/watcher init_postgresql_db && \
	echo "Init Watcher DBs DONE" && \
	echo "Run Child Chain" && \
	exec _build/dev/rel/child_chain/bin/child_chain foreground & \
	echo "Run Watcher" && \
	_build/dev/rel/watcher/bin/watcher foreground &

raw-update-child_chain:
	_build/dev/rel/child_chain/bin/child_chain stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name child_chain --silent && \
	set -e; . ./bin/variables && \
	exec _build/dev/rel/child_chain/bin/child_chain foreground &

raw-update-watcher:
	_build/dev/rel/watcher/bin/watcher stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher --silent && \
	set -e; . ./bin/variables && \
	exec _build/dev/rel/watcher/bin/watcher foreground &

raw-stop-child_chain:
	_build/dev/rel/child_chain/bin/child_chain stop

raw-stop-watcher:
	_build/dev/rel/watcher/bin/watcher stop

raw-remote-child_chain:
	set -e; . ./bin/variables && \
	_build/dev/rel/child_chain/bin/child_chain remote_console

raw-remote-watcher:
	set -e; . ./bin/variables && \
	_build/dev/rel/watcher/bin/watcher remote_console

alarms:
	echo "Child Chain alarms" ; \
	curl -s -X POST http://localhost:9656/alarm.get | jq ; \
	echo "Watcher alarms" ; \
	curl -s -X POST http://localhost:7434/alarm.get | jq

raw-cluster-stop:
	${MAKE} raw-stop-watcher ; ${MAKE} raw-stop-child_chain ; docker-compose down

### git setup
init:
	git config core.hooksPath .githooks

#old git
#init:
#  find .git/hooks -type l -exec rm {} \;
#  find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

### UTILS
OSFLAG := ''
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OSFLAG = OSX
endif
