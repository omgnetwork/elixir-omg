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

defmodule LoadTest.Scenario.ManyStandardExits do
  @moduledoc """
  Creates and funds an account, creates many utxos and starts a standard exit on each utxo

  ## configuration values
  - `exits_per_session` the number od utxos to create and then exit
  """

  use Chaperon.Scenario

  alias LoadTest.ChildChain.WatcherSync
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet

  @gas_start_exit 500_000
  @standard_exit_bond 14_000_000_000_000_000

  def run(session) do
    exits_per_session = config(session, [:exits_per_session])
    gas_price = config(session, [:gas_price])

    # Create a new exiter account
    {:ok, exiter} = Account.new()
    amount = (@gas_start_exit * gas_price + @standard_exit_bond) * exits_per_session

    # Fund the exiter with some root chain eth
    {:ok, _} = Faucet.fund_root_chain_account(exiter.addr, amount)

    # Create many utxos on the child chain
    session =
      run_scenario(session, LoadTest.Scenario.CreateUtxos, %{
        sender: exiter,
        transactions_per_session: 1,
        utxos_to_create_per_session: exits_per_session
      })

    # Wait for the last utxo to seen by the watcher
    :ok = LoadTest.ChildChain.Utxos.wait_for_utxo(exiter.addr, session.assigned.utxo)

    # Start a standard exit on each of the exiter's utxos
    session =
      exiter.addr
      |> LoadTest.ChildChain.Utxos.get_utxos()
      |> Enum.map(&exit_utxo(session, &1, exiter))
      |> List.first()

    last_tx_hash = session.assigned.tx_hash
    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} = Ethereum.transact_sync(last_tx_hash)

    :ok = WatcherSync.watcher_synchronize(root_chain_height: last_exit_height)

    log_info(session, "Many Standard Exits Test done.")
  end

  def exit_utxo(session, utxo, exiter) do
    run_scenario(
      session,
      LoadTest.Scenario.StartStandardExit,
      %{
        exiter: exiter,
        utxo: utxo
      }
    )
  end
end
