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

defmodule OmgWatcher.ExitProcessor.ExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked exit.

  Internal stuff of `OmgWatcher.ExitProcessor`
  """

  alias OMG.Crypto
  alias OMG.Utxo
  require Utxo

  defstruct [:amount, :currency, :owner, :is_active, :eth_height]

  @type t :: %__MODULE__{
          amount: non_neg_integer(),
          currency: Crypto.address_t(),
          owner: Crypto.address_t(),
          # this means the exit has been first seen active. If false, it won't be considered harmful
          is_active: boolean(),
          eth_height: pos_integer()
        }

  def make_event_data(type, position, %__MODULE__{} = exit_info) do
    struct(type, exit_info |> Map.from_struct() |> Map.put(:utxo_pos, Utxo.Position.encode(position)))
  end

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def make_db_update(
        {position,
         %__MODULE__{amount: amount, currency: currency, owner: owner, is_active: is_active, eth_height: eth_height}}
      )
      when is_integer(amount) and is_integer(eth_height) and
             is_binary(currency) and is_binary(owner) and
             is_boolean(is_active) do
    value = %{
      amount: amount,
      currency: currency,
      owner: owner,
      is_active: is_active,
      eth_height: eth_height
    }

    {:put, :exit_info, {Utxo.Position.to_db_key(position), value}}
  end

  def from_db_kv(
        {db_utxo_pos,
         %{
           amount: amount,
           currency: currency,
           owner: owner,
           is_active: is_active,
           eth_height: eth_height
         }}
      )
      when is_integer(amount) and is_integer(eth_height) and
             is_binary(currency) and is_binary(owner) and
             is_boolean(is_active) do
    # mapping is used in case of changes in data structure
    value = %{
      amount: amount,
      currency: currency,
      owner: owner,
      is_active: is_active,
      eth_height: eth_height
    }

    {Utxo.Position.from_db_key(db_utxo_pos), struct!(__MODULE__, value)}
  end
end
