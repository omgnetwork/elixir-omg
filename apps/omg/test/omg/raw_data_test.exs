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

defmodule OMG.RawDataTest do
  use ExUnit.Case, async: true
  # doctest OMG.RawData
  alias OMG.RawData

  describe "parse_amount/1" do
    test "rejects zero passed as amount" do
      [zero] = [0] |> ExRLP.encode() |> ExRLP.decode()

      assert {:error, :amount_cant_be_zero} == RawData.parse_amount(zero)
    end

    test "rejects integer greater than 32-bytes" do
      large = 2.0 |> :math.pow(8 * 32) |> Kernel.trunc()
      [too_large] = [large] |> ExRLP.encode() |> ExRLP.decode()

      assert {:error, :encoded_uint_too_big} == RawData.parse_amount(too_large)
    end

    test "rejects leading zeros encoded numbers" do
      [one] = [1] |> ExRLP.encode() |> ExRLP.decode()

      assert {:error, :leading_zeros_in_encoded_uint} == RawData.parse_amount(<<0>> <> one)
    end

    test "accepts 32-bytes positive integers" do
      large = 2.0 |> :math.pow(8 * 32) |> Kernel.trunc()
      big_just_enough = large - 1

      [one, big] = [1, big_just_enough] |> ExRLP.encode() |> ExRLP.decode()

      assert {:ok, 1} == RawData.parse_amount(one)
      assert {:ok, big_just_enough} == RawData.parse_amount(big)
    end
  end

  describe "parse_address/1" do
    test "accepts 20-bytes binaries" do
      zero_addr = <<0::160>>
      non_zero_addr = <<2::160>>

      [zero, addr] = [zero_addr, non_zero_addr] |> ExRLP.encode() |> ExRLP.decode()

      assert {:ok, zero_addr} == RawData.parse_address(zero)
      assert {:ok, non_zero_addr} == RawData.parse_address(addr)
    end

    test "rejects binaries shorter or longer than address length" do
      too_short_addr = <<0::152>>
      too_long_addr = <<0::168>>

      [short, long] = [too_short_addr, too_long_addr] |> ExRLP.encode() |> ExRLP.decode()

      assert {:error, :malformed_address} == RawData.parse_address(short)
      assert {:error, :malformed_address} == RawData.parse_address(long)
    end
  end
end
