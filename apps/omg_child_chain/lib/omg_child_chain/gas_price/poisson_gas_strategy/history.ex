# Copyright 2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.GasPrice.PoissonGasStrategy.History do
  @moduledoc """
  Responsible for creating the gas price history store and managing its records,
  including fetching, transforming, inserting and pruning the gas price records.
  """
  use GenServer
  require Logger

  alias OMG.ChildChain.GasPrice.PoissonGasStrategy.Fetcher
  alias OMG.Eth.Encoding
  alias OMG.Eth.EthereumHeight

  @num_blocks 200
  @history_table :gas_price_history

  @type state() :: %__MODULE__{
          earliest_stored_height: non_neg_integer(),
          latest_stored_height: non_neg_integer()
        }

  defstruct earliest_stored_height: 0,
            latest_stored_height: 0

  @type record() :: {height :: non_neg_integer(), prices :: [float()], timestamp :: non_neg_integer()}

  @doc false
  @spec start_link([event_bus: module()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec all() :: [record()]
  def all() do
    :ets.match(@history_table, "$1")
  end

  #
  # GenServer initialization
  #

  @doc false
  @impl GenServer
  def init(opts) do
    state = %__MODULE__{}
    event_bus = Keyword.fetch!(opts, :event_bus)

    _ = Logger.info("Started #{inspect(__MODULE__)}: #{inspect(state)}")
    {:ok, state, {:continue, {:initialize, event_bus}}}
  end

  @doc false
  @impl GenServer
  def handle_continue({:initialize, event_bus}, state) do
    :prices = :ets.new(@history_table, [:ordered_set, :protected, :named_table])
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    _ = Logger.info("Started #{__MODULE__}: #{inspect(state)}")
    {:noreply, state, {:continue, :populate_prices}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:populate_prices, state) do
    {:ok, to_height} = EthereumHeight.get()
    from_height = to_height - @num_blocks
    :ok = do_populate_prices(from_height, to_height, state)

    {:noreply, %{state | earliest_stored_height: from_height, latest_stored_height: to_height}}
  end

  #
  # GenServer callbacks
  #

  @doc false
  @impl GenServer
  def handle_info({:internal_event_bus, :ethereum_new_height, height}, state) do
    from_height = max(height - @num_blocks, state.earliest_stored_height)
    :ok = do_populate_prices(from_height, height, state)

    {:noreply, %{state | earliest_stored_height: from_height, latest_stored_height: height}}
  end

  #
  # Internal implementations
  #

  defp do_populate_prices(from_height, to_height, state) do
    :ok =
      from_height..to_height
      |> Fetcher.stream()
      |> stream_insert()
      |> Stream.run()

    :ok = prune_heights(state.earliest_stored_height, from_height - 1)
    _ = Logger.info("#{__MODULE__} removed gas prices from Eth heights: #{state.earliest_stored_height} - #{from_height - 1}.")
    _ = Logger.info("#{__MODULE__} populated gas prices from Eth heights: #{from_height} - #{to_height}.")
  end

  defp stream_insert(stream_blocks) do
    Stream.each(stream_blocks, fn block ->
      height = Encoding.int_from_hex(block["number"])
      prices = Enum.map(block["transactions"], fn tx -> Encoding.int_from_hex(tx["gasPrice"]) end)
      timestamp = Encoding.int_from_hex(block["timestamp"])

      true = :ets.insert(@history_table, {height, prices, timestamp})
    end)
  end

  defp prune_heights(from, to) do
    Enum.each(from..to, fn height -> :ets.delete(@history_table, height) end)
  end
end
