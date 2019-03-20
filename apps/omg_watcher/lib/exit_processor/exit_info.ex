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

defmodule OMG.Watcher.ExitProcessor.ExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked exit.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  require Utxo

  defstruct [:amount, :currency, :owner, :is_active, :eth_height, :exit_txhash]

  @type t :: %__MODULE__{
          amount: non_neg_integer(),
          currency: Crypto.address_t(),
          owner: Crypto.address_t(),
          # this means the exit has been first seen active. If false, it won't be considered harmful
          is_active: boolean(),
          eth_height: pos_integer(),
          exit_txhash: Transaction.tx_hash()
        }

  def make_event_data(type, position, %__MODULE__{} = exit_info) do
    struct(type, exit_info |> Map.from_struct() |> Map.put(:utxo_pos, Utxo.Position.encode(position)))
  end

  def make_db_update({position, %__MODULE__{} = exit_info}) do
    {:put, :exit_info, {Utxo.Position.to_db_key(position), exit_info |> Map.from_struct()}}
  end

  def from_db_value(exit_info_map) do
    struct!(__MODULE__, exit_info_map)
  end
end
