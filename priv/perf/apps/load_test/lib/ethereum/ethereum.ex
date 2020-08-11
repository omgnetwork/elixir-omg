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

defmodule LoadTest.Ethereum do
  @moduledoc """
  Support for synchronous transactions.
  """
  require Logger

  alias ExPlasma.Encoding
  alias LoadTest.Ethereum.NonceTracker
  alias LoadTest.Ethereum.Sync
  alias LoadTest.Ethereum.Transaction
  alias LoadTest.Ethereum.Transaction.Signature

  @about_4_blocks_time 120_000
  @eth_amount_to_fund trunc(:math.pow(10, 18) * 0.1)

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
      {:ok, receipt_enc} -> {:ok, Encoding.from_hex(receipt_enc)}
      other -> other
    end
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

  def fund_address_from_default_faucet(account, opts) do
    {:ok, [default_faucet | _]} = Ethereumex.HttpClient.eth_accounts()
    defaults = [faucet: default_faucet, initial_funds_wei: @eth_amount_to_fund]

    %{faucet: faucet, initial_funds_wei: initial_funds_wei} =
      defaults
      |> Keyword.merge(opts)
      |> Enum.into(%{})

    params = %{from: faucet, to: Encoding.to_hex(account.addr), value: Encoding.to_hex(initial_funds_wei)}

    {:ok, tx_fund} = send_transaction(params)

    transact_sync(tx_fund)
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

  defp send_transaction(txmap), do: Ethereumex.HttpClient.eth_send_transaction(txmap)

  defp eth_receipt(txhash, timeout) do
    f = fn ->
      txhash
      |> Ethereumex.HttpClient.eth_get_transaction_receipt()
      |> case do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end

    Sync.repeat_until_success(f, timeout)
  end
end
