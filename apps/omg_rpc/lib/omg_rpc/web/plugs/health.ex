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

defmodule OMG.RPC.Plugs.Health do
  @moduledoc """
  this is primarily a Plug, but we're subscribing to Alarms as well, so that we're able to reject API calls.
  """

  alias Phoenix.Controller
  import Plug.Conn
  alias Utils.JsonRPC.Error
  require Logger
  use GenServer

  @table_name :rpc_node_alarms

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :gen_server, name: __MODULE__)
  end

  def handle_cast({:service_available, :ethereum_client_connection = key}, state) do
    do_clear(key)
    {:noreply, state}
  end

  def handle_cast({:service_available, :boot_in_progress = key}, state) do
    _ = do_clear(key)
    {:noreply, state}
  end

  def handle_cast({:service_unavailable, :ethereum_client_connection = key}, state) do
    _ = do_raise(key)
    {:noreply, state}
  end

  def handle_cast({:service_unavailable, :boot_in_progress = key}, state) do
    _ = do_raise(key)
    {:noreply, state}
  end

  def handle_event({:clear_alarm, {:ethereum_client_connection, _}}, state) do
    _ = Logger.warn("Alarm :ethereum_client_connection was cleared.")
    :ok = GenServer.cast(__MODULE__, {:service_available, :ethereum_client_connection})
    {:ok, state}
  end

  def handle_event({:set_alarm, {:ethereum_client_connection, _}}, state) do
    _ = Logger.warn("Alarm :ethereum_client_connection was raised.")
    :ok = GenServer.cast(__MODULE__, {:service_unavailable, :ethereum_client_connection})
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:boot_in_progress, _}}, state) do
    _ = Logger.warn("Alarm :boot_in_progress was cleared.")
    :ok = GenServer.cast(__MODULE__, {:service_available, :boot_in_progress})
    {:ok, state}
  end

  def handle_event({:set_alarm, {:boot_in_progress, _}}, state) do
    _ = Logger.warn("Alarm :boot_in_progress was raised.")
    :ok = GenServer.cast(__MODULE__, {:service_unavailable, :boot_in_progress})
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("Health RPC plug got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  # gen server boot
  def init(:gen_server) do
    table_setup()
    install()
    {:ok, %{}}
  end

  # gen_event boot
  def init(:gen_event), do: {:ok, %{}}

  ###
  ### PLUG
  ###
  def init(options), do: options

  def call(conn, _params) do
    # is anything raised?

    case :ets.match_object(@table_name, {:_, 1}) do
      [] ->
        conn

      _ ->
        data = Error.serialize("operation:service_unavailable", "The server is not ready to handle the request.")

        conn
        |> Controller.json(data)
        |> halt()
    end
  end

  defp table_setup do
    _ = if :undefined == :ets.info(@table_name), do: @table_name = :ets.new(@table_name, table_settings())
  end

  defp table_settings, do: [:named_table, :set, :public, read_concurrency: true]

  defp install do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true ->
        :ok

      _ ->
        :alarm_handler.add_alarm_handler(__MODULE__, :gen_event)
    end
  end

  defp do_raise(key), do: :ets.update_counter(@table_name, key, {2, 1, 1, 1}, {key, 0})
  defp do_clear(key), do: :ets.update_counter(@table_name, key, {2, -1, 0, 0}, {key, 1})
end
