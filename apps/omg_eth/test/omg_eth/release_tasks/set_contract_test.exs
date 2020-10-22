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
  use ExUnit.Case, async: true

  alias OMG.Eth.ReleaseTasks.SetContract

  setup_all do
    plasma_framework = Support.SnapshotContracts.parse_contracts()["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]

    contract_addresses_value = %{
      plasma_framework: plasma_framework
    }

    %{
      contract_addresses_value: contract_addresses_value,
      plasma_framework: plasma_framework
    }
  end

  setup %{} do
    on_exit(fn ->
      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("TXHASH_CONTRACT")
      :ok = System.delete_env("AUTHORITY_ADDRESS")
      :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
    end)

    :ok
  end

  test "fetching from contract exchanger", %{
    contract_addresses_value: contract_addresses_value
  } do
    port = 9009
    pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    authority_address = config |> Keyword.fetch!(:omg_eth) |> Keyword.fetch!(:authority_address)
    assert authority_address == "authority_address_value"

    plasma_framework = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:contract_addr) |> Map.get(:plasma_framework)
    assert plasma_framework == contract_addresses_value.plasma_framework

    txhash_contract_value = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:txhash_contract)
    assert txhash_contract_value == "txhash_contract_value"

    :ok = Process.send(pid, :stop, [])
  end

  test "fetching from contract exchanger sets default exit period seconds" do
    port = 9010
    _pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    min_exit_period_seconds = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:min_exit_period_seconds)
    assert min_exit_period_seconds == 20
  end

  test "unsuported network throws exception for contract exchanger" do
    port = 9011
    pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY-GORLI")
    assert catch_exit(SetContract.load([], rpc_api: __MODULE__.Rpc))
    :ok = Process.send(pid, :stop, [])
  end

  test "contract details from env", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    authority_address = config |> Keyword.fetch!(:omg_eth) |> Keyword.fetch!(:authority_address)
    assert authority_address == "authority_address_value"

    plasma_framework = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:contract_addr) |> Map.get(:plasma_framework)
    assert plasma_framework == contract_addresses_value.plasma_framework

    txhash_contract_value = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:txhash_contract)
    assert txhash_contract_value == "txhash_contract_value"
  end

  test "contract details from env, mixed case", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("TXHASH_CONTRACT", "Txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "Authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)

    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    authority_address = config |> Keyword.fetch!(:omg_eth) |> Keyword.fetch!(:authority_address)
    assert authority_address == "authority_address_value"

    plasma_framework = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:contract_addr) |> Map.get(:plasma_framework)
    assert plasma_framework == contract_addresses_value.plasma_framework

    txhash_contract_value = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:txhash_contract)
    assert txhash_contract_value == "txhash_contract_value"
  end

  test "contract details from env for localchain", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "localchain")
    :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)

    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    authority_address = config |> Keyword.fetch!(:omg_eth) |> Keyword.fetch!(:authority_address)
    assert authority_address == "authority_address_value"

    plasma_framework = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:contract_addr) |> Map.get(:plasma_framework)
    assert plasma_framework == contract_addresses_value.plasma_framework

    txhash_contract_value = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:txhash_contract)
    assert txhash_contract_value == "txhash_contract_value"
  end

  test "contract details from env sets default exit period seconds", %{
    plasma_framework: plasma_framework
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)

    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    min_exit_period_seconds = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:min_exit_period_seconds)
    assert min_exit_period_seconds == 20
  end

  test "contract details and exit period seconds from env", %{
    plasma_framework: plasma_framework,
    contract_addresses_value: contract_addresses_value
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)

    config = SetContract.load([], rpc_api: __MODULE__.Rpc)
    min_exit_period_seconds = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:min_exit_period_seconds)
    assert min_exit_period_seconds == 20

    authority_address = config |> Keyword.fetch!(:omg_eth) |> Keyword.fetch!(:authority_address)
    assert authority_address == "authority_address_value"

    plasma_framework = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:contract_addr) |> Map.get(:plasma_framework)
    assert plasma_framework == contract_addresses_value.plasma_framework

    txhash_contract_value = config |> Keyword.get(:omg_eth) |> Keyword.fetch!(:txhash_contract)
    assert txhash_contract_value == "txhash_contract_value"
  end

  test "that exit is thrown when env configuration is faulty for network name", %{
    plasma_framework: plasma_framework
  } do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby is what we are, rinkeby is what we know")
    :ok = System.put_env("TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", plasma_framework)
    assert catch_exit(SetContract.load([], rpc_api: __MODULE__.Rpc))
  end

  test "that exit is thrown when there's no mandatory configuration" do
    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("TXHASH_CONTRACT")
    :ok = System.delete_env("AUTHORITY_ADDRESS")
    :ok = System.delete_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
    assert catch_exit(SetContract.load([], rpc_api: __MODULE__.Rpc))
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
      authority_address: "authority_address_value"
    }

    body = exchanger_body |> Map.put(:plasma_framework, plasma_framework) |> Jason.encode!()

    :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

    :gen_tcp.close(conn)
  end

  defmodule Rpc do
    def call_contract(_, "vaults(uint256)", _, _) do
      {:ok, "0x0000000000000000000000004e3aeff70f022a6d4cc5947423887e7152826cf7"}
    end

    def call_contract(_, "exitGames(uint256)", _, _) do
      {:ok,
       "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"}
    end

    def call_contract(_, "childBlockInterval()", _, _) do
      {:ok, "0x00000000000000000000000000000000000000000000000000000000000003e8"}
    end

    def call_contract(_, "getVersion()", _, _) do
      {:ok,
       "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000d312e302e342b6136396337363300000000000000000000000000000000000000"}
    end

    def call_contract(_, "minExitPeriod()", _, _) do
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000014"}
    end
  end
end
