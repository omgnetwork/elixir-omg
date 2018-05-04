#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule OmiseGO.WS.Server do
  @moduledoc """
  Cowboy server serving the Websocket handler
  """

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, [nil, nil]}
    }
  end

  def start(_type, _args) do
    ws_port = Application.get_env(:omisego_ws, :omisego_api_ws_port)
    dispatch_config = build_dispatch_config()
    {:ok, _} = :cowboy.start_http(:http, 100, [{:port, ws_port}], [{:env, [{:dispatch, dispatch_config}]}])
  end

  defp build_dispatch_config do
    :cowboy_router.compile([{:_, [{"/", OmiseGO.WS.Handler, []}]}])
  end
end
