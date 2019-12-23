# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Output do
  @moduledoc """
  `OMG.Output` and `OMG.Output.Protocol` represent the outputs of transactions, i.e. the valuables or other pieces of
  data spendable via transactions on the child chain, and/or exitable to the root chain.

  This module specificially dispatches generic calls to the various specific types
  """
  alias OMG.Crypto

  @type t :: %__MODULE__{
          output_type: binary(),
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer()
        }

  defstruct [:output_type, :owner, :currency, :amount]

  alias OMG.RawData
  alias OMG.Utxo

  require Utxo

  @output_types_modules OMG.WireFormatTypes.output_type_modules()
  @output_types Map.keys(@output_types_modules)

  def reconstruct([raw_type, rlp_decoded_chunks]) when is_binary(raw_type) do
    case RawData.parse_uint256(raw_type) do
      {:ok, output_type} when output_type in @output_types ->
        reconstruct([output_type, rlp_decoded_chunks])

      {:ok, _unrecognized_type} ->
        {:error, :unrecognized_output_type}
    end
  end

  @doc """
  Reconstructs the structure from a list of RLP items
  """
  def reconstruct([output_type, [owner_rlp, currency_rlp, amount_rlp]]) do
    with {:ok, cur12} <- RawData.parse_address(currency_rlp),
         {:ok, owner} <- RawData.parse_address(owner_rlp),
         :ok <- non_zero_owner(owner),
         {:ok, amount} <- RawData.parse_amount(amount_rlp),
         do: %__MODULE__{output_type: output_type, owner: owner, currency: cur12, amount: amount}
  end

  def reconstruct(_), do: {:error, :malformed_outputs}

  defp non_zero_owner(<<0::160>>), do: {:error, :output_guard_cant_be_zero}
  defp non_zero_owner(_), do: :ok

  def dispatching_reconstruct(_), do: {:error, :malformed_outputs}

  def from_db_value(%{type: output_type} = db_value), do: @output_types_modules[output_type].from_db_value(db_value)

  def from_db_value(%{owner: owner, currency: currency, amount: amount, output_type: output_type})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_integer(output_type) do
    %__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type}
  end

  @doc """
  For payment outputs, a binary witness is assumed to be a signature equal to the payment's output owner
  """
  def can_spend?(%__MODULE__{owner: owner}, witness, _raw_tx) when is_binary(witness) do
    owner == witness
  end

  def input_pointer(%__MODULE__{}, blknum, tx_index, oindex, _, _),
    do: Utxo.position(blknum, tx_index, oindex)

  def to_db_value(%__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_integer(output_type) do
    %{owner: owner, currency: currency, amount: amount, output_type: output_type}
  end

  def get_data_for_rlp(%__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type}),
    do: [output_type, [owner, currency, amount]]
end
