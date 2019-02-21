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

defmodule OMG.Watcher.BlockGetter.BlockApplication do
  @moduledoc """
  Contains all the information that `apply_block` and `handle_cast(:apply_block)` would need to apply a statelessly
  valid, downloaded block
  """

  alias OMG.API.State.Transaction
  alias OMG.Watcher.BlockGetter.BlockApplication

  @type t :: %__MODULE__{
          number: pos_integer(),
          eth_height: non_neg_integer(),
          eth_height_done: boolean(),
          hash: binary(),
          timestamp: pos_integer(),
          transactions: list(),
          zero_fee_requirements: map()
        }

  defstruct [
    :number,
    :eth_height,
    :eth_height_done,
    :hash,
    :timestamp,
    transactions: [],
    zero_fee_requirements: %{}
  ]

  def new(block, recovered_txs, block_timestamp) do
    # we as the Watcher don't care about the fees, so we fix all currencies to require 0 fee
    zero_fee_requirements = recovered_txs |> Enum.reduce(%{}, &add_zero_fee/2)

    struct!(
      BlockApplication,
      block
      |> Map.from_struct()
      |> Map.put(:transactions, recovered_txs)
      |> Map.put(:timestamp, block_timestamp)
      |> Map.put(:zero_fee_requirements, zero_fee_requirements)
    )
  end

  defp add_zero_fee(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}}, fee_map) do
    raw_tx
    |> Transaction.get_currencies()
    |> Enum.into(fee_map, fn currency -> {currency, 0} end)
  end
end
