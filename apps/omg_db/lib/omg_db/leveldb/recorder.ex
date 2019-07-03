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

defmodule OMG.DB.LevelDB.Recorder do
  @moduledoc """
  A GenServer template for metrics recording.
  """
  use GenServer
  @default_interval 5_000
  @write :leveldb_write
  @read :leveldb_read
  @multiread :leveldb_multiread
  @keys [@write, @read, @multiread]

  @type t :: %__MODULE__{
          name: atom(),
          parent: pid(),
          key: charlist() | nil,
          interval: pos_integer(),
          tref: reference() | nil,
          node: String.t() | nil,
          table: atom()
        }
  defstruct name: nil,
            parent: nil,
            key: nil,
            interval: @default_interval,
            tref: nil,
            node: nil,
            table: nil

  @spec update_write(atom()) :: integer()
  def update_write(table) do
    :ets.update_counter(table, @write, {2, 1}, {@write, 0})
  end

  @spec update_read(atom()) :: integer()
  def update_read(table) do
    :ets.update_counter(table, @read, {2, 1}, {@read, 0})
  end

  @spec update_multiread(atom()) :: integer()
  def update_multiread(table) do
    :ets.update_counter(table, @multiread, {2, 1}, {@multiread, 0})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts.name)
  end

  def init(opts) do
    {:ok, tref} = :timer.send_interval(opts.interval, self(), :gather)

    {:ok,
     %{
       opts
       | key: to_charlist(opts.name),
         interval: get_interval(opts.name) || @default_interval,
         tref: tref,
         node: Atom.to_string(Node.self()),
         table: opts.table
     }}
  end

  def handle_info(:gather, state) do
    measurements =
      Enum.reduce(@keys, %{}, fn table_key, acc ->
        case :ets.take(state.table, table_key) do
          [{key, value}] -> Map.put(acc, key, value)
          _ -> acc
        end
      end)
      |> Map.put(:message_queue_len, Process.info(state.parent, :message_queue_len) |> elem(1))

    :telemetry.execute(OMG.Utils.Metrics.to_event_name(state.name), measurements, %{node: state.node})

    {:noreply, state}
  end

  # check configuration and system env variable, otherwise use the default
  defp get_interval(name) do
    case Application.get_env(:omg_status, String.to_atom("#{name}_interval")) do
      nil ->
        name
        |> Atom.to_string()
        |> String.upcase()
        |> Kernel.<>("_INTERVAL")
        |> System.get_env()

      num ->
        num
    end
  end
end
