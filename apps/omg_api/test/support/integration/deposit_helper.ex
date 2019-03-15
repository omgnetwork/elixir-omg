# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.Integration.DepositHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the child chain and watcher requiring deposits
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.Eth

  @eth Crypto.zero_address()

  def deposit_to_child_chain(to, value, token \\ @eth)

  def deposit_to_child_chain(to, value, @eth) do
    {:ok, receipt} =
      Transaction.new([], [{to, @eth, value}])
      |> Transaction.encode()
      |> Eth.RootChain.deposit(value, to)
      |> Eth.DevHelpers.transact_sync!()

    process_deposit(receipt)
  end

  def deposit_to_child_chain(to, value, token_addr) when is_number(value) and is_binary(token_addr) and byte_size(token_addr) == 20 do
    contract_addr = Eth.Encoding.from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    to |> Eth.Token.mint(value, token_addr) |> Eth.DevHelpers.transact_sync!()
    to |> Eth.Token.approve(contract_addr, value, token_addr) |> Eth.DevHelpers.transact_sync!()

    {:ok, receipt} =
      Transaction.new([], [{to, token_addr, value}])
      |> Transaction.encode()
      |> Eth.RootChain.deposit_from(to)
      |> Eth.DevHelpers.transact_sync!()

    process_deposit(receipt)
  end

  def deposit_to_child_chain(to, tokenids, nftoken_addr) when is_list(tokenids) and is_binary(nftoken_addr) and byte_size(nftoken_addr) == 20 do
    contract_addr = Eth.Encoding.from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    for t <- tokenids, do: Eth.NFToken.mint(to, t, nftoken_addr) |> Eth.DevHelpers.transact_sync!()
    for t <- tokenids, do: Eth.NFToken.approve(to, contract_addr, t, nftoken_addr) |> Eth.DevHelpers.transact_sync!()

    {:ok, receipt} =
      Transaction.new([], [{to, nftoken_addr, tokenids}])
      |> Transaction.encode()
      |> Eth.RootChain.deposit_from(to)
      |> Eth.DevHelpers.transact_sync!()

    process_deposit(receipt)
  end

  defp process_deposit(%{"blockNumber" => deposit_eth_height} = receipt) do
    deposit_eth_height
    |> wait_deposit_recognized()

    Eth.RootChain.deposit_blknum_from_receipt(receipt)
  end

  defp wait_deposit_recognized(deposit_eth_height) do
    wait_deposit_finality_margin(deposit_eth_height)

    # sleeping some more, until the deposit is spendable
    geth_mining_period_ms = 1000

    Process.sleep(geth_mining_period_ms + Application.fetch_env!(:omg_api, :ethereum_status_check_interval_ms) * 3)

    :ok
  end

  defp wait_deposit_finality_margin(eth_height) do
    post_event_block_finality = eth_height + Application.fetch_env!(:omg_api, :deposit_finality_margin)

    {:ok, _} = Eth.DevHelpers.wait_for_root_chain_block(post_event_block_finality)

    # sleeping until the deposit is spendable
    geth_mining_period_ms = 1000

    Process.sleep(geth_mining_period_ms + Application.fetch_env!(:omg_api, :ethereum_status_check_interval_ms) * 3)

    :ok
  end

#   def wait_for_root_chain_block(blknum, dev \\ false, timeout \\ 10_000) do
#     f = fn ->
#       {:ok, last_blknum} = OMG.Eth.get_ethereum_height()

#       case last_blknum < blknum do
#         true ->
#           _ = OMG.Eth.DevGeth.maybe_mine(dev)
#           :repeat

#         false ->
#           {:ok, last_blknum}
#       end
#     end

#     fn -> Eth.WaitFor.repeat_until_ok(f) end |> Task.async() |> Task.await(timeout)
#   end

#   def wait_ethereum_event_block_finality_margin_for_receipt(receipt) do
#     case receipt["blockNumber"] do
#       "0x" <> blknum_hex ->
#         {blknum, ""} = Integer.parse(blknum_hex, 16)
#         wait_ethereum_event_block_finality_margin(blknum)
#     end
#   end

end
