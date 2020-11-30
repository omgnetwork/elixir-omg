# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Eth.ApplicationTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias OMG.DB
  alias OMG.Eth.Configuration

  setup do
    db_path = Briefly.create!(directory: true)
    Application.put_env(:omg_db, :path, db_path, persistent: true)
    :ok = DB.init()
    {:ok, apps} = Application.ensure_all_started(:omg_eth)

    on_exit(fn ->
      contracts_hash = DB.get_single_value(:omg_eth_contracts)
      :ok = DB.multi_update([{:delete, :omg_eth_contracts, contracts_hash}])
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    {:ok, %{apps: apps}}
  end

  describe "valid_contracts/0" do
    test "if contracts hash is persisted when application starts" do
      contracts_hash =
        Configuration.contracts()
        |> Map.put(:txhash_contract, Configuration.txhash_contract())
        # authority_addr to keep backwards compatibility
        |> Map.put(:authority_addr, Configuration.authority_address())
        |> :erlang.phash2()

      assert DB.get_single_value(:omg_eth_contracts) == {:ok, contracts_hash}
    end

    test "that if contracts change boot is not permitted", %{apps: apps} do
      contracts_hash =
        Configuration.contracts()
        |> Map.put(:txhash_contract, Configuration.txhash_contract())
        # authority_addr to keep backwards compatibility
        |> Map.put(:authority_addr, Configuration.authority_address())
        |> :erlang.phash2()

      assert DB.get_single_value(:omg_eth_contracts) == {:ok, contracts_hash}

      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
      contracts = Configuration.contracts()
      Application.put_env(:omg_eth, :contract_addr, %{"test" => "test"})

      assert capture_log(fn ->
               assert Application.ensure_all_started(:omg_eth) ==
                        {:error,
                         {:omg_eth,
                          {:bad_return, {{OMG.Eth.Application, :start, [:normal, []]}, {:EXIT, :contracts_missmatch}}}}}
             end) =~ "[error]"

      Application.put_env(:omg_eth, :contract_addr, contracts)
      {:ok, _} = Application.ensure_all_started(:omg_eth)
    end
  end
end
