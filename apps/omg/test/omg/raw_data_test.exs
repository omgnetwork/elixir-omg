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

defmodule OMG.RawDataTest do
  use ExUnit.Case, async: true
  # doctest OMG.RawData
  alias OMG.RawData

  test "parsing amounts" do
    big_32bytes = 2.0 |> :math.pow(8 * 32) |> Kernel.trunc()
    big_just_enough = big_32bytes - 1

    rlp_data = ExRLP.encode([0, 1, big_just_enough, big_32bytes])
    [zero, one, big, too_big] = ExRLP.decode(rlp_data)

    assert {:error, :amount_cant_be_zero} == RawData.parse_amount(zero)
    assert {:ok, 1} == RawData.parse_amount(one)
    assert {:ok, big_just_enough} == RawData.parse_amount(big)
    assert {:error, :encoded_uint_too_big} == RawData.parse_amount(too_big)
    assert {:error, :leading_zeros_in_encoded_uint} == RawData.parse_amount(<<0>> <> one)
  end

  test "parsing addresses" do
    zero_addr = <<0::160>>
    non_zero_addr = <<2::160>>
    too_short_addr = <<0::152>>
    too_long_addr = <<0::168>>

    rlp_data = ExRLP.encode([zero_addr, non_zero_addr, too_short_addr, too_long_addr])
    [zero, addr, bad1, bad2] = ExRLP.decode(rlp_data)

    assert {:ok, zero_addr} == RawData.parse_address(zero)
    assert {:ok, non_zero_addr} == RawData.parse_address(addr)
    assert {:error, :malformed_address} == RawData.parse_address(bad1)
    assert {:error, :malformed_address} == RawData.parse_address(bad2)
  end
end
