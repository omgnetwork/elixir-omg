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
  `OMG.Output` represent the outputs of transactions, i.e. the valuables or other pieces of
  data spendable via transactions on the child chain, and/or exitable to the root chain.

  This module specificially dispatches generic calls to the various specific types
  """

  @type t :: %__MODULE__{
          output_type: binary(),
          owner: OMG.Crypto.address_t(),
          currency: OMG.Crypto.address_t(),
          amount: non_neg_integer()
        }

  @output_type_marker <<1>>

  defstruct [:output_type, :owner, :currency, :amount]

  # TODO(achiurizo)
  # Need to fix that this method is able to re-build from it's own generated rlp data.
  # ex: [<<1>>, <<1::160>>, <<1::160>>, 1] (last number is an integer instead of binary)
  @doc """
  Returns a OMG.Output struct from a map

  ## Examples

      # Converts a map into an OMG.Output 
      iex> output = %{owner: <<1::160>>, currency: <<1::160>>, amount: 1}
      iex> OMG.Output.new(output)
      %OMG.Output{owner: <<1::160>>, currency: <<1::160>>, amount: 1}

      # Converts an RLP data list into a output utxo struct.
      iex> rlp_data = [<<1>>, <<1::160>>, <<1::160>>, <<1>>]
      iex> OMG.Output.new(rlp_data)
      %OMG.Output{owner: <<1::160>>, currency: <<1::160>>, amount: 1}
  """
  def new(%{owner: owner, currency: currency, amount: amount})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) do
    %__MODULE__{owner: owner, currency: currency, amount: amount}
  end

  def new([@output_type_marker | rest_of_rlp_data]), do: reconstruct(rest_of_rlp_data)
  def new(_), do: {:error, :unrecognized_output_type}

  # TODO(achiurizo)
  # refactor this? WE don't need this?
  @doc """
  Returns a boolean if the binary witness is equal to the payment output's owner.

  # Examples

      iex> output = %OMG.Output{owner: <<1::160>>}
      iex> OMG.Output.can_spend?(output, <<1::160>>, nil)
      true
  """
  def can_spend?(%OMG.Output{owner: owner}, witness, _raw_tx) when is_binary(witness) do
    owner == witness
  end

  @doc """
  Converts struct into a map with the output type data.

  ## Examples

      iex> output = %OMG.Output{owner: <<1::160>>, currency: <<1::160>>, amount: 1}
      iex> OMG.Output.to_db_value(output)
      %{type: <<1>>, owner: <<1::160>>, currency: <<1::160>>, amount: 1}
  """
  def to_db_value(%OMG.Output{owner: owner, currency: currency, amount: amount})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) do
    %{type: @output_type_marker, owner: owner, currency: currency, amount: amount}
  end

  @doc """
  Transforms into a RLP-ready structure

  ## Examples

      iex> output = %OMG.Output{owner: <<1::160>>, currency: <<1::160>>, amount: 1}
      iex> OMG.Output.get_data_for_rlp(output)
      [<<1>>, <<1::160>>, <<1::160>>, 1]
  """
  def get_data_for_rlp(%OMG.Output{owner: owner, currency: currency, amount: amount}),
    do: [@output_type_marker, owner, currency, amount]

  @doc """
  Reconstructs the structure from a list of RLP items
  """
  def reconstruct([output_type, [owner_rlp, currency_rlp, amount_rlp]]) do
    with {:ok, cur12} <- OMG.RawData.parse_address(currency_rlp),
         {:ok, owner} <- OMG.RawData.parse_address(owner_rlp),
         :ok <- non_zero_owner(owner),
         {:ok, amount} <- OMG.RawData.parse_amount(amount_rlp),
         do: %__MODULE__{output_type: output_type, owner: owner, currency: cur12, amount: amount}
  end

  def reconstruct(_), do: {:error, :malformed_outputs}

  defp non_zero_owner(<<0::160>>), do: {:error, :output_guard_cant_be_zero}
  defp non_zero_owner(_), do: :ok
end
