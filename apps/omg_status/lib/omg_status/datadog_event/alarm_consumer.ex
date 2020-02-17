# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.Status.DatadogEvent.AlarmConsumer do
  @moduledoc """
  Installs a alarm handler and publishes the alarms as events
  """

  require Logger

  @doc """
  Returns child_specs for the given `AlarmConsumer` setup, to be included e.g. in Supervisor's children.
  """
  @spec prepare_child(keyword()) :: %{id: atom(), start: tuple()}
  def prepare_child(opts \\ []) do
    %{id: :alarm_consumer, start: {__MODULE__, :start_link, [opts]}, shutdown: :brutal_kill, type: :worker}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(args) do
    alarm_handler_process = Keyword.get(args, :alarm_handler, :alarm_handler)
    dd_alarm_handler = Keyword.fetch!(args, :dd_alarm_handler)
    :ok = install_alarm_handler(alarm_handler_process, dd_alarm_handler)
    publisher = Keyword.fetch!(args, :publisher)

    release = Keyword.fetch!(args, :release)
    current_version = Keyword.fetch!(args, :current_version)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, %{publisher: publisher, release: release, current_version: current_version}}
  end

  # Gets events from the alarm consumer and send them off
  def handle_cast(alarm, state) do
    {alarm_type, data} = elem(alarm, 1)
    action = elem(alarm, 0)

    level =
      case action do
        :clear_alarm -> [alert_type: :info]
        _ -> [alert_type: :warning]
      end

    aggregation_key = :alarm
    timestamp = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    options = tags(aggregation_key, state.release, state.current_version, timestamp)
    title = "#{action} - #{inspect(alarm_type)}"
    message = "#{inspect(data)} - Timestamp: #{timestamp}"

    :ok = apply(state.publisher, :event, create_event_data(title, message, level ++ options))

    {:noreply, state}
  end

  defp create_event_data(title, message, options) do
    [title, message, options]
  end

  # https://docs.datadoghq.com/api/?lang=bash#api-reference
  defp tags(aggregation_key, release, current_version, _timestamp) do
    [
      {:aggregation_key, aggregation_key},
      {:tags, ["#{aggregation_key}", "#{release}", "vsn-#{current_version}"]}
    ]
  end

  defp install_alarm_handler(alarm_handler, dd_alarm_handler) do
    case Enum.member?(:gen_event.which_handlers(alarm_handler), dd_alarm_handler) do
      true -> :ok
      _ -> alarm_handler.add_alarm_handler(dd_alarm_handler, [self()])
    end
  end
end
