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

defmodule OMG.Watcher.Web.Controller.InflightExit do
  @moduledoc """
  Operations related to in flight exits starting and handling.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.Watcher.API
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  action_fallback(OMG.Watcher.Web.Controller.Fallback)

  @doc """
  For a given transaction provided in params,
  responds with arguments for plasma contract function that starts in-flight exit.
  """
  def get_in_flight_exit(conn, params) do
    with {:ok, txbytes_enc} <- Map.fetch(params, "txbytes"),
         {:ok, txbytes} <- Base.decode16(txbytes_enc, case: :mixed) do
      in_flight_exit = API.InflightExit.get_in_flight_exit(txbytes)
      respond(in_flight_exit, :in_flight_exit, conn)
    end
  end

  def get_competitor(conn, params) do
    with {:ok, txbytes_enc} <- Map.fetch(params, "txbytes"),
         {:ok, txbytes} <- Base.decode16(txbytes_enc, case: :mixed) do
      competitor = API.InflightExit.get_competitor(txbytes)
      respond(competitor, :competitor, conn)
    end
  end

  def prove_canonical(conn, params) do
    with {:ok, txbytes_enc} <- Map.fetch(params, "txbytes"),
         {:ok, txbytes} <- Base.decode16(txbytes_enc, case: :mixed) do
      competitor = API.InflightExit.prove_canonical(txbytes)
      respond(competitor, :prove_canonical, conn)
    end
  end

  defp respond({:ok, in_flight_exit}, :in_flight_exit, conn) do
    render(conn, View.InflightExit, :in_flight_exit, in_flight_exit: in_flight_exit)
  end

  defp respond({:ok, competitor}, :competitor, conn) do
    render(conn, View.InflightExit, :competitor, competitor: competitor)
  end

  defp respond({:ok, prove_canonical}, :prove_canonical, conn) do
    render(conn, View.InflightExit, :prove_canonical, prove_canonical: prove_canonical)
  end

  defp respond({:error, code}, _, conn) do
    handle_error(conn, code)
  end
end
