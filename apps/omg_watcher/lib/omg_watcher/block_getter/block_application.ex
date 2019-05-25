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

defmodule OMG.Watcher.BlockGetter.BlockApplication do
  @moduledoc """
  Contains all the information that `apply_block` and `handle_cast(:apply_block)` would need to apply a statelessly
  valid, downloaded block
  """

  alias OMG.Watcher.BlockGetter.BlockApplication

  @type t :: %__MODULE__{
          number: pos_integer(),
          eth_height: non_neg_integer(),
          eth_height_done: boolean(),
          hash: binary(),
          timestamp: pos_integer(),
          transactions: list()
        }

  defstruct [
    :number,
    :eth_height,
    :eth_height_done,
    :hash,
    :timestamp,
    transactions: []
  ]

  def new(block, recovered_txs, block_timestamp) do
    struct!(
      BlockApplication,
      block
      |> Map.from_struct()
      |> Map.put(:transactions, recovered_txs)
      |> Map.put(:timestamp, block_timestamp)
    )
  end
end
