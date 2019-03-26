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

defmodule OMG.DB.Recorder do
  @moduledoc """
  A GenServer template for metrics recording.
  """
  use GenServer
  @default_interval 5_000
  @table __MODULE__
  @write :write
  @read :read
  @multiread :multiread
  @keys [{@write, to_charlist(@write)}, {@read, to_charlist(@read)}, {@multiread, to_charlist(@multiread)}]

  @type t :: %__MODULE__{
          name: atom(),
          parent: pid(),
          key: charlist() | nil,
          interval: pos_integer(),
          reporter: (... -> atom()),
          tref: reference() | nil,
          node: String.t() | nil,
          table: atom()
        }
  defstruct name: nil,
            parent: nil,
            key: nil,
            interval: @default_interval,
            reporter: &Appsignal.set_gauge/3,
            tref: nil,
            node: nil,
            table: @table

  @spec update_write :: integer()
  def update_write(table \\ @table) do
    :ets.update_counter(table, @write, {2, 1}, {@write, 0})
  end

  @spec update_read :: integer()
  def update_read(table \\ @table) do
    :ets.update_counter(table, @read, {2, 1}, {@read, 0})
  end

  @spec update_multiread :: integer()
  def update_multiread(table \\ @table) do
    :ets.update_counter(table, @multiread, {2, 1}, {@multiread, 0})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts.name)
  end

  def init(opts) do
    table = create_stats_table(opts)
    {:ok, tref} = :timer.send_interval(opts.interval, self(), :gather)

    {:ok,
     %{
       opts
       | key: to_charlist(opts.name),
         interval: get_interval(opts.name) || @default_interval,
         tref: tref,
         node: Atom.to_string(:erlang.node()),
         table: table
     }}
  end

  def handle_info(:gather, state) do
    # invoke the reporter function and pass the key and value (invoke the fn)
    _ = state.reporter.(state.key, Process.info(state.parent, :message_queue_len) |> elem(1), %{node: state.node})

    _ =
      Enum.each(@keys, fn {table_key, key} ->
        case :ets.take(state.table, table_key) do
          [{^table_key, value}] -> _ = state.reporter.(key, value, %{node: state.node})
          _ -> :ok
        end
      end)

    {:noreply, state}
  end

  @spec create_stats_table(t) :: atom()
  def create_stats_table(%{name: __MODULE__}) do
    case :ets.whereis(@table) do
      :undefined ->
        true = @table == :ets.new(@table, table_settings())

        @table

      _ ->
        @table
    end
  end

  def create_stats_table(%{name: name}) do
    case :ets.whereis(name) do
      :undefined ->
        true = name == :ets.new(name, table_settings())

        name

      _ ->
        name
    end
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

  defp table_settings, do: [:named_table, :set, :public, write_concurrency: true]
end
