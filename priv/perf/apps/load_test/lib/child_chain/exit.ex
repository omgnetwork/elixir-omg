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

defmodule LoadTest.ChildChain.Exit do
  @moduledoc """
  Utility functions for exits on a child chain.
  """

  require Logger

  import LoadTest.Service.Sleeper

  alias ExPlasma.Encoding
  alias ExPlasma.Utxo
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Account
  alias LoadTest.Ethereum.Crypto

  @gas_start_exit 500_000
  @gas_challenge_exit 300_000
  @gas_add_exit_queue 800_000
  @standard_exit_bond 14_000_000_000_000_000

  @doc """
  Returns the exit data of a utxo.
  """
  @spec get_exit_data(Utxo.t()) :: any()
  def get_exit_data(%Utxo{} = utxo), do: get_exit_data(Utxo.pos(utxo))

  @spec get_exit_data(non_neg_integer()) :: any()
  def get_exit_data(utxo_pos) do
    body = %WatcherSecurityCriticalAPI.Model.UtxoPositionBodySchema{
      utxo_pos: utxo_pos
    }

    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.UTXO.utxo_get_exit_data(
        LoadTest.Connection.WatcherSecurity.client(),
        body
      )

    data = Jason.decode!(response.body)["data"]

    %{
      proof: data["proof"],
      txbytes: data["txbytes"],
      utxo_pos: data["utxo_pos"]
    }
  end

  @doc """
  Retries until the exit data of a utxo is found.
  """
  @spec wait_for_exit_data(Utxo.t(), pos_integer()) :: any()
  def wait_for_exit_data(utxo_pos, counter \\ 10)
  def wait_for_exit_data(_, 0), do: :error

  def wait_for_exit_data(utxo_pos, counter) do
    data = get_exit_data(utxo_pos)

    case data.proof do
      nil ->
        sleep("Waiting for exit data")
        wait_for_exit_data(utxo_pos, counter - 1)

      _ ->
        data
    end
  end

  @doc """
  Starts an exit.
  """
  @spec start_exit(any(), Account.t(), pos_integer()) :: any()
  def start_exit(exit_data, from, gas_price) do
    data =
      ABI.encode(
        "startStandardExit((uint256,bytes,bytes))",
        [
          {
            exit_data.utxo_pos,
            Encoding.to_binary(exit_data.txbytes),
            Encoding.to_binary(exit_data.proof)
          }
        ]
      )

    tx = %Ethereum.Transaction{
      to: contract_address_payment_exit_game(),
      value: @standard_exit_bond,
      gas_price: gas_price,
      gas_limit: @gas_start_exit,
      data: data
    }

    {:ok, tx_hash} = Ethereum.send_raw_transaction(tx, from)
    tx_hash
  end

  def add_exit_queue(vault_id, token, from, gas_price) do
    if has_exit_queue?(vault_id, token) do
      _ = Logger.info("Exit queue was already added.")
    else
      _ = Logger.info("Exit queue missing. Adding...")

      data =
        ABI.encode(
          "addExitQueue(uint256,address)",
          [vault_id, token]
        )

      tx = %Ethereum.Transaction{
        to: Encoding.to_binary(Application.fetch_env!(:load_test, :contract_address_plasma_framework)),
        gas_price: gas_price,
        gas_limit: @gas_add_exit_queue,
        data: data
      }

      {:ok, receipt_hash} = Ethereum.send_raw_transaction(tx, from)
      Ethereum.transact_sync(receipt_hash)
      wait_for_exit_queue(vault_id, token, 100)
      receipt_hash
    end
  end

  defp wait_for_exit_queue(_vault_id, _token, 0), do: exit(1)

  defp wait_for_exit_queue(vault_id, token, counter) do
    if has_exit_queue?(vault_id, token) do
      :ok
    else
      sleep("waiting for exit queue")
      wait_for_exit_queue(vault_id, token, counter - 1)
    end
  end

  defp has_exit_queue?(vault_id, token) do
    data =
      ABI.encode(
        "hasExitQueue(uint256,address)",
        [vault_id, token]
      )

    {:ok, receipt_enc} =
      Ethereumex.HttpClient.eth_call(%{
        to: Application.fetch_env!(:load_test, :contract_address_plasma_framework),
        data: Encoding.to_hex(data)
      })

    receipt_enc
    |> Encoding.to_binary()
    |> ABI.TypeDecoder.decode([:bool])
    |> hd()
  end

  def challenge_exit(exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, from) do
    opts = Keyword.put(tx_defaults(), :gas, @gas_challenge_exit)
    sender_data = Crypto.hash(from)

    contract = contract_address_payment_exit_game()
    signature = "challengeStandardExit((uint160,bytes,bytes,uint16,bytes,bytes32))"
    args = [{exit_id, exiting_tx, challenge_tx, input_index, challenge_tx_sig, sender_data}]

    {:ok, transaction_hash} = Ethereum.contract_transact(from, contract, signature, args, opts)

    Encoding.to_hex(transaction_hash)
  end

  def tx_defaults() do
    Transaction.tx_defaults()
  end

  defp contract_address_payment_exit_game() do
    :load_test
    |> Application.fetch_env!(:contract_address_payment_exit_game)
    |> Encoding.to_binary()
  end
end
