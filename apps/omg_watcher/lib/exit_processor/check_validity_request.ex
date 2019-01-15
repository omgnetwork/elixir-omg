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

defmodule OMG.Watcher.ExitProcessor.CheckValidityRequest do
  @moduledoc """
  Encapsulates the state of processing of `OMG.Watcher.ExitProcessor.check_validity/0` pipeline

  Holds all the necessary query date and the respective response
  """

  alias OMG.API.Block
  alias OMG.API.Utxo

  defstruct [
    :eth_height_now,
    :blknum_now,
    :utxos_to_check,
    :utxo_exists_result,
    :spends_to_get,
    :spent_blknum_result,
    :blknums_to_get,
    :blocks_result
  ]

  @type t :: %__MODULE__{
          eth_height_now: nil | pos_integer,
          blknum_now: nil | pos_integer,
          utxos_to_check: nil | list(Utxo.Position.t()),
          utxo_exists_result: nil | list(boolean),
          spends_to_get: nil | list(Utxo.Position.t()),
          spent_blknum_result: nil | list(pos_integer),
          blknums_to_get: nil | list(pos_integer),
          blocks_result: nil | {:ok, list(Block.t())}
        }
end
