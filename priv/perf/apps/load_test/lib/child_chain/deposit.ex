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

defmodule LoadTest.ChildChain.Deposit do
  @moduledoc """
  Utility functions for deposits on a child chain
  """
  require Logger

  alias ExPlasma.Encoding
  alias ExPlasma.Transaction.Deposit
  alias ExPlasma.Utxo
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum

  alias LoadTest.Ethereum.Account

  @eth <<0::160>>
  @poll_interval 5_000
  @doc """
  Deposits funds into the childchain.

  If currency is ETH, funds will be deposited into the EthVault.
  If currency is ERC20, 'approve()' will be called before depositing funds into the Erc20Vault.

  Returns the utxo created by the deposit.
  """
  @spec deposit_from(
          LoadTest.Ethereum.Account.t(),
          pos_integer(),
          LoadTest.Ethereum.Account.t(),
          pos_integer(),
          pos_integer()
        ) :: Utxo.t()
  def deposit_from(%Account{} = depositor, amount, currency, deposit_finality_margin, gas_price) do
    deposit_utxo = %Utxo{amount: amount, owner: depositor.addr, currency: currency}
    {:ok, deposit} = Deposit.new(deposit_utxo)
    {:ok, {deposit_blknum, eth_blknum}} = send_deposit(deposit, depositor, amount, currency, gas_price)
    :ok = wait_deposit_finality(eth_blknum, deposit_finality_margin)
    Utxo.new(%{blknum: deposit_blknum, txindex: 0, oindex: 0, amount: amount})
  end

  def approve_token(from, spender, amount, token, opts \\ []) do
    opts = Transaction.tx_defaults() |> Keyword.put(:gas, 80_000) |> Keyword.merge(opts)

    Ethereum.contract_transact(from, token, "approve(address,uint256)", [spender, amount], opts)
  end

  defp send_deposit(deposit, account, value, @eth, gas_price) do
    vault_address = Application.fetch_env!(:load_test, :eth_vault_address)
    do_deposit(vault_address, deposit, account, value, gas_price)
  end

  defp send_deposit(deposit, account, value, erc20_contract, gas_price) do
    vault_address = Application.fetch_env!(:load_test, :erc20_vault_address)

    # First have to approve the token
    {:ok, tx_hash} = approve(erc20_contract, vault_address, account, value, gas_price)
    {:ok, _} = Ethereum.transact_sync(tx_hash)

    # Note that when depositing erc20 tokens, then tx value must be 0
    do_deposit(vault_address, deposit, account, 0, gas_price)
  end

  defp do_deposit(vault_address, deposit, account, value, gas_price) do
    %{data: deposit_data} = LoadTest.Utils.Encoding.encode_deposit(deposit)

    tx = %LoadTest.Ethereum.Transaction{
      to: Encoding.to_binary(vault_address),
      value: value,
      gas_price: gas_price,
      gas_limit: 200_000,
      data: Encoding.to_binary(deposit_data)
    }

    {:ok, tx_hash} = Ethereum.send_raw_transaction(tx, account)
    {:ok, %{"blockNumber" => eth_blknum}} = Ethereum.transact_sync(tx_hash)

    {:ok, %{"logs" => logs}} = Ethereumex.HttpClient.eth_get_transaction_receipt(tx_hash)

    %{"topics" => [_topic, _addr, blknum | _]} =
      Enum.find(logs, fn %{"address" => address} -> address == vault_address end)

    {:ok, {Encoding.to_int(blknum), eth_blknum}}
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

  defp approve(contract, vault_address, account, value, gas_price) do
    data = ABI.encode("approve(address,uint256)", [Encoding.to_binary(vault_address), value])

    tx = %LoadTest.Ethereum.Transaction{
      to: contract,
      gas_price: gas_price,
      gas_limit: 200_000,
      data: data
    }

    Ethereum.send_raw_transaction(tx, account)
  end
end
