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

defmodule OMG.ChildChain.BlockQueue.BlockQueueState do
  @moduledoc """

  """

  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.GasPriceAdjustment

  use OMG.Utils.LoggerExt

  @zero_bytes32 <<0::size(256)>>

  @type eth_height() :: non_neg_integer()
  @type hash() :: BlockSubmission.hash()
  @type plasma_block_num() :: BlockSubmission.plasma_block_num()
  # child chain block number, as assigned by plasma contract
  @type encoded_signed_tx() :: binary()

  defstruct [
    :blocks,
    :parent_height,
    last_parent_height: 0,
    formed_child_block_num: 0,
    wait_for_enqueue: false,
    gas_price_to_use: 20_000_000_000,
    mined_child_block_num: 0,
    last_enqueued_block_at_height: 0,
    # config:
    child_block_interval: nil,
    chain_start_parent_height: nil,
    minimal_enqueue_block_gap: 1,
    finality_threshold: 12,
    gas_price_adj_params: %GasPriceAdjustment{},
    # TMP
    stored_child_top_num: nil
  ]

  @type t() :: %__MODULE__{
    blocks: %{pos_integer() => %BlockSubmission{}},
    # last mined block num
    mined_child_block_num: plasma_block_num(),
    # newest formed block num
    formed_child_block_num: plasma_block_num(),
    # current Ethereum block height
    parent_height: nil | eth_height(),
    # whether we're pending an enqueue signal with a new block
    wait_for_enqueue: boolean(),
    # gas price to use when (re)submitting transactions
    gas_price_to_use: pos_integer(),
    last_enqueued_block_at_height: pos_integer(),
    # CONFIG CONSTANTS below
    # spacing of child blocks in RootChain contract, being the amount of deposit decimals per child block
    child_block_interval: pos_integer(),
    # Ethereum height at which first block was mined
    chain_start_parent_height: pos_integer(),
    # minimal gap between child blocks
    minimal_enqueue_block_gap: pos_integer(),
    # depth of max reorg we take into account
    finality_threshold: pos_integer(),
    # the gas price adjustment strategy parameters
    gas_price_adj_params: GasPriceAdjustment.t(),
    last_parent_height: non_neg_integer()
  }
end
