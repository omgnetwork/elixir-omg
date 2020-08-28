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
  alias LoadTest.ChildChain.Abi
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

  def deposit_to_child_chain(to, value) do
    deposit_to_child_chain(to, value, <<0::160>>)
  end

  def deposit_to_child_chain(to, value, <<0::160>>) do
    {:ok, receipt} =
      encode_payment_transaction([], [{to, <<0::160>>, value}])
      |> deposit_transaction(value, to)
      |> Ethereum.transact_sync()

    process_deposit(receipt)
  end

  def deposit_to_child_chain(to, value, token_addr) do
    contract_addr = Application.fetch_env!(:load_test, :erc20_vault_address)

    {:ok, _} = to |> approve_token(contract_addr, value, token_addr) |> Ethereum.transact_sync()

    {:ok, receipt} =
      encode_payment_transaction([], [{to, token_addr, value}])
      |> deposit_transaction_from(to)
      |> Ethereum.transact_sync()

    process_deposit(receipt)
  end

  def approve_token(from, spender, amount, token, opts \\ []) do
    opts = Transaction.tx_defaults() |> Keyword.put(:gas, 80_000) |> Keyword.merge(opts)

    Ethereum.contract_transact(from, token, "approve(address,uint256)", [spender, amount], opts)
  end

  defp process_deposit(%{"blockNumber" => deposit_eth_height} = receipt) do
    _ = wait_deposit_recognized(deposit_eth_height)

    deposit_blknum_from_receipt(receipt)
  end

  defp wait_deposit_recognized(deposit_eth_height) do
    post_event_block_finality = deposit_eth_height + Application.fetch_env!(:load_test, :deposit_finality_margin)
    {:ok, _} = Ethereum.wait_for_root_chain_block(post_event_block_finality + 1)
    # sleeping until the deposit is spendable
    Process.sleep(800 * 2)
    :ok
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

  defp encode_payment_transaction(inputs, outputs, metadata \\ <<0::256>>) do
    ExRLP.encode([
      1,
      Enum.map(inputs, fn {blknum, txindex, oindex} ->
        ExPlasma.Utxo.to_rlp(%ExPlasma.Utxo{blknum: blknum, txindex: txindex, oindex: oindex})
      end),
      Enum.map(outputs, fn {owner, currency, amount} ->
        [1, [owner, currency, amount]]
      end),
      0,
      metadata
    ])
  end

  defp deposit_transaction(tx, value, from) do
    opts = Transaction.tx_defaults() |> Keyword.put(:gas, 180_000) |> Keyword.put(:value, value)

    contract = :load_test |> Application.fetch_env!(:eth_vault_address) |> Encoding.to_binary()

    {:ok, transaction_hash} = Ethereum.contract_transact(from, contract, "deposit(bytes)", [tx], opts)

    Encoding.to_hex(transaction_hash)
  end

  defp deposit_transaction_from(tx, from) do
    opts = Keyword.put(Transaction.tx_defaults(), :gas, 250_000)

    contract = Application.fetch_env!(:load_test, :erc20_vault_address)

    {:ok, transaction_hash} = Ethereum.contract_transact(from, contract, "deposit(bytes)", [tx], opts)

    Encoding.to_hex(transaction_hash)
  end

  defp deposit_blknum_from_receipt(%{"logs" => logs}) do
    topic =
      "DepositCreated(address,uint256,address,uint256)"
      |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
      |> Encoding.to_hex()

    [%{blknum: deposit_blknum}] =
      logs
      |> Enum.filter(&(topic in &1["topics"]))
      |> Enum.map(&Abi.decode_log/1)

    deposit_blknum
  end
end
