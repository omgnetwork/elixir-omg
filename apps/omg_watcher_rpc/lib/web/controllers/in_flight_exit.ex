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

defmodule OMG.WatcherRPC.Web.Controller.InFlightExit do
  @moduledoc """
  Operations related to in flight exits starting and handling.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.Watcher.API

  @doc """
  For a given transaction provided in params,
  responds with arguments for plasma contract function that starts in-flight exit.
  """
  def get_in_flight_exit(conn, params) do
    handle_txbytes_based_request(conn, params, &API.InFlightExit.get_in_flight_exit/1, :in_flight_exit)
  end

  def get_competitor(conn, params) do
    handle_txbytes_based_request(conn, params, &API.InFlightExit.get_competitor/1, :competitor)
  end

  def prove_canonical(conn, params) do
    handle_txbytes_based_request(conn, params, &API.InFlightExit.prove_canonical/1, :prove_canonical)
  end

  def get_input_challenge_data(conn, params) do
    with {:ok, txbytes} <- expect(params, "txbytes", :hex),
         {:ok, input_index} <- expect(params, "input_index", :non_neg_integer) do
      API.InFlightExit.get_input_challenge_data(txbytes, input_index)
      |> api_response(conn, :get_input_challenge_data)
    end
  end

  def get_output_challenge_data(conn, params) do
    with {:ok, txbytes} <- expect(params, "txbytes", :hex),
         {:ok, output_index} <- expect(params, "output_index", :non_neg_integer) do
      API.InFlightExit.get_output_challenge_data(txbytes, output_index)
      |> api_response(conn, :get_output_challenge_data)
    end
  end

  # NOTE: don't overdo this DRYing here - if the above controller functions evolve and diverge, it might be better to
  #       un-DRY
  defp handle_txbytes_based_request(conn, params, api_function, template) do
    with {:ok, txbytes} <- expect(params, "txbytes", :hex) do
      txbytes
      |> api_function.()
      |> api_response(conn, template)
    end
  end
end
