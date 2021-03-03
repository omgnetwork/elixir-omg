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

defmodule OMG.Watcher.RawData do
  @moduledoc """
  Provides functions to decode various data types from RLP raw format
  """

  alias OMG.Watcher.Crypto

  @doc """
  Parses amount, where 0 < amount < 2^256
  """
  @spec parse_amount(binary()) ::
          {:ok, pos_integer()} | {:error, :amount_cant_be_zero | :leading_zeros_in_encoded_uint | :encoded_uint_too_big}
  def parse_amount(binary) when is_binary(binary) do
    case parse_uint256(binary) do
      {:ok, 0} ->
        {:error, :amount_cant_be_zero}

      {:ok, amount} ->
        {:ok, amount}

      error ->
        error
    end
  end

  @doc """
  Parses 20-bytes address
  Case `<<>>` is necessary, because RLP handles empty string equally to integer 0
  """
  @spec parse_address(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  def parse_address(binary)
  def parse_address(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  def parse_address(_), do: {:error, :malformed_address}

  @doc """
  Parses unsigned at-most 32-bytes integer. Leading zeros are disallowed
  """
  @spec parse_uint256(binary()) ::
          {:ok, non_neg_integer()} | {:error, :encoded_uint_too_big | :leading_zeros_in_encoded_uint}
  def parse_uint256(<<0>> <> _binary), do: {:error, :leading_zeros_in_encoded_uint}
  def parse_uint256(binary) when byte_size(binary) <= 32, do: {:ok, :binary.decode_unsigned(binary, :big)}
  def parse_uint256(binary) when byte_size(binary) > 32, do: {:error, :encoded_uint_too_big}
  def parse_uint256(_), do: {:error, :malformed_uint256}
end
