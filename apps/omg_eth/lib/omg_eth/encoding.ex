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

defmodule OMG.Eth.Encoding do
  @moduledoc """
  Internal encoding helpers to talk to ethereum.
  For use in `OMG.Eth` and `OMG.Eth.DevHelper`
  """

  alias OMG.Eth.Encoding.ContractConstructor

  @doc """
  Ethereum JSONRPC and Ethereumex' specific encoding and decoding of binaries and ints

  We are enforcing the users of Eth and Eth.<Contract> APIs to always use integers and raw decoded binaries,
  when interacting.

  Configuration entries are expected to be written in "0xhex-style"
  """
  @spec to_hex(binary | non_neg_integer) :: binary
  def to_hex(non_hex)

  def to_hex(raw) when is_binary(raw), do: "0x" <> Base.encode16(raw, case: :lower)
  def to_hex(int) when is_integer(int), do: "0x" <> Integer.to_string(int, 16)

  @doc """
  Decodes to a raw binary, see `to_hex`
  """
  # because https://github.com/rrrene/credo/issues/583, we need to:
  # credo:disable-for-next-line Credo.Check.Consistency.SpaceAroundOperators
  @spec from_hex(<<_::16, _::_*8>>) :: binary
  def from_hex("0x" <> encoded), do: Base.decode16!(encoded, case: :lower)

  @doc """
  Decodes to an integer, see `to_hex`
  """
  # because https://github.com/rrrene/credo/issues/583, we need to:
  # credo:disable-for-next-line Credo.Check.Consistency.SpaceAroundOperators
  @spec int_from_hex(<<_::16, _::_*8>>) :: non_neg_integer
  def int_from_hex("0x" <> encoded) do
    {return, ""} = Integer.parse(encoded, 16)
    return
  end

  @doc """
  Encodes a list of smart contract constructor parameters into a base16 encoded-ABI that
  solidity expects.

  ## Examples

      iex> OMG.Eth.Encoding.encode_constructor_params([
      ...>   {{:uint, 8}, 255},
      ...> ])
      "00000000000000000000000000000000000000000000000000000000000000ff"

      iex> OMG.Eth.Encoding.encode_constructor_params([
      ...>   {{:uint, 8}, 255},
      ...>   {:string, "hello"},
      ...> ])
      "00000000000000000000000000000000000000000000000000000000000000ff0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000568656c6c6f000000000000000000000000000000000000000000000000000000"
  """
  @spec encode_constructor_params(types_values :: [tuple()]) :: abi_base16_encoded :: binary()
  def encode_constructor_params(types_values) do
    {types, values} = ContractConstructor.extract_params(types_values)

    values
    |> ABI.TypeEncoder.encode_raw(types)
    # NOTE: we're not using `to_hex` because the `0x` will be appended to the bytecode already
    |> Base.encode16(case: :lower)
  end
end
