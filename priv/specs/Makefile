.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

test:
	mix test test/itest

clean:
	docker-compose down && docker volume prune --force

start_daemon_services-2:
	cd ../../ && \
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init_test && \
	cd priv/cabbage/ && \
	docker-compose -f ../../docker-compose.yml -f docker-compose-2-specs.yml up -d

start_daemon_services:
	cd ../../ && \
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init_test && \
	cd priv/cabbage/ && \
	docker-compose -f ../../docker-compose.yml -f docker-compose-specs.yml up -d

start_daemon_services_reorg-2:
	cd ../../ && \
	make init_test_reorg && \
	cd priv/cabbage/ && \
	docker-compose -f ../../docker-compose.yml -f docker-compose-2-reorg.yml -f docker-compose-2-specs.yml up -d

start_daemon_services_reorg:
	cd ../../ && \
	make init_test_reorg && \
	cd priv/cabbage/ && \
	docker-compose -f ../../docker-compose.yml -f docker-compose-reorg.yml -f docker-compose-specs.yml up -d

stop_daemon_services:
	docker container stop $(docker container ls -aq)

generate-security_critical_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ./security_critical_api_specs.yml -g elixir -o apps/watcher_security_critical_api

generate-info_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ./info_api_specs.yml -g elixir -o apps/watcher_info_api

generate-operator_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ./operator_api_specs.yml -g elixir -o apps/child_chain_api

generate_api_code: generate-security_critical_api_specs generate-info_api_specs generate-operator_api_specs

clean_generate_api_code:
	rm -rf apps/child_chain_api || true && \
	rm -rf apps/watcher_info_api || true && \
	rm -rf apps/watcher_security_critical_api

install:
	mkdir -p priv/openapitools
	curl https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/bin/utils/openapi-generator-cli.sh > priv/openapitools/openapi-generator-cli
	chmod u+x priv/openapitools/openapi-generator-cli
