# Perf

Umbrella app for performance/load/stress tests

## How to run the test
1. Change the configurations inside the [config files](config/) for the environment you are targeting.
1. To generate the open-api client (only need once): `make init`
1. To run the test: `MIX_ENV=<your_env> mix test`. Or `mix test` if you want to run against local services.
1. Each `<env_name>.config` is defined for a specific environment. eg. `dev.exs` is the config for the dev env. One special case is `test` config. `test.exs` is the config used for local testing with docker-compose (see the following section) and this is the default config that would be pick up when running `mix test` without specifying the env.

### Spin up local services for development
1. To test with local services (by docker-compose): `make start-services`
1. To turn the local services down: `make stop-services`

### Increase connection pool size and connection
One can override the setup in config to increase the `pool_size` and `max_connection`. If you found the latency on the api calls are high but the data dog latency shows way smaller, it might be latency from setting up the connection instead of real api latency.
