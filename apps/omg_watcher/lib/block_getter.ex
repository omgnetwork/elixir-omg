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

defmodule OMG.Watcher.BlockGetter do
  @moduledoc """
  Downloads blocks from child chain, validates them and updates watcher state.
  Manages simultaneous getting and stateless-processing of blocks.
  Detects byzantine behaviors like invalid blocks and block withholding and notifies Eventer.
  """
  alias OMG.API.Block
  alias OMG.API.EventerAPI
  alias OMG.API.RootChainCoordinator
  alias OMG.API.State
  alias OMG.Eth
  alias OMG.Watcher.BlockGetter.Core
  alias OMG.Watcher.DB

  use GenServer
  use OMG.API.LoggerExt

  @spec download_block(pos_integer()) ::
          {:ok, Block.t() | Core.PotentialWithholding.t()} | {:error, Core.block_error(), binary(), pos_integer()}
  defp download_block(requested_number) do
    {:ok, {requested_hash, block_timestamp}} = Eth.RootChain.get_child_chain(requested_number)
    response = OMG.JSONRPC.Client.call(:get_block, %{hash: requested_hash})

    Core.validate_download_response(
      response,
      requested_hash,
      requested_number,
      block_timestamp,
      :os.system_time(:millisecond)
    )
  end

  def handle_cast(
        {:apply_block, %{transactions: transactions, number: blknum, zero_fee_requirements: fees} = block,
         block_rootchain_height},
        state
      ) do
    tx_exec_results = for tx <- transactions, do: OMG.API.State.exec(tx, fees)
    {continue, events} = Core.validate_tx_executions(tx_exec_results, block)

    # TODO: Unfortunately due to strange issue with SQLite on tests we cannot fetch this number at init
    # as it was tried in c972be3831bc2eab7a8816ae408a6195ba2f3ef4,
    # we should be able to revert when test will be run on Postgres
    last_persisted_block = DB.Block.get_max_blknum()
    blocks_to_persist = Core.ensure_block_imported_once(block, block_rootchain_height, last_persisted_block)

    EventerAPI.emit_events(events)

    with :ok <- continue do
      _ = Enum.map(blocks_to_persist, &DB.Transaction.update_with/1)
      _ = Logger.info(fn -> "Applied block \##{inspect(blknum)}" end)
      state = run_block_download_task(state)

      :ok = OMG.API.State.close_block(block_rootchain_height)

      {state, synced_height, db_updates} = Core.apply_block(state, blknum, block_rootchain_height)
      :ok = RootChainCoordinator.check_in(synced_height, __MODULE__)
      :ok = OMG.DB.multi_update(db_updates)

      {:noreply, state}
    else
      {:needs_stopping, reason} ->
        _ = Logger.error(fn -> "Stopping #{inspect(__MODULE__)} because of #{inspect(reason)}" end)
        {:stop, :shutdown, state}
    end
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, deployment_height} = Eth.RootChain.get_root_deployment_height()
    {:ok, last_synced_height} = OMG.DB.last_block_getter_eth_height()
    synced_height = max(deployment_height, last_synced_height)

    {current_block_height, state_at_block_beginning} = State.get_status()
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    # State treats current as the next block to be executed or a block that is being executed
    # while top block number is a block that has been formed (they differ by the interval)
    child_top_block_number = current_block_height - child_block_interval

    {:ok, block_submissions} = Eth.RootChain.get_block_submitted_events({synced_height, synced_height + 1000})
    exact_synced_height = Core.figure_out_exact_sync_height(block_submissions, synced_height, child_top_block_number)

    :ok = RootChainCoordinator.check_in(exact_synced_height, __MODULE__)

    height_sync_interval = Application.get_env(:omg_watcher, :block_getter_height_sync_interval_ms)
    {:ok, _} = schedule_sync_height(height_sync_interval)
    :producer = send(self(), :producer)

    maximum_block_withholding_time_ms = Application.get_env(:omg_watcher, :maximum_block_withholding_time_ms)
    maximum_number_of_unapplied_blocks = Application.get_env(:omg_watcher, :maximum_number_of_unapplied_blocks)

    {:ok, state} =
      Core.init(
        child_top_block_number,
        child_block_interval,
        exact_synced_height,
        state_at_block_beginning,
        maximum_block_withholding_time_ms: maximum_block_withholding_time_ms,
        maximum_number_of_unapplied_blocks: maximum_number_of_unapplied_blocks,
        # TODO: not elegant, but this should limit the number of heavy-lifting workers and chance to starve the rest
        maximum_number_of_pending_blocks: System.schedulers() - 1
      )

    {:ok, state}
  end

  @spec handle_info(
          :producer
          | {reference(), {:downloaded_block, {:ok, map}}}
          | {reference(), {:downloaded_block, {:error, Core.block_error()}}}
          | {:DOWN, reference(), :process, pid, :normal},
          Core.t()
        ) :: {:noreply, Core.t()} | {:stop, :normal, Core.t()}
  def handle_info(msg, state)

  def handle_info(:producer, state) do
    new_state = run_block_download_task(state)

    {:ok, _} = :timer.send_after(2_000, self(), :producer)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:downloaded_block, response}}, state) do
    # 1/ process the block that arrived and consume
    {continue, new_state, events} = Core.handle_downloaded_block(state, response)

    EventerAPI.emit_events(events)

    with :ok <- continue do
      {:noreply, new_state}
    else
      {:needs_stopping, reason} ->
        _ = Logger.error(fn -> "Stopping #{inspect(__MODULE__)} because of #{inspect(reason)}" end)
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state), do: {:noreply, state}

  def handle_info(:sync, state) do
    with {:sync, next_synced_height} <- RootChainCoordinator.get_height() do
      block_range = Core.get_eth_range_for_block_submitted_events(state, next_synced_height)
      {:ok, submissions} = Eth.RootChain.get_block_submitted_events(block_range)

      {blocks_to_apply, synced_height, db_updates, state} =
        Core.get_blocks_to_apply(state, submissions, next_synced_height)

      Enum.each(blocks_to_apply, fn {block, eth_height} ->
        GenServer.cast(__MODULE__, {:apply_block, block, eth_height})
      end)

      :ok = OMG.DB.multi_update(db_updates)
      :ok = RootChainCoordinator.check_in(synced_height, __MODULE__)
      {:noreply, state}
    else
      :nosync ->
        :ok = RootChainCoordinator.check_in(state.synced_height, __MODULE__)
        {:noreply, state}
    end
  end

  defp run_block_download_task(state) do
    {:ok, next_child} = Eth.RootChain.get_current_child_block()
    {new_state, blocks_numbers} = Core.get_numbers_of_blocks_to_download(state, next_child)

    blocks_numbers
    |> Enum.each(
      # captures the result in handle_info/2 with the atom: downloaded_block
      &Task.async(fn -> {:downloaded_block, download_block(&1)} end)
    )

    new_state
  end

  defp schedule_sync_height(interval) do
    :timer.send_interval(interval, self(), :sync)
  end
end
