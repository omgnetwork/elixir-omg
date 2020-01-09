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

defmodule OMG.Output do
  @moduledoc """
  `OMG.Output` and `OMG.Output.Protocol` represent the outputs of transactions, i.e. the valuables or other pieces of
  data spendable via transactions on the child chain, and/or exitable to the root chain.

  This module specificially dispatches generic calls to the various specific types
  """
  alias OMG.Crypto
  alias OMG.RawData

  @type t :: %__MODULE__{
          output_type: binary(),
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer()
        }

  defstruct [:output_type, :owner, :currency, :amount]

  @doc """
  Reconstructs the structure from a list of RLP items
  """
  def reconstruct([raw_type, [_owner, _currency, _amount]] = rlp_data) when is_binary(raw_type) do
    with :ok <- validate_data(rlp_data),
         {:ok, utxo} <- ExPlasma.Utxo.new(rlp_data),
         do: %__MODULE__{output_type: utxo.output_type, owner: utxo.owner, currency: utxo.currency, amount: utxo.amount}
  end

  def reconstruct([_raw_type, [_owner, _currency, _amount]]), do: {:error, :unrecognized_output_type}
  def reconstruct(_), do: {:error, :malformed_outputs}

  def from_db_value(%{owner: owner, currency: currency, amount: amount, output_type: output_type})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_integer(output_type) do
    %__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type}
  end

  def to_db_value(%__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_integer(output_type) do
    %{owner: owner, currency: currency, amount: amount, output_type: output_type}
  end

  def get_data_for_rlp(%__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type}),
    do: [output_type, [owner, currency, amount]]

  # TODO(achiurizo)
  # remove the validation here and port the error tuple response handling into ex_plasma.
  defp validate_data([raw_type, [owner, currency, amount]]) do
    with {:ok, _} <- RawData.parse_uint256(raw_type),
         {:ok, _} <- valid_output_type?(raw_type),
         {:ok, _} <- RawData.parse_address(owner),
         {:ok, _} <- non_zero_owner?(owner),
         {:ok, _} <- RawData.parse_address(currency),
         {:ok, _} <- RawData.parse_amount(amount),
         do: :ok
  end

  defp non_zero_owner?(<<0::160>>), do: {:error, :output_guard_cant_be_zero}
  defp non_zero_owner?(_), do: {:ok, :valid}

  defp valid_output_type?(type) when type in [<<1>>, <<2>>], do: {:ok, :valid}
  defp valid_output_type?(_), do: {:error, :unrecognized_output_type}
end
