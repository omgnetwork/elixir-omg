# Perf

Umbrella app for performance/load/stress tests

## How to run the test
1. Change the urls inside the [config files](config/) for the environment you are targeting.
1. To generate the open-api client (only need once): `make init`
1. To run the test: `MIX_ENV=<your_env> mix test`. Or `mix test` if you want to run against local services.

### Spin up local services for development
1. To test with local services (by docker-compose): `make start-services`
1. To turn the local services down: `make stop-services`

### Increase connection pool size and connection
One can override the setup in config to increase the `pool_size` and `max_connection`. If you found the latency on the api calls are high but the data dog latency shows way smaller, it might be latency from setting up the connection instead of real api latency.
