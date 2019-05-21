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

defmodule OMG.Watcher.DB.Spend do
  @moduledoc """
  Ecto schema to record transaction's utxo spend
  """
  use Ecto.Schema
  use OMG.Utils.Metrics

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @primary_key false
  schema "spends" do
    field(:blknum, :integer, primary_key: true)
    field(:txindex, :integer, primary_key: true)
    field(:oindex, :integer, primary_key: true)
    field(:spending_txhash, :binary)
    field(:spending_tx_oindex, :integer)
  end

  @decorate measure_event()
  @spec create_spends(Transaction.any_flavor_t(), binary()) :: [map()]
  def create_spends(tx, spending_txhash) do
    tx
    |> Transaction.get_inputs()
    |> Enum.with_index()
    |> Enum.map(fn {Utxo.position(blknum, txindex, oindex), index} ->
      %{
        blknum: blknum,
        txindex: txindex,
        oindex: oindex,
        spending_txhash: spending_txhash,
        spending_tx_oindex: index
      }
    end)
  end
end
