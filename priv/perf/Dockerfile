FROM elixir:1.10.4-alpine

RUN apk add git curl bash maven jq \
        autoconf \
        automake \
        gmp \
        gmp-dev \
        libtool \
        gcc \
        cmake \
        gnupg \
        alpine-sdk

COPY ./ ./elixir-omg

WORKDIR ./elixir-omg

RUN mkdir -p priv/openapitools \
        && curl https://raw.githubusercontent.com/OpenAPITools/openapi-generator/v4.3.1/bin/utils/openapi-generator-cli.sh > priv/openapitools/openapi-generator-cli \
        && chmod u+x priv/openapitools/openapi-generator-cli

RUN priv/openapitools/openapi-generator-cli generate \
        -i https://raw.githubusercontent.com/omgnetwork/omg-childchain-v1/master/apps/omg_child_chain_rpc/priv/swagger/operator_api_specs.yaml \
        -g elixir \
        -o priv/perf/apps/child_chain_api/

RUN priv/openapitools/openapi-generator-cli generate \
        -i apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs.yaml \
        -g elixir \
        -o priv/perf/apps/watcher_security_critical_api/

RUN priv/openapitools/openapi-generator-cli generate \
        -i apps/omg_watcher_rpc/priv/swagger/info_api_specs.yaml \
        -g elixir \
        -o priv/perf/apps/watcher_info_api/

RUN mix local.hex --force && mix local.rebar --force

WORKDIR ./priv/perf

RUN mix deps.get && mix compile
