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

defmodule OMG.WatcherRPC.Web.Serializer.Base do
  @moduledoc """
  Common structure formatters module.
  """

  def to_utxo(%{blknum: blknum, txindex: txindex, oindex: oindex} = db_entry) do
    alias OMG.Utxo
    require Utxo

    db_entry
    |> Map.take([:amount, :currency, :blknum, :txindex, :oindex, :owner])
    |> Map.put(:utxo_pos, Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode())
  end
end
