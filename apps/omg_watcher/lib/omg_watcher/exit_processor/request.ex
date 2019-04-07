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

defmodule OMG.Watcher.ExitProcessor.Request do
  @moduledoc """
  Encapsulates the state of processing of `OMG.Watcher.ExitProcessor` pipelines

  Holds all the necessary query date and the respective response

  NOTE: this is highly experimental, to test out new patterns to follow when doing the Functional Core vs Imperative
        Shell separation. **Do not yet** follow outside of here. I'm not sure whether such struct offers much and it
        has its problems. Decide and update this note after OMG-384 or OMG-383

        EDIT: the multitude and duplication of the fields here is a clear sign that this design loses.
  """

  alias OMG.Block
  alias OMG.Utxo

  defstruct [
    :eth_height_now,
    :blknum_now,
    utxos_to_check: [],
    spends_to_get: [],
    blknums_to_get: [],
    piggybacked_utxos_to_check: [],
    piggybacked_spends_to_get: [],
    piggybacked_blknums_to_get: [],
    utxo_exists_result: [],
    spent_blknum_result: [],
    blocks_result: [],
    piggybacked_utxo_exists_result: [],
    piggybacked_spent_blknum_result: [],
    piggybacked_blocks_result: []
  ]

  @type t :: %__MODULE__{
          eth_height_now: nil | pos_integer,
          blknum_now: nil | pos_integer,
          utxos_to_check: list(Utxo.Position.t()),
          spends_to_get: list(Utxo.Position.t()),
          blknums_to_get: list(pos_integer),
          piggybacked_utxos_to_check: list(Utxo.Position.t()),
          piggybacked_spends_to_get: list(Utxo.Position.t()),
          piggybacked_blknums_to_get: list(pos_integer),
          utxo_exists_result: list(boolean),
          spent_blknum_result: list(pos_integer),
          blocks_result: list(Block.t()),
          piggybacked_utxo_exists_result: list(boolean),
          piggybacked_spent_blknum_result: list(pos_integer),
          piggybacked_blocks_result: list(Block.t())
        }
end
