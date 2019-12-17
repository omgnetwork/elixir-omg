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

  @doc """
  Reconstructs the structure from a list of RLP items

  NOTE: the of items should be a single-item list holding a list of three items. The output type has been parsed earlier
  """
  def reconstruct([[owner_rlp, currency_rlp, amount_rlp]]) do
    with {:ok, cur12} <- parse_address(currency_rlp),
         {:ok, owner} <- parse_address(owner_rlp),
         :ok <- non_zero_owner(owner),
         {:ok, int_amount} <- parse_int(amount_rlp),
         {:ok, amount} <- parse_amount(int_amount),
         do: %__MODULE__{owner: owner, currency: cur12, amount: amount}
  end

  def reconstruct(_), do: {:error, :malformed_outputs}

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

  # FIXME unit test
  defp non_zero_owner(<<0::160>>), do: {:error, :output_guard_cant_be_zero}
  defp non_zero_owner(_), do: :ok
end

defimpl OMG.Output.Protocol, for: OMG.Output.FungibleMoreVPToken do
  alias OMG.Output.FungibleMoreVPToken
  alias OMG.Utxo

  require Utxo

  # TODO: dry wrt. Application.fetch_env!(:omg, :output_types_modules)? Use `bimap` perhaps?
  @output_type_marker <<1>>

  @doc """
  For payment outputs, a binary witness is assumed to be a signature equal to the payment's output owner
  """
  def can_spend?(%FungibleMoreVPToken{owner: owner}, witness, _raw_tx) when is_binary(witness) do
    owner == witness
  end

  def input_pointer(%FungibleMoreVPToken{}, blknum, tx_index, oindex, _, _),
    do: Utxo.position(blknum, tx_index, oindex)

  def to_db_value(%FungibleMoreVPToken{owner: owner, currency: currency, amount: amount})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) do
    %{owner: owner, currency: currency, amount: amount, type: @output_type_marker}
  end

  def get_data_for_rlp(%FungibleMoreVPToken{owner: owner, currency: currency, amount: amount}),
    do: [@output_type_marker, [owner, currency, amount]]
end
