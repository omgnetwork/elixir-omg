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

defmodule OMG.Watcher.ExitProcessor.Request do
  @moduledoc """
  Encapsulates the state of processing of `OMG.Watcher.ExitProcessor` pipelines

  Holds all the necessary query date and the respective response
  """

  alias OMG.Block
  alias OMG.Utxo

  defstruct [
    :eth_height_now,
    :blknum_now,
    utxos_to_check: [],
    spends_to_get: [],
    blknums_to_get: [],
    ife_input_utxos_to_check: [],
    ife_input_spends_to_get: [],
    piggybacked_blknums_to_get: [],
    utxo_exists_result: [],
    blocks_result: [],
    ife_input_utxo_exists_result: [],
    ife_input_spending_blocks_result: [],
    se_exiting_pos: nil,
    se_spending_blocks_to_get: [],
    se_spending_blocks_result: []
  ]

  @type t :: %__MODULE__{
          eth_height_now: nil | pos_integer,
          blknum_now: nil | pos_integer,
          utxos_to_check: list(Utxo.Position.t()),
          spends_to_get: list(Utxo.Position.t()),
          blknums_to_get: list(pos_integer),
          ife_input_utxos_to_check: list(Utxo.Position.t()),
          ife_input_spends_to_get: list(Utxo.Position.t()),
          piggybacked_blknums_to_get: list(pos_integer),
          utxo_exists_result: list(boolean),
          blocks_result: list(Block.t()),
          ife_input_utxo_exists_result: list(boolean),
          ife_input_spending_blocks_result: list(Block.t()),
          se_exiting_pos: nil | Utxo.Position.t(),
          se_spending_blocks_to_get: list(Utxo.Position.t()),
          se_spending_blocks_result: list(Block.t())
        }
end
