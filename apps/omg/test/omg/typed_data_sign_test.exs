# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.TypedDataSignTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.State.Transaction
  alias OMG.TypedDataSign

  describe "Test vectors" do
    # This account was used with metamask to create signatures - do not change!
    @signer <<34, 88, 165, 39, 152, 80, 246, 251, 120, 136, 138, 126, 69, 234, 42, 94, 177, 179, 196, 54>>

    # TODO inline computation here
    @test_domain_separator <<0::256>>

    @other_addr <<1, 35, 69, 103, 137, 171, 205, 239, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    @eth <<0::160>>

    test "simple transfer" do
      signature =
        <<31, 250, 170, 204, 65, 228, 206, 34, 124, 90, 254, 51, 13, 175, 144, 76, 120, 130, 249, 167, 63, 119, 178,
          224, 100, 33, 195, 89, 105, 150, 12, 163, 70, 14, 254, 3, 118, 104, 21, 242, 139, 207, 69, 2, 208, 10, 160,
          105, 159, 86, 226, 67, 166, 19, 237, 223, 161, 248, 125, 14, 251, 185, 29, 33, 28>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx = Transaction.new([{1000, 0, 1}], [{@other_addr, @eth, 5}, {@signer, @eth, 10}])

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "transaction with different input" do
      signature =
        <<11, 160, 68, 236, 58, 193, 245, 1, 166, 52, 16, 162, 74, 175, 246, 106, 113, 185, 158, 109, 22, 63, 24, 241,
          20, 69, 105, 202, 173, 79, 126, 254, 35, 198, 254, 125, 61, 160, 72, 181, 101, 216, 216, 45, 6, 105, 192, 103,
          93, 117, 80, 239, 189, 65, 133, 206, 120, 40, 155, 186, 152, 219, 240, 124, 28>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx = Transaction.new([{1000, 1, 0}], [{@other_addr, @eth, 5}, {@signer, @eth, 10}])

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "transaction outputs reverted" do
      signature =
        <<224, 157, 107, 96, 72, 147, 122, 111, 131, 43, 6, 20, 138, 103, 188, 34, 65, 10, 25, 44, 221, 1, 240, 131, 98,
          186, 162, 85, 164, 180, 194, 228, 66, 19, 77, 44, 226, 198, 252, 231, 87, 131, 64, 33, 223, 127, 47, 124, 91,
          173, 39, 22, 21, 20, 82, 220, 187, 159, 38, 162, 3, 25, 132, 95, 28>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx = Transaction.new([{1000, 1, 0}], [{@signer, @eth, 10}, {@other_addr, @eth, 5}])

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "transaction with input & output placeholders" do
      signature =
        <<227, 83, 26, 156, 250, 126, 83, 252, 198, 185, 4, 1, 80, 227, 104, 100, 155, 83, 170, 81, 102, 51, 78, 141, 3,
          24, 82, 136, 43, 104, 101, 126, 51, 46, 103, 60, 113, 190, 70, 11, 94, 211, 43, 199, 107, 189, 189, 38, 76,
          20, 231, 42, 123, 27, 187, 41, 14, 49, 23, 113, 254, 1, 161, 245, 28>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx =
        Transaction.new(
          [{1000, 1, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}],
          [{@signer, @eth, 10}, {@other_addr, @eth, 5}, {@eth, @eth, 0}, {@eth, @eth, 0}]
        )

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "transaction with metadata" do
      signature =
        <<32, 199, 147, 113, 164, 1, 117, 84, 255, 203, 194, 52, 25, 19, 39, 152, 124, 74, 26, 190, 101, 45, 0, 4, 133,
          7, 153, 37, 145, 178, 120, 207, 50, 100, 176, 203, 239, 161, 16, 78, 33, 54, 22, 231, 97, 149, 219, 111, 189,
          149, 0, 88, 94, 34, 84, 252, 135, 131, 169, 180, 218, 192, 240, 252, 28>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx =
        Transaction.new(
          [{1000, 1, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}],
          [{@signer, @eth, 10}, {@other_addr, @eth, 5}, {@eth, @eth, 0}, {@eth, @eth, 0}],
          <<0::256>>
        )

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "transaction with metadata, no placeholders" do
      signature =
        <<102, 120, 226, 61, 200, 191, 140, 150, 166, 228, 220, 97, 187, 239, 40, 211, 3, 27, 182, 159, 41, 63, 176,
          196, 122, 120, 173, 80, 120, 33, 57, 227, 60, 33, 239, 77, 100, 216, 154, 92, 108, 90, 185, 81, 215, 107, 144,
          39, 143, 182, 104, 112, 158, 160, 163, 76, 160, 35, 10, 40, 137, 225, 159, 177, 27>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx = Transaction.new([{1000, 1, 0}], [{@signer, @eth, 10}, {@other_addr, @eth, 5}], <<0::256>>)

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "merge transaction 4 to 1" do
      signature =
        <<38, 214, 56, 179, 8, 85, 1, 28, 122, 201, 140, 71, 2, 31, 96, 40, 73, 105, 42, 223, 25, 52, 152, 85, 226, 195,
          50, 44, 135, 156, 36, 229, 85, 235, 226, 196, 114, 61, 81, 21, 163, 145, 18, 109, 221, 204, 83, 78, 122, 136,
          191, 205, 2, 48, 44, 49, 59, 6, 217, 46, 222, 151, 112, 141, 28>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx = Transaction.new([{1001, 0, 0}, {1002, 0, 0}, {2000, 0, 0}, {2000, 1, 0}], [{@signer, @eth, 100}])

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end

    test "all inputs & outputs filled in" do
      signature =
        <<179, 119, 206, 222, 82, 209, 134, 139, 81, 148, 176, 53, 26, 120, 8, 27, 53, 55, 186, 183, 82, 52, 186, 53,
          93, 244, 184, 227, 135, 108, 78, 101, 35, 182, 203, 133, 157, 217, 136, 1, 56, 148, 39, 108, 70, 149, 171,
          234, 173, 117, 46, 200, 17, 255, 38, 148, 62, 79, 202, 116, 166, 146, 112, 125, 27>>

      # sanity check
      assert 65 == signature |> Kernel.byte_size()

      raw_tx =
        Transaction.new(
          [{1001, 0, 0}, {1002, 0, 0}, {2000, 0, 0}, {2000, 1, 0}],
          [{@signer, @eth, 50}, {@signer, @eth, 50}, {@signer, @eth, 50}, {@signer, @eth, 50}]
        )

      assert {:ok, true} == TypedDataSign.verify(raw_tx, signature, @signer, @test_domain_separator)
    end
  end
end
