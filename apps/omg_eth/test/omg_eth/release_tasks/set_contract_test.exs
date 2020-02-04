# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Eth.ReleaseTasks.SetContractTest do
  use ExUnit.Case, async: false
  alias OMG.Eth.ReleaseTasks.SetContract

  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @app :omg_eth
  @configuration_old Application.get_all_env(@app)

  setup_all do
    plasma_framework = Support.SnapshotContracts.parse_contracts()["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]

    contract_addresses_value = %{
      erc20_vault: "erc20_vault_value",
      eth_vault: "eth_vault_value",
      payment_exit_game: "payment_exit_game_value",
      plasma_framework: plasma_framework
    }

    %{
      contract_addresses_value: contract_addresses_value,
      plasma_framework: plasma_framework
    }
  end

  setup %{} do
    vcr_path = Path.join(__DIR__, "../../fixtures/vcr_cassettes")
    ExVCR.Config.cassette_library_dir(vcr_path)

    on_exit(fn ->
      :ok =
        Enum.each(@configuration_old, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  test "fetching from contract exchanger", %{
    contract_addresses_value: contract_addresses_value
  } do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      port = 9009

      :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
      :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
      :ok = SetContract.init([])
      "authority_address_value" = Application.get_env(@app, :authority_addr)
      ^contract_addresses_value = Application.get_env(@app, :contract_addr)
      "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
    end
  end

  test "fetching from contract exchanger sets default exit period seconds" do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      port = 9009
      :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
      :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
      :ok = SetContract.init([])
      20 = Application.get_env(@app, :min_exit_period_seconds)

      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
    end
  end

  test "unsuported network throws exception for contract exchanger" do
    port = 9011
    pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY-GORLI")

    try do
      :ok = SetContract.init([])
    catch
      :exit, _ ->
        :ok = Process.send(pid, :stop, [])
        :ok
    end

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
  end

  test "contract details from env", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
      :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
      :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
      :ok = System.put_env("CONTRACT_ADDRESS_ETH_VAULT", "eth_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_ERC20_VAULT", "erc20_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME", "payment_exit_game_value")
      :ok = SetContract.init([])
      "authority_address_value" = Application.get_env(@app, :authority_addr)
      ^contract_addresses_value = Application.get_env(@app, :contract_addr)
      "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("TXHASH_CONTRACT")
      :ok = System.delete_env("AUTHORITY_ADDRESS")
      :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
      :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
    end
  end

  test "contract details from env, mixed case", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
      :ok = System.put_env("TXHASH_CONTRACT", "Txhash_contract_value")
      :ok = System.put_env("AUTHORITY_ADDRESS", "Authority_address_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
      :ok = System.put_env("CONTRACT_ADDRESS_ETH_VAULT", "Eth_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_ERC20_VAULT", "Erc20_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME", "Payment_exit_game_value")
      :ok = SetContract.init([])
      "authority_address_value" = Application.get_env(@app, :authority_addr)
      ^contract_addresses_value = Application.get_env(@app, :contract_addr)
      "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("TXHASH_CONTRACT")
      :ok = System.delete_env("AUTHORITY_ADDRESS")
      :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
      :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
    end
  end

  test "contract details from env for localchain", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      :ok = System.put_env("ETHEREUM_NETWORK", "localchain")
      :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
      :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
      :ok = System.put_env("CONTRACT_ADDRESS_ETH_VAULT", "eth_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_ERC20_VAULT", "erc20_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME", "payment_exit_game_value")
      :ok = SetContract.init([])
      "authority_address_value" = Application.get_env(@app, :authority_addr)
      ^contract_addresses_value = Application.get_env(@app, :contract_addr)
      "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("TXHASH_CONTRACT")
      :ok = System.delete_env("AUTHORITY_ADDRESS")
      :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
      :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
    end
  end

  test "contract details from env sets default exit period seconds", %{
    plasma_framework: plasma_framework
  } do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
      :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
      :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
      :ok = System.put_env("CONTRACT_ADDRESS_ETH_VAULT", "eth_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_ERC20_VAULT", "erc20_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME", "payment_exit_game_value")
      :ok = SetContract.init([])
      20 = Application.get_env(@app, :min_exit_period_seconds)

      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("TXHASH_CONTRACT")
      :ok = System.delete_env("AUTHORITY_ADDRESS")
      :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
      :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
    end
  end

  test "contract details and exit period seconds from env", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    use_cassette "root_chain/get_min_exit_period", match_requests_on: [:request_body] do
      :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
      :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
      :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
      :ok = System.put_env("CONTRACT_ADDRESS_ETH_VAULT", "eth_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_ERC20_VAULT", "erc20_vault_value")
      :ok = System.put_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME", "payment_exit_game_value")

      :ok = SetContract.init([])
      20 = Application.get_env(@app, :min_exit_period_seconds)
      "authority_address_value" = Application.get_env(@app, :authority_addr)
      ^contract_addresses_value = Application.get_env(@app, :contract_addr)
      "txhash_contract_value" = Application.get_env(@app, :txhash_contract)
      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("TXHASH_CONTRACT")
      :ok = System.delete_env("AUTHORITY_ADDRESS")
      :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
      :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
      :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
    end
  end

  test "that exit is thrown when env configuration is faulty for network name", %{
    plasma_framework: plasma_framework
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby is what we are, rinkeby is what we know")
    :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
    :ok = System.put_env("CONTRACT_ADDRESS_ETH_VAULT", "eth_vault_value")
    :ok = System.put_env("CONTRACT_ADDRESS_ERC20_VAULT", "erc20_vault_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME", "payment_exit_game_value")

    try do
      :ok = SetContract.init([])
    catch
      :exit, _ ->
        :ok
    end

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("TXHASH_CONTRACT")
    :ok = System.delete_env("AUTHORITY_ADDRESS")
    :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
    :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
    :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
    :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
  end

  test "that exit is thrown when there's no mandatory configuration" do
    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("TXHASH_CONTRACT")
    :ok = System.delete_env("AUTHORITY_ADDRESS")
    :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
    :ok = System.delete_env("CONTRACT_ADDRESS_ETH_VAULT")
    :ok = System.delete_env("CONTRACT_ADDRESS_ERC20_VAULT")
    :ok = System.delete_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME")
    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")

    try do
      :ok = SetContract.init([])
    catch
      :exit, _ ->
        :ok
    end
  end

  # a very simple web server that serves conctract exchanger requests
  defp start(port) do
    {:ok, sock} = :gen_tcp.listen(port, [{:active, false}])
    spawn(fn -> loop(sock) end)

    receive do
      :stop ->
        :gen_tcp.close(sock)
    end
  end

  defp loop(sock) do
    case :gen_tcp.accept(sock) do
      {:ok, conn} ->
        handler = spawn(fn -> handle(conn) end)
        :gen_tcp.controlling_process(conn, handler)
        loop(sock)

      _ ->
        :ok
    end
  end

  defp handle(conn) do
    plasma_framework = Support.SnapshotContracts.parse_contracts()["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]

    exchanger_body = %{
      plasma_framework_tx_hash: "txhash_contract_value",
      plasma_framework: nil,
      eth_vault: "eth_vault_value",
      erc20_vault: "erc20_vault_value",
      payment_exit_game: "payment_exit_game_value",
      authority_address: "authority_address_value"
    }

    body = Jason.encode!(Map.put(exchanger_body, :plasma_framework, plasma_framework))

    :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

    :gen_tcp.close(conn)
  end
end
