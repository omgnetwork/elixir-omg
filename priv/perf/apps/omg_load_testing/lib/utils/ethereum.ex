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

defmodule OMG.LoadTesting.Utils.Ethereum do
  @moduledoc """
  Utility module that supports synchronous transaction and creating Ethereum accounts.
  """
  require Logger

  alias ExPlasma.Encoding
  alias OMG.LoadTesting.Utils.Ethereum.Transaction
  alias OMG.LoadTesting.Utils.Ethereum.Transaction.Signature
  alias OMG.LoadTesting.Utils.NonceTracker

  @about_4_blocks_time 120_000
  @eth_amount_to_fund trunc(:math.pow(10, 18) * 0.1)

  @type hash_t() :: <<_::256>>

  @doc """
  Waits until transaction is mined
  Returns transaction receipt updated with Ethereum block number in which the transaction was mined
  """
  @spec transact_sync(hash_t(), pos_integer()) :: {:ok, map()} | {:error, map()}
  def transact_sync(txhash, timeout \\ @about_4_blocks_time) do
    {:ok, _} =
      txhash
      |> eth_receipt(timeout)
      |> case do
        {:ok, %{"status" => "0x1"} = receipt} ->
          {:ok, receipt |> Map.update!("blockNumber", &Encoding.to_int(&1))}

        {:ok, %{"status" => "0x0"} = receipt} ->
          {:error, receipt}

        other ->
          other
      end
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

    OMG.LoadTesting.Utils.Sync.ok(f, timeout)
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

    case Keyword.get(opts, :timeout) do
      nil -> transact_sync(tx_fund)
      timeout -> transact_sync(tx_fund, timeout)
    end
  end

  def send_transaction(txmap), do: Ethereumex.HttpClient.eth_send_transaction(txmap)

  def send_raw_transaction(txmap, sender) do
    {:ok, nonce} = NonceTracker.update_nonce(sender.addr)

    Map.merge(txmap, %{nonce: nonce})
    |> Signature.sign_transaction(sender.priv)
    |> Transaction.serialize()
    |> ExRLP.encode()
    |> Encoding.to_hex()
    |> Ethereumex.HttpClient.eth_send_raw_transaction()
  end

  def get_next_nonce_for_account(address) when byte_size(address) == 20,
    do: get_next_nonce_for_account(ExPlasma.Encoding.to_hex(address))

  def get_next_nonce_for_account("0x" <> _ = address) do
    {:ok, nonce} = Ethereumex.HttpClient.eth_get_transaction_count(address)
    ExPlasma.Encoding.to_int(nonce)
  end
end
