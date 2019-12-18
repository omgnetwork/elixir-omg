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

defmodule OMG.Output.FungibleMoreVPToken do
  @moduledoc """
  Representation of the payment transaction output of a fungible token `currency`.
  Fungible token outputs could have different `output_type` but as long as they share the same behaviour
  they are indistinguishable from code perspective.
  """
  alias OMG.Crypto
  alias OMG.RawData
  defstruct [:output_type, :owner, :currency, :amount]

  @type t :: %__MODULE__{
          output_type: binary(),
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer()
        }

  def from_db_value(%{owner: owner, currency: currency, amount: amount, output_type: output_type})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) and is_integer(output_type) do
    %__MODULE__{owner: owner, currency: currency, amount: amount, output_type: output_type}
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
end
