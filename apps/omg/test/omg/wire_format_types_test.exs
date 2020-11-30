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

defmodule OMG.WireFormatTypesTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.WireFormatTypes

  describe "tx_type_for/1" do
    test "returns the tx type for the given atom" do
      assert WireFormatTypes.tx_type_for(:tx_payment_v1) == 1
    end
  end

  describe "input_pointer_type_for/1" do
    test "returns the input type for the given input" do
      assert WireFormatTypes.input_pointer_type_for(:input_pointer_utxo_position) == 1
    end
  end

  describe "output_type_for/1" do
    test "returns the output type for the given output" do
      assert WireFormatTypes.output_type_for(:output_payment_v1) == 1
    end
  end
end
