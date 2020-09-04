.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

clean:
	docker-compose down && docker volume prune --force

start-services:
	cd ../../ && \
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init-contracts && \
	cd priv/perf/ && \
	docker-compose -f ../../docker-compose.yml -f ../../docker-compose.feefeed.yml up -d

stop-services:
	docker-compose down

init:
	. scripts/generate_api_client.sh
	# run format ONLY on formatted code so that it cleans up quoted atoms because
	mix format apps/*_api/lib/*_api/model/*.ex
	mix deps.get

test: # runs test against child chain and geth provided in test docker containers
	export $(cat ../../localchain_contract_addresses.env | xargs)
	LOAD_TEST_FAUCET_PRIVATE_KEY=0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce mix test --trace

format-code-check-warnings:
	export $(cat ../../localchain_contract_addresses.env | xargs)
	LOAD_TEST_FAUCET_PRIVATE_KEY=0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce MIX_ENV=test mix do compile --warnings-as-errors --ignore-module-conflict --force, test --exclude test
