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

defmodule OMG.DB.Measure do
  @moduledoc """
   A telemetry handler for DB related metrics.
  """
  alias OMG.Status.Metric.Datadog
  import OMG.Status.Metric.Event, only: [name: 1]

  alias RocksDB.Server

  @write :write
  @read :read
  @multiread :multiread
  @keys [@write, @read, @multiread]

  @services [Server]

  @supported_events List.foldl(@services, [], fn service, acc ->
                      acc ++
                        [
                          [:process, service],
                          [:update_write, service],
                          [:update_read, service],
                          [:update_multiread, service]
                        ]
                    end)
  def supported_events(), do: @supported_events

  def handle_event([:process, service_name], _, state, _config) when service_name in @services do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(:db_message_queue_len), value, tags: ["service_name:#{service_name}"])

    Enum.each(@keys, fn table_key ->
      case :ets.take(state.name, table_key) do
        [{key, value}] ->
          _ = Datadog.gauge(name(key), value)

        _ ->
          # handling the case where the entry doesn't exist yet
          :skip
      end
    end)
  end

  def handle_event([:update_write, service_name], _, state, _config) when service_name in @services do
    :ets.update_counter(state.name, @write, {2, 1}, {@write, 0})
  end

  def handle_event([:update_read, service_name], _, state, _config) when service_name in @services do
    :ets.update_counter(state.name, @read, {2, 1}, {@read, 0})
  end

  def handle_event([:update_multiread, service_name], _, state, _config) when service_name in @services do
    :ets.update_counter(state.name, @multiread, {2, 1}, {@multiread, 0})
  end
end
