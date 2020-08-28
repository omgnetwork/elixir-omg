.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

start-services:
	cd ../../ && \
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init-contracts && \
	cd priv/perf/ && \
	docker-compose -f ../../docker-compose.yml up -d

stop-services:
	docker-compose down

init:
	. scripts/generate_api_client.sh
	mix deps.get

test: # runs test against child chain and geth provided in test docker containers
	LOAD_TEST_FAUCET_PRIVATE_KEY=0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce mix test test/load_tests/runner/utxos_load_test.exs:22

format-code-check-warnings:
	MIX_ENV=test mix do compile --warnings-as-errors --ignore-module-conflict --force, test --exclude test
