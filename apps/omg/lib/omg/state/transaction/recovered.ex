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

defmodule OMG.State.Transaction.Recovered do
  @moduledoc """
  Representation of a signed transaction, with addresses recovered from signatures (from `OMG.State.Transaction.Signed`)
  Intent is to allow concurrent processing of signatures outside of serial processing in `OMG.State`.

  `Transaction.Recovered` represents a transaction that can be sent to `OMG.State.exec/1`
  """

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @type tx_bytes() :: binary()

  @type recover_tx_error() ::
          :duplicate_inputs
          | :malformed_transaction
          | :malformed_transaction_rlp
          | :signature_corrupt
          | :missing_signature

  defstruct [:signed_tx, :tx_hash, :signed_tx_bytes, :witnesses]

  @type t() :: %__MODULE__{
          tx_hash: Transaction.tx_hash(),
          witnesses: %{non_neg_integer => Transaction.Witness.t()},
          signed_tx: Transaction.Signed.t(),
          signed_tx_bytes: tx_bytes()
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
         do: recover_from_struct(signed_tx, encoded_signed_tx)
  end

  @doc """
  Throwing version of `recover_from/1`
  """
  @spec recover_from!(binary) :: Transaction.Recovered.t()
  def recover_from!(encoded_signed_tx) do
    {:ok, recovered} = Transaction.Recovered.recover_from(encoded_signed_tx)
    recovered
  end

  @spec recover_from_struct(Transaction.Signed.t(), tx_bytes()) :: {:ok, t()} | {:error, recover_tx_error()}
  defp recover_from_struct(%Transaction.Signed{} = signed_tx, signed_tx_bytes) do
    with {:ok, witnesses} <- Transaction.Signed.get_witnesses(signed_tx),
         do:
           {:ok,
            %__MODULE__{
              tx_hash: Transaction.raw_txhash(signed_tx),
              witnesses: witnesses,
              signed_tx: signed_tx,
              signed_tx_bytes: signed_tx_bytes
            }}
  end

  defp valid?(%Transaction.Signed{raw_tx: raw_tx} = tx) do
    with true <- generic_valid?(tx),
         true <- Transaction.Protocol.valid?(raw_tx, tx),
         do: true
  end

  defp generic_valid?(%Transaction.Signed{raw_tx: raw_tx}) do
    inputs = Transaction.get_inputs(raw_tx)

    with true <- no_duplicate_inputs?(inputs) || {:error, :duplicate_inputs},
         do: true
  end

  defp no_duplicate_inputs?(inputs) do
    number_of_unique_inputs =
      inputs
      |> Enum.uniq()
      |> Enum.count()

    inputs_length = Enum.count(inputs)
    inputs_length == number_of_unique_inputs
  end
end
