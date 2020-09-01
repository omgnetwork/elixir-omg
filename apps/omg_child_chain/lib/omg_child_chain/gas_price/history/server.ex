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

defmodule OMG.ChildChain.GasPrice.History.Server do
  @moduledoc """
  Responsible for creating the gas price history store and managing its records,
  including fetching, transforming, inserting and pruning the gas price records.

  Also provides subscription that triggers on history changes.

  This module utilizes [`ets`](https://elixir-lang.org/getting-started/mix-otp/ets.html)
  instead of GenServer for history storage for the following reasons:

    1. Multiple pricing strategies will be accessing the history. ets allows those strategies to
       access the records concurrently.

    2. Fetching the history is RPC-intensive and unnecessary between GenServer crashes.
       Using ets allows the records to persist across crashes.
  """
  use GenServer
  require Logger

  alias OMG.ChildChain.GasPrice.History
  alias OMG.ChildChain.GasPrice.History.Fetcher
  alias OMG.Eth.Encoding
  alias OMG.Eth.EthereumHeight

  @history_table :gas_price_history

  @type state() :: %__MODULE__{
          num_blocks: non_neg_integer(),
          earliest_stored_height: non_neg_integer(),
          latest_stored_height: non_neg_integer(),
          history_ets: :ets.tid(),
          ethereum_url: String.t(),
          event_bus: module()
        }

  defstruct num_blocks: 200,
            earliest_stored_height: 0,
            latest_stored_height: 0,
            history_ets: nil,
            ethereum_url: nil,
            event_bus: nil

  @doc false
  @spec all() :: History.t()
  def all() do
    # No need to go through the GenSever to fetch from ets.
    :ets.tab2list(@history_table)
  end

  #
  # GenServer initialization
  #

  @doc false
  @impl GenServer
  def init(opts) do
    num_blocks = Keyword.fetch!(opts, :num_blocks)
    ethereum_url = Keyword.fetch!(opts, :ethereum_url)
    event_bus = Keyword.fetch!(opts, :event_bus)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    # The ets table is not initialized with `:read_concurrency` because we are expecting interleaving
    # reads and writes. See http://erlang.org/doc/man/ets.html
    history_ets = :ets.new(@history_table, [:ordered_set, :protected, :named_table])

    state = %__MODULE__{
      num_blocks: num_blocks,
      history_ets: history_ets,
      ethereum_url: ethereum_url,
      event_bus: event_bus
    }

    _ = Logger.info("Started #{__MODULE__}: #{inspect(state)}")
    {:ok, state, {:continue, :first_fetch}}
  end

  @doc false
  @impl GenServer
  def handle_continue(:first_fetch, state) do
    {:ok, to_height} = EthereumHeight.get()
    from_height = to_height - state.num_blocks
    {:ok, earliest_height, latest_height} = do_populate_prices(from_height, to_height, state)

    state = %{state | earliest_stored_height: earliest_height, latest_stored_height: latest_height}

    {:noreply, state}
  end

  #
  # GenServer callbacks
  #

  @doc false
  @impl GenServer
  def handle_info({:internal_event_bus, :ethereum_new_height, height}, state) do
    from_height = height - state.num_blocks
    {:ok, earliest_height, latest_height} = do_populate_prices(from_height, height, state)

    {:noreply, %{state | earliest_stored_height: earliest_height, latest_stored_height: latest_height}}
  end

  #
  # Internal implementations
  #

  defp do_populate_prices(from_height, to_height, state) do
    fetch_from_height = max(from_height, state.latest_stored_height)

    # Fetch and insert new heights, leaving obsolete heights intact.
    :ok =
      fetch_from_height..to_height
      |> Fetcher.stream(state.ethereum_url)
      |> stream_insert(state.history_ets)
      |> Stream.run()

    # Prune obsolete heights.
    :ok = prune_heights(state.history_ets, state.earliest_stored_height, from_height - 1)

    _ =
      Logger.info(
        "#{__MODULE__} removed gas prices from Eth heights: #{state.earliest_stored_height} - #{from_height - 1}."
      )

    _ = Logger.info("#{__MODULE__} available gas prices from Eth heights: #{from_height} - #{to_height}.")

    # Publish `:history_updated` event through the OMG.Bus
    {:child_chain, "gas_price_history"}
    |> state.event_bus.new(:history_updated, to_height)
    |> state.event_bus.direct_local_broadcast()

    {:ok, from_height, to_height}
  end

  defp stream_insert(stream_blocks, history_ets) do
    Stream.each(stream_blocks, fn block ->
      height = Encoding.int_from_hex(block["number"])
      prices = Enum.map(block["transactions"], fn tx -> Encoding.int_from_hex(tx["gasPrice"]) end)
      timestamp = Encoding.int_from_hex(block["timestamp"])

      true = :ets.insert(history_ets, {height, prices, timestamp})
    end)
  end

  defp prune_heights(history_ets, from, to) do
    :ets.select_delete(history_ets, :ets.fun2ms(fn
      {height, _prices, _timestamp} when height >= from and height <= to -> true
    end))
  end
end
