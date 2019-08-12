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
    :ok = OMG.Eth.ReleaseTasks.SetContract.init([])
    "authority_address_value" = Application.get_env(@app, :authority_addr)
    "contract_address_value" = Application.get_env(@app, :contract_addr)
    "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

    :ok = Process.send(pid, :stop, [])

    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
  end

  test "fetching from contract exchanger sets default exit period seconds" do
    port = 9010
    pid = spawn(fn -> start(port) end)
    :ok = System.put_env("CONTRACT_EXCHANGER_URL", "http://localhost:#{port}")
    :ok = OMG.Eth.ReleaseTasks.SetContract.init([])
    22 = Application.get_env(@app, :exit_period_seconds)

    :ok = Process.send(pid, :stop, [])
    :ok = System.delete_env("CONTRACT_EXCHANGER_URL")
  end

  test "contract details from env" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("RINKEBY_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("RINKEBY_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("RINKEBY_CONTRACT_ADDRESS", "contract_address_value")
    :ok = OMG.Eth.ReleaseTasks.SetContract.init([])
    "authority_address_value" = Application.get_env(@app, :authority_addr)
    "contract_address_value" = Application.get_env(@app, :contract_addr)
    "txhash_contract_value" = Application.get_env(@app, :txhash_contract)

    :ok = System.delete_env("ETHEREUM_NETWORK")
    :ok = System.delete_env("RINKEBY_TXHASH_CONTRACT")
    :ok = System.delete_env("RINKEBY_AUTHORITY_ADDRESS")
    :ok = System.delete_env("RINKEBY_CONTRACT_ADDRESS")
  end

  test "contract details from env sets default exit period seconds" do
    :ok = System.put_env("ETHEREUM_NETWORK", "rinkeby")
    :ok = System.put_env("RINKEBY_TXHASH_CONTRACT", "txhash_contract_value")
    :ok = System.put_env("RINKEBY_AUTHORITY_ADDRESS", "authority_address_value")
    :ok = System.put_env("RINKEBY_CONTRACT_ADDRESS", "contract_address_value")
    :ok = OMG.Eth.ReleaseTasks.SetContract.init([])
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
    :ok = OMG.Eth.ReleaseTasks.SetContract.init([])
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
