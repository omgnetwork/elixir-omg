.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

test:
	mix test test/itest

clean:
	docker-compose down && docker rm -f $$(docker ps -a -q) && docker volume rm $$(docker volume ls -q)

start_daemon_services:
	cd ../ && \
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_20 make init_test && \
	cd priv/ && \
	docker-compose -f ../docker-compose.yml up -d

generate-security_critical_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ../apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs.yaml -g elixir -o apps/watcher_security_critical_api

generate-info_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ../apps/omg_watcher_rpc/priv/swagger/info_api_specs.yaml -g elixir -o apps/watcher_info_api

generate-operator_api_specs:
	priv/openapitools/openapi-generator-cli generate -i ../apps/omg_child_chain_rpc/priv/swagger/operator_api_specs.yaml -g elixir -o apps/child_chain_api

generate_api_code: generate-security_critical_api_specs generate-info_api_specs generate-operator_api_specs

clean_generate_api_code:
	rm -rf apps/child_chain_api || true && \
	rm -rf apps/watcher_info_api || true && \
	rm -rf apps/watcher_security_critical_api

install:
	mkdir -p priv/openapitools
	curl https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/bin/utils/openapi-generator-cli.sh > priv/openapitools/openapi-generator-cli
	chmod u+x priv/openapitools/openapi-generator-cli
