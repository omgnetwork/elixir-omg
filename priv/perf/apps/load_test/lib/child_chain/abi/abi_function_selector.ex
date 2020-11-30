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

defmodule LoadTest.ChildChain.Abi.AbiFunctionSelector do
  @moduledoc """

  We define Solidity Function selectors that help us decode returned values from function calls
  """
  # workaround for https://github.com/omgnetwork/elixir-omg/issues/1632
  def blocks() do
    %ABI.FunctionSelector{
      function: "blocks",
      input_names: ["block_hash", "block_timestamp"],
      inputs_indexed: nil,
      method_id: <<242, 91, 63, 153>>,
      # returns: [bytes: 32, uint: 256],
      type: :function,
      # types: [uint: 256]
      types: [bytes: 32, uint: 256]
    }
  end
end
