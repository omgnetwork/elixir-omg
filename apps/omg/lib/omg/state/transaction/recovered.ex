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
  Representation of a signed transaction, with addresses recovered from signatures (from `OMG.State.Transaction.Signed`)
  Intent is to allow concurrent processing of signatures outside of serial processing in `OMG.State`.

  `Transaction.Recovered` represents a transaction that can be sent to `OMG.State.exec/1`
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
         true <- valid?(signed_tx),
         do: recover_from_struct(signed_tx)
  end

  @doc """
  Throwing version of `recover_from/1`
  """
  @spec recover_from!(binary) :: Transaction.Recovered.t()
  def recover_from!(encoded_signed_tx) do
    {:ok, recovered} = Transaction.Recovered.recover_from(encoded_signed_tx)
    recovered
  end

  @doc """
  Checks if input spenders and recovered transaction's spenders are the same and have the same order
  """
  @spec all_spenders_authorized(t(), list()) :: :ok | {:error, :unauthorized_spent}
  def all_spenders_authorized(%__MODULE__{spenders: spenders}, inputs_spenders) do
    if spenders == inputs_spenders, do: :ok, else: {:error, :unauthorized_spent}
  end

  @spec recover_from_struct(Transaction.Signed.t()) :: {:ok, t()} | {:error, recover_tx_error()}
  defp recover_from_struct(%Transaction.Signed{} = signed_tx) do
    with {:ok, spenders} <- Transaction.Signed.get_spenders(signed_tx),
         do: {:ok, %__MODULE__{tx_hash: Transaction.raw_txhash(signed_tx), spenders: spenders, signed_tx: signed_tx}}
  end

  defp valid?(%Transaction.Signed{sigs: sigs} = tx) do
    inputs = Transaction.get_inputs(tx)

    with true <- no_duplicate_inputs?(inputs) || {:error, :duplicate_inputs},
         do: all_inputs_signed?(inputs, sigs)
  end

  defp no_duplicate_inputs?(inputs) do
    number_of_unique_inputs =
      inputs
      |> Enum.uniq()
      |> Enum.count()

    inputs_length = Enum.count(inputs)
    inputs_length == number_of_unique_inputs
  end

  defp all_inputs_signed?(non_zero_inputs, sigs) do
    count_non_zero_signatures = Enum.count(sigs, &(&1 != @empty_signature))
    count_non_zero_inputs = length(non_zero_inputs)

    cond do
      count_non_zero_signatures > count_non_zero_inputs -> {:error, :superfluous_signature}
      count_non_zero_signatures < count_non_zero_inputs -> {:error, :missing_signature}
      true -> true
    end
  end
end
