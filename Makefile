MAKEFLAGS += --silent
OVERRIDING_START ?= foreground
help:
	@echo "Dont Fear the Makefile"
	@echo ""
	@echo "DOCKER DEVELOPMENT:"
	@echo ""
	@echo "  - \`make docker-start-cluster\`: start everything for you, but if there are no local images \c"
	@echo "for Watcher and Child chain tagged with latest they will get pulled from our repository."
	@echo ""
	@echo "  - \`make docker-start-cluster-with-infura\`: start everything but connect to Infura \c"
	@echo "instead of your own local geth network. Note: you will need to configure the environment \c"
	@echo "variables defined in docker-compose-infura.yml"
	@echo ""
	@echo "  - \`make docker-watcher && make docker-child_chain\`: use your own image containers \c"
	@echo "for Watcher and Child Chain"
	@echo ""
	@echo "  - \`make docker-update-watcher\` or \`make docker-update-child_chain\`: \c"
	@echo "replaces containers with your code changes for rapid development."
	@echo ""
	@echo "BARE METAL DEVELOPMENT:"
	@echo "-----------------------------"
	@echo "ATTENTION ATTENTION ATTENTION"
	@echo "This presumes you want to run geth, plasma-deployer and postgres as containers"
	@echo "but Watcher and Child Chain bare metal."
	@echo "-----------------------------"
	@echo ""
	@echo "You will need four terminal windows."
	@echo ""
	@echo "1. In the first one, start geth, postgres and plasma-deployer:"
	@echo ""
	@echo "    make start-services"
	@echo ""
	@echo "In case one of the containers is faulty, restart it by running the command again. \c"
	@echo "Usually it's plasma-deployer."
	@echo ""
	@echo "2. In the second terminal window, run:"
	@echo ""
	@echo "    make start-child_chain"
	@echo ""
	@echo "3. In the third terminal window, run:"
	@echo ""
	@echo "    make start-watcher"
	@echo ""
	@echo "4. Wait until they all boot. And run in the fourth terminal window"
	@echo ""
	@echo "    make get-alarms"
	@echo ""
	@echo "If you want to attach yourself to running services, use"
	@echo ""
	@echo "    make remote-child_chain"
	@echo ""
	@echo "or"
	@echo ""
	@echo "    make remote-watcher"
	@echo ""
	@echo "Discover other rules with"
	@echo ""
	@echo "    make list"
	@echo ""

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

all: clean build-child_chain-prod build-watcher-prod

WATCHER_IMAGE_NAME      ?= "omisego/watcher:latest"
CHILD_CHAIN_IMAGE_NAME  ?= "omisego/child_chain:latest"
IMAGE_BUILDER   ?= "omisegoimages/elixir-omg-builder:stable-20191024"
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
		-c "cd /app && make build-child_chain-prod"

docker-watcher-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && make build-watcher-prod"

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
docker-start-cluster:
	docker-compose build --no-cache && docker-compose up

docker-stop-cluster:
	docker-compose down

docker-update-watcher:
	docker stop elixir-omg_watcher_1
	$(MAKE) docker-watcher
	docker-compose up watcher

docker-update-child_chain:
	docker stop elixir-omg_childchain_1
	$(MAKE) docker-child_chain
	docker-compose up childchain

docker-start-cluster-with-infura:
	docker-compose -f docker-compose.yml -f docker-compose-infura.yml up

docker-start-cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up plasma-deployer watcher childchain

docker-stop-cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

###
### barebone stuff
###
start-services:
	docker-compose up geth postgres plasma-deployer

prune-plasma-deployer:
	docker rmi -f $(docker images --format '{{.Repository}}:{{.Tag}}' | grep elixir-omg_plasma-deployer:latest)

start-child_chain:
	set -e; . ./bin/variables; \
	echo "Building Child Chain" && \
	make build-child_chain-dev && \
	rm -f ./_build/dev/rel/child_chain/var/sys.config || true && \
	echo "Init Child Chain DB" && \
	_build/dev/rel/child_chain/bin/child_chain init_key_value_db && \
	echo "Init Child Chain DB DONE" && \
	_build/dev/rel/child_chain/bin/child_chain $(OVERRIDING_START)

start-watcher:
	set -e; . ./bin/variables; \
	echo "Building Watcher" && \
	make build-watcher-dev && \
	echo "Potential cleanup" && \
	rm -f ./_build/dev/rel/watcher/var/sys.config || true && \
	echo "Init Watcher DBs" && \
	_build/dev/rel/watcher/bin/watcher init_key_value_db && \
	_build/dev/rel/watcher/bin/watcher init_postgresql_db && \
	echo "Init Watcher DBs DONE" && \
	echo "Run Watcher" && \
	_build/dev/rel/watcher/bin/watcher $(OVERRIDING_START)

update-child_chain:
	_build/dev/rel/child_chain/bin/child_chain stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name child_chain --silent && \
	set -e; . ./bin/variables && \
	exec _build/dev/rel/child_chain/bin/child_chain foreground &

update-watcher:
	_build/dev/rel/watcher/bin/watcher stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher --silent && \
	set -e; . ./bin/variables && \
	exec _build/dev/rel/watcher/bin/watcher foreground &

stop-child_chain:
	_build/dev/rel/child_chain/bin/child_chain stop

stop-watcher:
	_build/dev/rel/watcher/bin/watcher stop

remote-child_chain:
	set -e; . ./bin/variables && \
	_build/dev/rel/child_chain/bin/child_chain remote_console

remote-watcher:
	set -e; . ./bin/variables && \
	_build/dev/rel/watcher/bin/watcher remote_console

get-alarms:
	echo "Child Chain alarms" ; \
	curl -s -X POST http://localhost:9656/alarm.get ; \
	echo "\nWatcher alarms" ; \
	curl -s -X POST http://localhost:7434/alarm.get

cluster-stop:
	${MAKE} stop-watcher ; ${MAKE} stop-child_chain ; docker-compose down

### git setup
init:
	git config core.hooksPath .githooks

#old git
#init:
#  find .git/hooks -type l -exec rm {} \;
#  find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

###
### SWAGGER openapi
###
security_critical_api_specs:
	swagger-cli bundle -r -t yaml -o apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs.yaml apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs/swagger.yaml

informational_api_specs:
	swagger-cli bundle -r -t yaml -o apps/omg_watcher_rpc/priv/swagger/informational_api_specs.yaml apps/omg_watcher_rpc/priv/swagger/informational_api_specs/swagger.yaml

operator_api_specs:
	swagger-cli bundle -r -t yaml -o apps/omg_child_chain_rpc/priv/swagger/operator_api_specs.yaml apps/omg_child_chain_rpc/priv/swagger/operator_api_specs/swagger.yaml

### UTILS
OSFLAG := ''
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OSFLAG = OSX
endif
