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

defmodule OMG.API.Core do
  @moduledoc """
  Functional core work-horse for `OMG.API`.
  """
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo

  require Utxo

  @empty_signature <<0::size(520)>>

  @type recover_tx_error() ::
          :bad_signature_length
          | :duplicate_inputs
          | :malformed_transaction
          | :malformed_transaction_rlp
          | :no_inputs
          | :signature_corrupt
          | :missing_signature

  @doc """
  Transforms a RLP-encoded child chain transaction (binary) into a:
    - decoded
    - statelessly valid (mainly inputs logic)
    - recovered (i.e. signatures get recovered into spenders)
  transaction

   See docs/transaction_validation.md for more information about stateful and stateless validation.
  """
  @spec recover_tx(binary) ::
          {:ok, Transaction.Recovered.t()}
          | {:error, recover_tx_error()}
  def recover_tx(encoded_signed_tx) do
    with {:ok, signed_tx} <- Transaction.Signed.decode(encoded_signed_tx),
         :ok <- valid?(signed_tx),
         do: Transaction.Recovered.recover_from(signed_tx)
  end

  defp valid?(%Transaction.Signed{
         raw_tx: raw_tx,
         sigs: sigs
       }) do
    inputs = Transaction.get_inputs(raw_tx)

    with :ok <- inputs_present?(inputs),
         :ok <- no_duplicate_inputs?(inputs) do
      is_signed?(sigs)
    end
  end

  defp inputs_present?(inputs) do
    inputs_present =
      inputs
      |> Enum.any?(fn Utxo.position(blknum, _, _) -> blknum != 0 end)

    if inputs_present, do: :ok, else: {:error, :no_inputs}
  end

  defp no_duplicate_inputs?(inputs) do
    inputs =
      inputs
      |> Enum.filter(fn Utxo.position(blknum, _, _) -> blknum != 0 end)

    number_of_unique_inputs =
      inputs
      |> Enum.uniq()
      |> Enum.count()

    inputs_length = Enum.count(inputs)

    if inputs_length == number_of_unique_inputs, do: :ok, else: {:error, :duplicate_inputs}
  end

  defp is_signed?(sigs), do: if(Enum.any?(sigs, &(&1 != @empty_signature)), do: :ok, else: {:error, :missing_signature})
end
