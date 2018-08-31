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
  alias OMG.Eth

  @eth Crypto.zero_address()

  def deposit_to_child_chain(to, value, token \\ @eth)

  def deposit_to_child_chain(to, value, @eth) do
    {:ok, deposit_tx_hash} = Eth.RootChain.deposit(value, to)
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.RootChain.deposit_blknum_from_receipt(receipt)

    wait_deposit_recognized(deposit_blknum)

    deposit_blknum
  end

  def deposit_to_child_chain(to, value, token) do
    _ = Eth.Token.mint(to, value, token.address)

    contract_addr = Application.fetch_env!(:omg_eth, :contract_addr)

    Eth.Token.approve(to, contract_addr, value, token.address)

    {:ok, receipt} = Eth.RootChain.deposit_token(to, token.address, value)

    token_deposit_blknum = Eth.RootChain.deposit_blknum_from_receipt(receipt)

    wait_deposit_recognized(token_deposit_blknum)

    token_deposit_blknum
  end

  defp wait_deposit_recognized(deposit_blknum) do
    post_deposit_child_block =
      deposit_blknum - 1 +
        (Application.get_env(:omg_api, :ethereum_event_block_finality_margin) + 1) *
          Application.get_env(:omg_eth, :child_block_interval)

    {:ok, _} = wait_for_current_child_block(post_deposit_child_block, true, 60_000)

    # sleeping some more until when the deposit is spendable
    geth_mining_period_ms = 1000
    Process.sleep(geth_mining_period_ms + Application.get_env(:omg_api, :ethereum_event_check_height_interval_ms) * 3)

    :ok
  end

  def wait_for_current_child_block(blknum, dev \\ false, timeout \\ 10_000, contract \\ nil) do
    f = fn ->
      {:ok, next_num} = Eth.RootChain.get_current_child_block(contract)

      case next_num < blknum do
        true ->
          _ = OMG.Eth.DevGeth.maybe_mine(dev)
          :repeat

        false ->
          {:ok, next_num}
      end
    end

    fn -> Eth.WaitFor.repeat_until_ok(f) end |> Task.async() |> Task.await(timeout)
  end
end
