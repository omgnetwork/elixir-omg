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

defmodule OMG.WatcherRPC.Web.Controller.Utxo do
  @moduledoc """
  Operations related to utxo.
  Modify the state in the database.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.Utxo
  alias OMG.Watcher.API
  alias OMG.WatcherInfo.API.Utxo, as: InfoApiUtxo
  alias OMG.WatcherRPC.Web.Validator

  def get_utxo_exit(conn, params) do
    with {:ok, utxo_pos} <- expect(params, "utxo_pos", :pos_integer),
         {:ok, utxo} <- Utxo.Position.decode(utxo_pos) do
      utxo
      |> API.Utxo.compose_utxo_exit()
      |> api_response(conn, :utxo_exit)
    end
  end

  def get_deposits(conn, params) do
    with {:ok, constraints} <- Validator.UtxoConstraints.parse(params) do
      InfoApiUtxo.get_deposits(constraints)
      |> api_response(conn, :deposits)
    end
  end
end
