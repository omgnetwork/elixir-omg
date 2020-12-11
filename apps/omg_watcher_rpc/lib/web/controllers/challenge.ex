# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.Utxo
  alias OMG.Watcher.API

  @doc """
  Challenges exits
  """
  def get_utxo_challenge(conn, params) do
    with {:ok, utxo_pos} <- expect(params, "utxo_pos", :pos_integer),
         {:ok, utxo} <- Utxo.Position.decode(utxo_pos) do
      utxo
      |> API.Utxo.create_challenge()
      |> api_response(conn, :challenge)
    end
  end
end
