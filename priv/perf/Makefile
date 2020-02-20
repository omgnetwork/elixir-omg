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

test:
	mix test

init:
	. scripts/generate_api_client.sh
	mix deps.get
