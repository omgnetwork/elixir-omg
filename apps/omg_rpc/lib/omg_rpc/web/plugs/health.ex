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

  The module serves and a guard from requests reaching unhealthy services.
  When an application that needs ethereum node connectivity raises an alarm, we react to that alarm
  and prevent requests reach the underlying controllers. We do the same when there's a long boot
  process.

  The mechanics: we're subscribed to alarms, when we receive an alarm we cast the alarm to
  the genserver implemented in the same module and that server increments the alarm key in the ETS table @table_name.
  ETS table query is super fast and it gets hit with every request. If an alarm key is set to 1, we
  reject the request with service_unavailable response.

  """

  alias OMG.Status.Alert.Alarm
  alias OMG.Utils.HttpRPC.Error
  alias Phoenix.Controller

  import Plug.Conn
  require Logger
  use GenServer

  @table_name :rpc_node_alarms
  @alarms [:boot_in_progress, :ethereum_client_connection]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :gen_server, name: __MODULE__)
  end

  def handle_cast({:service_available, key}, state) when key in @alarms do
    do_clear(key)
    {:noreply, state}
  end

  def handle_cast({:service_unavailable, key}, state) when key in @alarms do
    _ = do_raise(key)
    {:noreply, state}
  end

  def handle_event({:clear_alarm, {alarm, _}}, state) when alarm in @alarms do
    _ = Logger.warn("Alarm #{alarm} was cleared.")
    :ok = GenServer.cast(__MODULE__, {:service_available, alarm})
    {:ok, state}
  end

  def handle_event({:set_alarm, {alarm, _}}, state) when alarm in @alarms do
    _ = Logger.warn("Alarm #{alarm} was raised.")
    :ok = GenServer.cast(__MODULE__, {:service_unavailable, alarm})
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
        # if rpc app is started last we might miss any previously raised alarms
        # so we resend all alarms that we can handle. Handlers that already reacted to an alarm
        # need to be idempotent.
        alarms = Alarm.all()

        alarms
        |> Enum.filter(fn {id, _} -> id in @alarms end)
        |> Enum.each(&:alarm_handler.set_alarm(&1))
    end
  end

  defp do_raise(key), do: :ets.update_counter(@table_name, key, {2, 1, 1, 1}, {key, 0})
  defp do_clear(key), do: :ets.update_counter(@table_name, key, {2, -1, 0, 0}, {key, 1})
end
