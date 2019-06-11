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

defmodule OMG.Eth.SubscriptionWorker do
  @moduledoc """
  Listens for events passed in as `listen_to`.
  """
  use WebSockex

  @subscription_id 1

  #
  # Client API
  #

  @doc """
  Starts a GenServer that listens to events.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | no_return()
  def start_link(opts) do
    _ = Process.flag(:trap_exit, true)

    ws_url =
      case Keyword.get(opts, :ws_url) do
        nil -> Application.get_env(:omg_eth, :ws_url)
        ws_url -> ws_url
      end

    {:ok, pid} = WebSockex.start_link(ws_url, __MODULE__, opts, opts)
    :ok = listen(pid, opts)
    {:ok, pid}
  end

  defp listen(pid, opts) do
    payload = %{
      jsonrpc: "2.0",
      id: @subscription_id,
      method: "eth_subscribe",
      params: [
        Keyword.get(opts, :listen_to)
      ]
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(payload)})
  end

  #
  # Server API
  #

  @doc false
  @spec init(any()) :: {:ok, any()}
  def init(opts) do
    {:ok, opts}
  end

  @doc false
  @impl true
  def handle_frame({:text, msg}, state) do
    {:ok, decoded} = Jason.decode(msg)
    {:links, links} = Process.info(self(), :links)

    _ =
      Enum.each(links, fn
        link when is_pid(link) ->
          :ok = GenServer.cast(link, {:event_received, Keyword.get(state, :listen_to), decoded})

        _ ->
          :skip
      end)

    {:ok, state}
  end
end
