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
  Representation of the payment transaction output of a fungible token `currency`
  """
  alias OMG.Crypto
  defstruct [:owner, :currency, :amount]

  @type t :: %__MODULE__{
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer()
        }

  def from_db_value(%{owner: owner, currency: currency, amount: amount})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) do
    %__MODULE__{owner: owner, currency: currency, amount: amount}
  end

  def reconstruct([owner, currency, bin_amount]) do
    with {:ok, cur12} <- parse_address(currency),
         {:ok, owner} <- parse_address(owner),
         {:ok, int_amount} <- parse_int(bin_amount),
         {:ok, amount} <- parse_amount(int_amount),
         do: %__MODULE__{owner: owner, currency: cur12, amount: amount}
  end

  defp parse_amount(amount) when is_integer(amount) and amount > 0, do: {:ok, amount}
  defp parse_amount(amount) when is_integer(amount), do: {:error, :amount_cant_be_zero}

  defp parse_int(<<0>> <> _binary), do: {:error, :leading_zeros_in_encoded_uint}
  defp parse_int(binary) when byte_size(binary) <= 32, do: {:ok, :binary.decode_unsigned(binary, :big)}
  defp parse_int(binary) when byte_size(binary) > 32, do: {:error, :encoded_uint_too_big}

  # necessary, because RLP handles empty string equally to integer 0
  @spec parse_address(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp parse_address(binary)
  defp parse_address(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp parse_address(_), do: {:error, :malformed_address}
end
