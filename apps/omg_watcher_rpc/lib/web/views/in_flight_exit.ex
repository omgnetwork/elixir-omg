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

defmodule OMG.WatcherRPC.Web.View.InFlightExit do
  @moduledoc """
  The transaction view for rendering json
  """

  use OMG.WatcherRPC.Web, :view

  alias OMG.Utils.HttpRPC.Response
  alias OMG.Utxo

  def render("in_flight_exit.json", %{response: in_flight_exit}) do
    in_flight_exit
    |> Response.serialize()
  end

  def render("competitor.json", %{response: competitor}) do
    competitor
    |> Map.update!(:competing_tx_pos, &Utxo.Position.encode/1)
    |> Map.update!(:input_utxo_pos, &Utxo.Position.encode/1)
    |> Response.serialize()
  end

  def render("prove_canonical.json", %{response: prove_canonical}) do
    prove_canonical
    |> Map.update!(:in_flight_tx_pos, &Utxo.Position.encode/1)
    |> Response.serialize()
  end

  def render("get_input_challenge_data.json", %{response: challenge_data}) do
    challenge_data
    |> Map.update!(:input_utxo_pos, &Utxo.Position.encode/1)
    |> Response.serialize()
  end

  def render("get_output_challenge_data.json", %{response: challenge_data}) do
    challenge_data
    |> Map.update!(:in_flight_output_pos, &Utxo.Position.encode/1)
    |> Response.serialize()
  end
end
