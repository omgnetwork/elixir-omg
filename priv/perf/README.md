# Perf

Umbrella app for performance/load/stress tests

## How to run the test
1. Override the urls for the services by environment variables if needed. Otherwise would be set to the default localhost with port defined in docker-compose file (No need to override if running against local services). for example:
    ```
    CHILD_CHAIN_URL=http://localhost:7534
    WATCHER_SECURITY_URL=http://localhost:7434
    WATCHER_INFO_URL=http://localhost:7534
    ```

1. To test with local services (by docker-compose): `make start-services`
1. To generate the open-api client: `make init`
1. To run the test: `make test`
1. To turn the local services down: `make stop-services`
