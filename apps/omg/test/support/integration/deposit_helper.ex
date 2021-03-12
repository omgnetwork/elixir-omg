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

defmodule Support.Integration.DepositHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the child chain and watcher requiring deposits
  """

  alias OMG.Eth.Configuration
  alias OMG.Eth.Encoding
  alias OMG.Eth.Token
  alias OMG.State.Transaction
  alias Support.DevHelper
  alias Support.RootChainHelper

  @eth <<0::160>>

  def deposit_to_child_chain(to, value, token \\ @eth)

  def deposit_to_child_chain(to, value, @eth) do
    {:ok, receipt} =
      Transaction.Payment.new([], [{to, @eth, value}])
      |> Transaction.raw_txbytes()
      |> RootChainHelper.deposit(value, to)
      |> DevHelper.transact_sync!()

    process_deposit(receipt)
  end

  def deposit_to_child_chain(to, value, token_addr) when is_binary(token_addr) and byte_size(token_addr) == 20 do
    contract_addr = Encoding.from_hex(Configuration.contracts().erc20_vault, :mixed)

    {:ok, _} = to |> Token.approve(contract_addr, value, token_addr) |> DevHelper.transact_sync!()

    {:ok, receipt} =
      Transaction.Payment.new([], [{to, token_addr, value}])
      |> Transaction.raw_txbytes()
      |> RootChainHelper.deposit_from(to)
      |> DevHelper.transact_sync!()

    process_deposit(receipt)
  end

  defp process_deposit(%{"blockNumber" => deposit_eth_height} = receipt) do
    _ = wait_deposit_recognized(deposit_eth_height)
    RootChainHelper.deposit_blknum_from_receipt(receipt)
  end

  defp wait_deposit_recognized(deposit_eth_height) do
    post_event_block_finality = deposit_eth_height + OMG.Configuration.deposit_finality_margin()
    {:ok, _} = DevHelper.wait_for_root_chain_block(post_event_block_finality + 1)
    # sleeping until the deposit is spendable
    Process.sleep(Application.fetch_env!(:omg, :ethereum_events_check_interval_ms) * 2)
    :ok
  end
end
