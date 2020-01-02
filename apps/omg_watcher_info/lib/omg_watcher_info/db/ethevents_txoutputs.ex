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

defmodule OMG.WatcherInfo.DB.EthEventsTxOutputs do
  @moduledoc """
  Ecto Schema representing a many-to-many ethevents <-> txoutputs association
  """
  use Ecto.Schema

  alias OMG.WatcherInfo.DB

  @primary_key false
  schema "ethevents_txoutputs" do
    belongs_to(:ethevents, DB.EthEvent, foreign_key: :root_chain_txhash_event, type: :binary)
    belongs_to(:txoutput, DB.TxOutput, foreign_key: :child_chain_utxohash, type: :binary)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:root_chain_txhash_event, :child_chain_utxohash])
    |> Ecto.Changeset.validate_required([:root_chain_txhash_event, :child_chain_utxohash])
  end
end
