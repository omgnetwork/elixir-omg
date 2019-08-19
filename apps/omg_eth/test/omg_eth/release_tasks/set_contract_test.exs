# Copyright 2019 OmiseGO Pte Ltd
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

  @app :omg_eth
  @configuration_old Application.get_all_env(@app)

  setup %{} do
    on_exit(fn ->
      :ok =
        Enum.each(@configuration_old, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  test "fetching from contract exchanger" do
    port = 9009
    pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
    :ok = SetContract.init([])
    "authority_address_value" = Application.get_env(@app, :authority_addr)
    "contract_address_value" = Application.get_env(@app, :contract_addr)
    "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

    :ok = Process.send(pid, :stop, [])
    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
  end

  test "fetching from contract exchanger sets default exit period seconds" do
    port = 9010
    pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = System.put_env("ETHEREUM_NETWORK", "RINKEBY")
    :ok = SetContract.init([])
    22 = Application.get_env(@app, :exit_period_seconds)

    :ok = Process.send(pid, :stop, [])
    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
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

  test "contract details from env" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("RINKEBY_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("RINKEBY_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("RINKEBY_CONTRACT_ADDRESS", "contract_address_value")
    :ok = SetContract.init([])
    "authority_address_value" = Application.get_env(@app, :authority_addr)
    "contract_address_value" = Application.get_env(@app, :contract_addr)
    "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
  end

  test "contract details from env for localchain" do
    :ok = System.put_env("ETHEREUM_NETWORK", "localchain")
    :ok = System.put_env("LOCALCHAIN_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("LOCALCHAIN_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("LOCALCHAIN_CONTRACT_ADDRESS", "contract_address_value")
    :ok = SetContract.init([])
    "authority_address_value" = Application.get_env(@app, :authority_addr)
    "contract_address_value" = Application.get_env(@app, :contract_addr)
    "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
  end

  test "if exit is thrown when mixed network names" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("LOCALCHAIN_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("LOCALCHAIN_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("LOCALCHAIN_CONTRACT_ADDRESS", "contract_address_value")

    try do
      :ok = SetContract.init([])
    catch
      :exit, _ ->
        :ok = System.delete_env("ETHEREUM_NETWORK")
        :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
        :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
        :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
    end
  end

  test "contract details from env sets default exit period seconds" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("RINKEBY_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("RINKEBY_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("RINKEBY_CONTRACT_ADDRESS", "contract_address_value")
    :ok = SetContract.init([])
    22 = Application.get_env(@app, :exit_period_seconds)

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
  end

  test "contract details and exit period seconds from env" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("RINKEBY_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("RINKEBY_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("RINKEBY_CONTRACT_ADDRESS", "contract_address_value")
    :ok = System.put_env("EXIT_PERIOD_SECONDS", "2222")
    :ok = SetContract.init([])
    2222 = Application.get_env(@app, :exit_period_seconds)
    "authority_address_value" = Application.get_env(@app, :authority_addr)
    "contract_address_value" = Application.get_env(@app, :contract_addr)
    "txhash_contract_value" = Application.get_env(@app, :txhash_contract)
    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
    :ok = System.delete_env("EXIT_PERIOD_SECONDS")
  end

  test "that exit is thrown when env configuration is faulty for network name" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby is what we are, rinkeby is what we know")
    :ok = System.put_env("RINKEBY_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("RINKEBY_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("RINKEBY_CONTRACT_ADDRESS", "contract_address_value")

    try do
      :ok = SetContract.init([])
    catch
      :exit, _ ->
        :ok
    end

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
  end

  test "that exit is thrown when there's no mandatory configuration" do
    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
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
    body =
      "{\"authority_addr\":\"authority_address_value\",\"contract_addr\":\"contract_address_value\",\"txhash_contract\":\"txhash_contract_value\"}"

    :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

    :gen_tcp.close(conn)
  end
end
