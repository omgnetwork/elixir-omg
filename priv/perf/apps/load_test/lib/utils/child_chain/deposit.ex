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

defmodule LoadTest.Utils.ChildChain.Deposit do
  @moduledoc """
  Utility functions for deposits on a child chain
  """
  require Logger

  alias ExPlasma.Encoding
  alias ExPlasma.Transaction.Deposit
  alias ExPlasma.Utxo
  alias LoadTest.Utils.Ethereum
  alias LoadTest.Utils.Ethereum.Account

  @eth <<0::160>>
  @poll_interval 5_000

  def deposit_from(%Account{} = depositor, amount, currency, deposit_finality_margin) do
    deposit_utxo = %Utxo{amount: amount, owner: depositor.addr, currency: currency}
    {:ok, deposit} = Deposit.new(deposit_utxo)
    {:ok, {deposit_blknum, eth_blknum}} = send_deposit(deposit, depositor, amount, currency)
    :ok = wait_deposit_finality(eth_blknum, deposit_finality_margin)
    Utxo.new(%{blknum: deposit_blknum, txindex: 0, oindex: 0})
  end

  defp send_deposit(deposit, account, value, @eth) do
    eth_vault_address = Application.fetch_env!(:ex_plasma, :eth_vault_address)
    %{data: deposit_data} = LoadTest.Utils.Encoding.encode_deposit(deposit)

    tx = %LoadTest.Utils.Ethereum.Transaction{
      to: Encoding.to_binary(eth_vault_address),
      value: value,
      gas_price: 20_000_000,
      gas_limit: 200_000,
      init: <<>>,
      data: Encoding.to_binary(deposit_data)
    }

    {:ok, tx_hash} = Ethereum.send_raw_transaction(tx, account)
    {:ok, %{"blockNumber" => eth_blknum}} = Ethereum.transact_sync(tx_hash)

    {:ok, %{"logs" => logs}} = Ethereumex.HttpClient.eth_get_transaction_receipt(tx_hash)

    deposit_blknum =
      logs
      |> Enum.map(fn %{"topics" => topics} -> topics end)
      |> Enum.map(fn [_topic, _addr, blknum | _] -> blknum end)
      |> hd()
      |> Encoding.to_int()

    {:ok, {deposit_blknum, eth_blknum}}
  end

  defp wait_deposit_finality(deposit_eth_blknum, finality_margin) do
    {:ok, current_blknum} = Ethereumex.HttpClient.eth_block_number()
    current_blknum = Encoding.to_int(current_blknum)

    if current_blknum >= deposit_eth_blknum + finality_margin do
      :ok
    else
      _ = Logger.info("Waiting for deposit finality")
      Process.sleep(@poll_interval)
      wait_deposit_finality(deposit_eth_blknum, finality_margin)
    end
  end
end
