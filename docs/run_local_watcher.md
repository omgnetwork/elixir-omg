# Running your own Watcher locally

The `docker-compose` tooling in the root of `elixir-omg` allows users to run their own instance of the Watcher to connect to the OMG Network and validate transactions.

### Requirements

- Docker
- Ethereum connectivity: local Ethereum node or Infura

### Startup

1) Configure the environment variable `ETHEREUM_RPC_URL=https://rinkeby.infura.io/v3/<your_api_key>` with the RPC connection information

2) From the root of the `elixir-omg` execute:

- `docker-compose -f docker-compose-watcher-mac.yml up` (Mac)
- `docker-compose -f docker-compose-watcher-non-mac.yml up` (Linux/Windows)

Modify the other environment variables for connecting to other networks.