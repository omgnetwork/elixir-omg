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

defmodule LoadTest.Ethereum.BitHelper do
  @moduledoc """
  Helpers for common operations on the blockchain.
  Extracted from: https://github.com/exthereum/blockchain
  """

  use Bitwise

  @type keccak_hash :: binary()

  @doc """
  Returns the keccak sha256 of a given input.
  """
  @spec kec(binary()) :: keccak_hash
  def kec(data) do
    :keccakf1600.sha3_256(data)
  end

  @doc """
  Similar to `:binary.encode_unsigned/1`, except we encode `0` as
  `<<>>`, the empty string. This is because the specification says that
  we cannot have any leading zeros, and so having <<0>> by itself is
  leading with a zero and prohibited.
  """
  @spec encode_unsigned(non_neg_integer()) :: binary()
  def encode_unsigned(0), do: <<>>
  def encode_unsigned(n), do: :binary.encode_unsigned(n)
end
