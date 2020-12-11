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
defmodule OMG.OutputTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest OMG.Output

  describe "reconstruct/1" do
    test "returns an error if the output guard is invalid" do
      rlp_data = [
        <<1>>,
        [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          <<1>>
        ]
      ]

      assert {:error, :output_guard_cant_be_zero} = OMG.Output.reconstruct(rlp_data)
    end

    test "returns an error if the output is malformed" do
      rlp_data = []
      assert {:error, :malformed_outputs} = OMG.Output.reconstruct(rlp_data)
    end
  end
end
