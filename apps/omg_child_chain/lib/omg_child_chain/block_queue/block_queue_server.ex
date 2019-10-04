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

defmodule OMG.ChildChain.BlockQueue.BlockQueueServer do
  @moduledoc """
  Imperative shell for `OMG.ChildChain.BlockQueue.Core`, see there for more info

  The new blocks to enqueue arrive here via `OMG.Bus`

  Handles timing of calls to root chain.
  Driven by block height and mined transaction data delivered by local geth node and new blocks
  formed by server. Resubmits transaction until it is mined.
  """
  use GenServer
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.BlockQueueCore

  alias OMG.ChildChain.BlockQueue.BlockQueueCore
  alias OMG.ChildChain.BlockQueue.BlockQueueSubmitter

  alias OMG.ChildChain.FreshBlocks

  alias DB
  alias OMG.Eth
  alias OMG.Eth.EthereumHeight
  alias OMG.Eth.RootChain

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, %{}, {:continue, :setup}}
  end

  def handle_continue(:setup, %{}) do
    # _ = BlockQueueLogger.log(:starting, __MODULE__)

    # Ensure external services are running (Ethereum node and childchain contract)
    :ok = Eth.node_ready()
    :ok = RootChain.contract_ready()

    {:ok, state} = BlockQueueCore.init()

    # `link: true` because we want the `BlockQueue` to restart and resubscribe, if the bus crashes
    # TODO: Any reason to subscribe after we've triggered the timer?
    :ok = OMG.Bus.subscribe("blocks", link: true)

    {:ok, _} = :timer.send_interval(BlockQueueCore.get_check_interval(), self(), :sync_with_ethereum)
    {:ok, _} = :timer.send_interval(BlockQueueCore.get_metrics_interval(), self(), :send_metrics)

    # _ = BlockQueueLogger.log(:started, __MODULE__)
    # _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:noreply, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  @doc """
  Checks the status of the Ethereum root chain, the top mined child block number
  and status of State to decide what to do
  """
  def handle_info(:sync_with_ethereum, state) do
    {:noreply, do_sync_with_ethereum(state)}
  end

  def handle_info(block, state) do
    {:noreply, do_internal_event_bus(block, state)}
  end

  defp do_sync_with_ethereum(state) do
    {:ok, parent_height} = EthereumHeight.get()
    {:ok, mined_child_block_num} = RootChain.get_mined_child_block()
    {_, is_empty_block?} = OMG.State.get_status()

    {form_block_or_skip, state} =
      BlockQueueCore.sync_with_ethereum(state, %{
        ethereum_height: parent_height,
        mined_child_block_num: mined_child_block_num,
        is_empty_block: is_empty_block?
      })

    :ok = BlockQueueSubmitter.submit_blocks_or_skip(state, form_block_or_skip)

    state
  end

  defp do_internal_event_bus(block, state) do
    {:ok, parent_height} = EthereumHeight.get()
    state = BlockQueueCore.enqueue_block(state, block, parent_height)

    :ok = FreshBlocks.push(block)
    :ok = BlockQueueSubmitter.submit_blocks_or_skip(state, :do_form_block)

    state
  end
end
