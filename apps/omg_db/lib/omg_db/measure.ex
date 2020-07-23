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
  import OMG.Status.Metric.Event, only: [name: 1]
  alias OMG.DB.Monitor
  alias OMG.DB.RocksDB.Server
  alias OMG.Eth.Encoding
  alias OMG.Status.Metric.Datadog

  @write :write
  @read :read
  @multiread :multiread
  @keys [@write, @read, @multiread]

  @supported_events [
    [:process, Server],
    [:update_write, Server],
    [:update_read, Server],
    [:update_multiread, Server],
    [:balances, Monitor],
    [:total_unspent_addresses, Monitor],
    [:total_unspent_outputs, Monitor]
  ]

  def supported_events(), do: @supported_events

  def handle_event([:process, Server], _, state, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(:db_message_queue_len), value, tags: ["service_name:#{Server}"])

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

  def handle_event([:update_write, Server], _, state, _config) do
    :ets.update_counter(state.name, @write, {2, 1}, {@write, 0})
  end

  def handle_event([:update_read, Server], _, state, _config) do
    :ets.update_counter(state.name, @read, {2, 1}, {@read, 0})
  end

  def handle_event([:update_multiread, Server], _, state, _config) do
    :ets.update_counter(state.name, @multiread, {2, 1}, {@multiread, 0})
  end

  def handle_event([:balances, Monitor], measurements, _metadata, _config) do
    Enum.each(measurements.balances, fn {currency, amount} ->
      Datadog.gauge(name(:balance), amount, tags: ["currency:#{Encoding.to_hex(currency)}"])
    end)
  end

  def handle_event([:total_unspent_addresses, Monitor], measurements, _metadata, _config) do
    Datadog.gauge(name(:total_unspent_addresses), measurements.total_unspent_addresses)
  end

  def handle_event([:total_unspent_outputs, Monitor], measurements, _metadata, _config) do
    Datadog.gauge(name(:total_unspent_outputs), measurements.total_unspent_outputs)
  end
end
