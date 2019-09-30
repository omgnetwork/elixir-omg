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
  """

  alias OMG.Block
  alias OMG.ChildChain.BlockQueueCore
  alias OMG.ChildChain.BlockQueue.Core.BlockSubmission
  alias OMG.ChildChain.FreshBlocks

  defmodule Server do
    @moduledoc """
    Handles timing of calls to root chain.
    Driven by block height and mined transaction data delivered by local geth node and new blocks
    formed by server. Resubmits transaction until it is mined.
    """

    use GenServer
    use OMG.Utils.LoggerExt

    alias DB
    alias OMG.Eth
    alias OMG.Eth.Encoding
    alias OMG.Eth.EthereumHeight
    alias OMG.Eth.Rootchain

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

      config = load_config()
      {:ok, state} = BlockQueueCore.init_state(config)

      # `link: true` because we want the `BlockQueue` to restart and resubscribe, if the bus crashes
      # TODO: Any reason to subscribe after we've triggered the timer?
      :ok = OMG.Bus.subscribe("blocks", link: true)

      {:ok, _} = :timer.send_interval(get_check_interval(), self(), :sync_with_ethereum)
      {:ok, _} = :timer.send_interval(get_metrics_interval(), self(), :send_metrics)

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

      BlockQueueCore.sync_with_ethereum(state, %{
        ethereum_height: parent_height,
        mined_child_block_num: mined_child_block_num,
        is_empty_block: is_empty_block?
      })
    end

    defp do_internal_event_bus(block, state) do
      {:ok, parent_height} = EthereumHeight.get()
      BlockQueueCore.enqueue_block(state, block, parent_height)
    end

    defp load_config do
      with {:ok, parent_height} = EthereumHeight.get(),
         {:ok, mined_child_block_num} = RootChain.get_mined_child_block(),
         {:ok, chain_start_parent_height} = RootChain.get_root_deployment_height(),
         {:ok, child_block_interval} = RootChain.get_child_block_interval(),
         {:ok, stored_child_top_num} = DB.get_single_value(:child_top_block_number),
         {:ok, finality_threshold} = Application.fetch_env(:omg_child_chain, :submission_finality_margin)
      do
        %{
          parent_height: parent_height,
          mined_child_block_num: mined_child_block_num,
          chain_start_parent_height: chain_start_parent_height,
          child_block_interval: child_block_interval,
          stored_child_top_num: stored_child_top_num,
          finality_threshold: finality_threshold
        }
      else
        error ->
          # TODO: Log?
          error
      end
    end

    defp get_check_interval do
      Application.fetch_env!(:omg_child_chain, :block_queue_eth_height_check_interval_ms)
    end

    defp get_metrics_interval do
      Application.fetch_env!(:omg_child_chain, :metrics_collection_interval)
    end
  end
end
