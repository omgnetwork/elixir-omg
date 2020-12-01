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

defmodule LoadTest.Ethereum do
  @moduledoc """
  Support for synchronous transactions.
  """
  require Logger

  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Abi
  alias LoadTest.Ethereum.Account
  alias LoadTest.Ethereum.NonceTracker
  alias LoadTest.Ethereum.Transaction
  alias LoadTest.Ethereum.Transaction.Signature
  alias LoadTest.Service.Sync

  @about_4_blocks_time 120_000
  @poll_timeout 60_000

  @type hash_t() :: <<_::256>>

  @doc """
  Send transaction to be singed by a key managed by Ethereum node, geth or parity.
  For geth, account must be unlocked externally.
  If using parity, account passphrase must be provided directly or via config.
  """
  @spec contract_transact(<<_::160>>, <<_::160>>, binary, [any]) :: {:ok, <<_::256>>} | {:error, any}
  def contract_transact(from, to, signature, args, opts \\ []) do
    data = encode_tx_data(signature, args)

    txmap =
      %{from: Encoding.to_hex(from), to: Encoding.to_hex(to), data: data}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    case Ethereumex.HttpClient.eth_send_transaction(txmap) do
      {:ok, receipt_enc} -> {:ok, Encoding.to_binary(receipt_enc)}
      other -> other
    end
  end

  @spec get_gas_used(String.t()) :: non_neg_integer()
  def get_gas_used(receipt_hash) do
    {{:ok, %{"gasUsed" => gas_used}}, {:ok, %{"gasPrice" => gas_price}}} =
      {Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash),
       Ethereumex.HttpClient.eth_get_transaction_by_hash(receipt_hash)}

    {gas_price_value, ""} = gas_price |> String.replace_prefix("0x", "") |> Integer.parse(16)
    {gas_used_value, ""} = gas_used |> String.replace_prefix("0x", "") |> Integer.parse(16)

    gas_price_value * gas_used_value
  end

  @doc """
  Waits until transaction is mined
  Returns transaction receipt updated with Ethereum block number in which the transaction was mined
  """
  @spec transact_sync(hash_t(), pos_integer()) :: {:ok, map()}
  def transact_sync(txhash, timeout \\ @about_4_blocks_time) do
    {:ok, %{"status" => "0x1"} = receipt} = eth_receipt(txhash, timeout)
    {:ok, Map.update!(receipt, "blockNumber", &Encoding.to_int(&1))}
  end

  def block_hash(mined_num) do
    contract_address = Application.fetch_env!(:load_test, :contract_address_plasma_framework)

    %{"block_hash" => block_hash, "block_timestamp" => block_timestamp} =
      get_external_data(contract_address, "blocks(uint256)", [mined_num])

    {block_hash, block_timestamp}
  end

  def send_raw_transaction(txmap, sender) do
    nonce = NonceTracker.get_next_nonce(sender.addr)

    txmap
    |> Map.merge(%{nonce: nonce})
    |> Signature.sign_transaction(sender.priv)
    |> Transaction.serialize()
    |> ExRLP.encode()
    |> Encoding.to_hex()
    |> Ethereumex.HttpClient.eth_send_raw_transaction()
  end

  def get_next_nonce_for_account(address) when byte_size(address) == 20 do
    address
    |> ExPlasma.Encoding.to_hex()
    |> get_next_nonce_for_account()
  end

  def get_next_nonce_for_account("0x" <> _ = address) do
    {:ok, nonce} = Ethereumex.HttpClient.eth_get_transaction_count(address)
    Encoding.to_int(nonce)
  end

  def wait_for_root_chain_block(awaited_eth_height, timeout \\ 600_000) do
    f = fn ->
      {:ok, eth_height} =
        case Ethereumex.HttpClient.eth_block_number() do
          {:ok, height_hex} ->
            {:ok, Encoding.to_int(height_hex)}

          other ->
            other
        end

      if eth_height < awaited_eth_height, do: :repeat, else: {:ok, eth_height}
    end

    Sync.repeat_until_success(f, timeout, "Failed to fetch eth block number")
  end

  @spec fetch_balance(Account.addr_t(), Account.addr_t()) :: non_neg_integer() | no_return()
  def fetch_balance(address, <<0::160>>) do
    {:ok, initial_balance} =
      Sync.repeat_until_success(
        fn ->
          address
          |> Encoding.to_hex()
          |> eth_account_get_balance()
        end,
        @poll_timeout,
        "Failed to fetch eth balance from rootchain"
      )

    {initial_balance, ""} = initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)
    initial_balance
  end

  def fetch_balance(address, currency) do
    Sync.repeat_until_success(
      fn ->
        do_root_chain_get_erc20_balance(address, currency)
      end,
      @poll_timeout,
      "Failed to fetch erc20 balance from rootchain"
    )
  end

  defp eth_account_get_balance(address) do
    Ethereumex.HttpClient.eth_get_balance(address)
  end

  defp do_root_chain_get_erc20_balance(address, currency) do
    data = ABI.encode("balanceOf(address)", [Encoding.to_binary(address)])

    case Ethereumex.HttpClient.eth_call(%{
           from: Encoding.to_hex(currency),
           to: Encoding.to_hex(currency),
           data: Encoding.to_hex(data)
         }) do
      {:ok, result} ->
        balance =
          result
          |> Encoding.to_binary()
          |> ABI.TypeDecoder.decode([{:uint, 256}])
          |> hd()

        {:ok, balance}

      error ->
        error
    end
  end

  defp get_external_data(address, signature, params) do
    data = signature |> ABI.encode(params) |> Encoding.to_hex()

    {:ok, data} = Ethereumex.HttpClient.eth_call(%{from: address, to: address, data: data})

    Abi.decode_function(data, signature)
  end

  defp eth_receipt(txhash, timeout) do
    f = fn ->
      txhash
      |> Ethereumex.HttpClient.eth_get_transaction_receipt()
      |> case do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end

    Sync.repeat_until_success(f, timeout, "Failed to fetch eth receipt")
  end

  defp encode_tx_data(signature, args) do
    signature
    |> ABI.encode(args)
    |> Encoding.to_hex()
  end

  defp encode_all_integer_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> is_integer(v) end)
    |> Enum.into(opts, fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end
end
