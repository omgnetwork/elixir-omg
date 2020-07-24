# Specs

TBD - Repo containing specs and integrations tests

## Setup and Run

```sh
# If there is already some elixir-omg docker running, this can make sure it is cleaned up
make clean

# Starts the elixir-omg services (childchain, watcher and watcher_info) as background services
make start_daemon_services

# Run all the tests
make test

# To run a specific test, see the <test_file_name> in apps/itest/test/
mix test test/itest/<test_file_name>.exs
```
