# Running your own Watcher locally

The `docker-compose` tooling in the root of `elixir-omg` allows users to run their own instance of the Watcher to connect to the OMG Network and validate transactions.

### Requirements

- Docker
- `docker-compose` - known to work with `docker-compose version 1.24.0, build 0aa59064`, version `1.17` has had problems
- Ethereum connectivity: local Ethereum node or Infura

### Startup

1) Add an ENV variable `INFURA_API_KEY` to your environment or override the ETHEREUM_RPC_URL completely in the `docker-compose-watcher.yml` file with the RPC connection information.

2) From the root of the `elixir-omg` execute:

- `docker-compose -f docker-compose-watcher.yml up`

Modify the other environment variables for connecting to other networks.
