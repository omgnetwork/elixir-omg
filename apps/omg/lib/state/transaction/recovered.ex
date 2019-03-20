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

defmodule OMG.State.Transaction.Recovered do
  @moduledoc """
  Representation of a Signed transaction, with addresses recovered from signatures (from `OMG.State.Transaction.Signed`)
  Intent is to allow concurrent processing of signatures outside of serial processing in `OMG.State`
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @empty_signature <<0::size(520)>>

  @type recover_tx_error() ::
          :bad_signature_length
          | :duplicate_inputs
          | :malformed_transaction
          | :malformed_transaction_rlp
          | :signature_corrupt
          | :missing_signature

  defstruct [:signed_tx, :tx_hash, spenders: nil]

  @type t() :: %__MODULE__{
          tx_hash: Transaction.tx_hash(),
          spenders: [Crypto.address_t()],
          signed_tx: Transaction.Signed.t()
        }

  @doc """
  Transforms a RLP-encoded child chain transaction (binary) into a:
    - decoded
    - statelessly valid (mainly inputs logic)
    - recovered (i.e. signatures get recovered into spenders)
  transaction

   See docs/transaction_validation.md for more information about stateful and stateless validation.
  """
  @spec recover_from(binary) :: {:ok, Transaction.Recovered.t()} | {:error, recover_tx_error()}
  def recover_from(encoded_signed_tx) do
    with {:ok, signed_tx} <- Transaction.Signed.decode(encoded_signed_tx),
         :ok <- valid?(signed_tx),
         do: recover_from_struct(signed_tx)
  end

  @doc """
  Checks if input spenders and recovered transaction's spenders are the same and have the same order
  """
  @spec all_spenders_authorized(t(), list()) :: :ok | {:error, :unauthorized_spent}
  def all_spenders_authorized(%__MODULE__{spenders: spenders}, inputs_spenders) do
    if spenders == inputs_spenders, do: :ok, else: {:error, :unauthorized_spent}
  end

  @spec recover_from_struct(Transaction.Signed.t()) :: {:ok, t()} | {:error, recover_tx_error()}
  defp recover_from_struct(%Transaction.Signed{raw_tx: raw_tx, sigs: sigs} = signed_tx) do
    hash_without_sigs = Transaction.hash(raw_tx)

    with {:ok, reversed_spenders} <- get_reversed_spenders(hash_without_sigs, sigs),
         do:
           {:ok,
            %__MODULE__{
              tx_hash: Transaction.hash(raw_tx),
              spenders: reversed_spenders |> Enum.reverse(),
              signed_tx: signed_tx
            }}
  end

  defp get_reversed_spenders(hash_without_sigs, sigs) do
    sigs
    |> Enum.filter(fn sig -> sig != @empty_signature end)
    |> Enum.reduce_while({:ok, []}, fn sig, acc -> get_spender(hash_without_sigs, sig, acc) end)
  end

  defp get_spender(hash_without_sigs, sig, {:ok, spenders}) do
    Crypto.recover_address(hash_without_sigs, sig)
    |> case do
      {:ok, spender} -> {:cont, {:ok, [spender | spenders]}}
      error -> {:halt, error}
    end
  end

  defp valid?(%Transaction.Signed{
         raw_tx: raw_tx,
         sigs: sigs
       }) do
    inputs = Transaction.get_inputs(raw_tx)

    with :ok <- no_duplicate_inputs?(inputs) do
      all_inputs_signed?(inputs, sigs)
    end
  end

  defp no_duplicate_inputs?(inputs) do
    inputs =
      inputs
      |> Enum.filter(&Utxo.Position.non_zero?/1)

    number_of_unique_inputs =
      inputs
      |> Enum.uniq()
      |> Enum.count()

    inputs_length = Enum.count(inputs)

    if inputs_length == number_of_unique_inputs, do: :ok, else: {:error, :duplicate_inputs}
  end

  defp all_inputs_signed?(inputs, sigs) do
    Enum.zip(inputs, sigs)
    |> Enum.map(&input_signature_valid/1)
    |> Enum.find(:ok, &(&1 != :ok))
  end

  defp input_signature_valid({Utxo.position(0, _, _), @empty_signature}), do: :ok
  defp input_signature_valid({Utxo.position(0, _, _), _}), do: {:error, :signature_corrupt}
  defp input_signature_valid({_, @empty_signature}), do: {:error, :missing_signature}
  defp input_signature_valid({_, _}), do: :ok
end
