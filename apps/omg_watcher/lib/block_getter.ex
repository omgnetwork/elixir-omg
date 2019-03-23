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

  Reponsible for processing all block submissions and processing them once, regardless of the reorg situation.
  Note that the former responsibility is quite involved, as `BlockGetter` should have any finality margin configured,
  i.e. it should be prepared to be served not-yet-confirmed eth heights from the `OMG.RootChainCoordinator`
  """

  alias OMG.Eth
  alias OMG.RootChainCoordinator
  alias OMG.RootChainCoordinator.SyncGuide
  alias OMG.RPC.Client
  alias OMG.State
  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.Watcher.BlockGetter.Core
  alias OMG.Watcher.DB
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.Recorder

  use GenServer
  use OMG.LoggerExt

  def get_events do
    GenServer.call(__MODULE__, :get_events)
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}, {:continue, :setup}}
  end

  def handle_continue(:setup, %{}) do
    {:ok, deployment_height} = Eth.RootChain.get_root_deployment_height()
    {:ok, last_synced_height} = OMG.DB.get_single_value(:last_block_getter_eth_height)
    synced_height = max(deployment_height, last_synced_height)

    {current_block_height, state_at_block_beginning} = State.get_status()
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
    # State treats current as the next block to be executed or a block that is being executed
    # while top block number is a block that has been formed (they differ by the interval)
    child_top_block_number = current_block_height - child_block_interval

    last_persisted_block = DB.Block.get_max_blknum()

    # how many eth blocks backward can change during an reorg
    block_getter_reorg_margin = Application.fetch_env!(:omg_watcher, :block_getter_reorg_margin)
    maximum_block_withholding_time_ms = Application.fetch_env!(:omg_watcher, :maximum_block_withholding_time_ms)
    maximum_number_of_unapplied_blocks = Application.fetch_env!(:omg_watcher, :maximum_number_of_unapplied_blocks)

    exit_processor_initial_results = ExitProcessor.check_validity()

    {:ok, state} =
      Core.init(
        child_top_block_number,
        child_block_interval,
        synced_height,
        block_getter_reorg_margin,
        last_persisted_block,
        state_at_block_beginning,
        exit_processor_initial_results,
        maximum_block_withholding_time_ms: maximum_block_withholding_time_ms,
        maximum_number_of_unapplied_blocks: maximum_number_of_unapplied_blocks,
        # NOTE: not elegant, but this should limit the number of heavy-lifting workers and chance to starve the rest
        maximum_number_of_pending_blocks: System.schedulers()
      )

    :ok = RootChainCoordinator.check_in(synced_height, __MODULE__)
    {:ok, _} = schedule_sync_height()
    {:ok, _} = schedule_producer()

    {:ok, _} = Recorder.start_link(%Recorder{name: __MODULE__.Recorder, parent: self()})

    {:noreply, state}
  end

  def handle_call(:get_events, _from, state) do
    {:reply, Core.chain_ok(state), state}
  end

  def handle_cast(
        {:apply_block,
         %BlockApplication{
           transactions: transactions,
           number: blknum,
           eth_height: eth_height
         } = to_apply},
        state
      ) do
    with {:ok, _} <- Core.chain_ok(state),
         tx_exec_results = for(tx <- transactions, do: OMG.State.exec(tx, :ignore)),
         {:ok, state} <- Core.validate_executions(tx_exec_results, to_apply, state) do
      _ =
        to_apply
        |> Core.ensure_block_imported_once(state)
        |> Enum.each(&DB.Transaction.update_with/1)

      state = run_block_download_task(state)

      {:ok, db_updates_from_state} = OMG.State.close_block(eth_height)

      {state, synced_height, db_updates} = Core.apply_block(state, to_apply)

      _ = Logger.debug("Synced height update: #{inspect(db_updates)}")

      :ok = OMG.DB.multi_update(db_updates ++ db_updates_from_state)
      :ok = RootChainCoordinator.check_in(synced_height, __MODULE__)

      exit_processor_results = ExitProcessor.check_validity()
      state = Core.consider_exits(state, exit_processor_results)

      _ =
        Logger.info(
          "Applied block: \##{inspect(blknum)}, from eth height: #{inspect(eth_height)} " <>
            "with #{inspect(length(transactions))} txs"
        )

      {:noreply, state}
    else
      {{:error, _} = error, new_state} ->
        _ = Logger.error("Invalid block #{inspect(blknum)}, because of #{inspect(error)}")
        {:noreply, new_state}

      {:error, _} = error ->
        _ = Logger.warn("Chain already invalid before applying block #{inspect(blknum)} because of #{inspect(error)}")
        {:noreply, state}
    end
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
    with {:ok, _} <- Core.chain_ok(state) do
      new_state = run_block_download_task(state)
      {:ok, _} = schedule_producer()
      {:noreply, new_state}
    else
      {:error, _} = error ->
        _ = Logger.warn("Chain invalid when trying to download blocks, because of #{inspect(error)}, won't try again")
        {:noreply, state}
    end
  end

  def handle_info({_ref, {:downloaded_block, response}}, state) do
    # 1/ process the block that arrived and consume

    with {:ok, state} <- Core.handle_downloaded_block(state, response) do
      state = run_block_download_task(state)
      {:noreply, state}
    else
      {{:error, _} = error, state} ->
        _ = Logger.error("Error while handling downloaded block because of #{inspect(error)}")

        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state), do: {:noreply, state}

  def handle_info(:sync, state) do
    with %SyncGuide{sync_height: next_synced_height} <- RootChainCoordinator.get_sync_info() do
      block_range = Core.get_eth_range_for_block_submitted_events(state, next_synced_height)

      {time, {:ok, submissions}} = :timer.tc(fn -> Eth.RootChain.get_block_submitted_events(block_range) end)
      time = round(time / 1000)

      _ =
        if time > Application.fetch_env!(:omg_eth, :ethereum_client_warning_time_ms),
          do:
            Logger.warn(
              "Query to Ethereum client took long: #{inspect(time)} ms " <>
                "to get #{inspect(length(submissions))} events from range #{inspect(block_range)}"
            )

      _ = Logger.debug("Submitted #{length(submissions)} plasma blocks on Ethereum block range #{inspect(block_range)}")

      {blocks_to_apply, synced_height, db_updates, state} =
        Core.get_blocks_to_apply(state, submissions, next_synced_height)

      _ = Logger.debug("Synced height is #{inspect(synced_height)}, got #{length(blocks_to_apply)} blocks to apply")

      Enum.each(blocks_to_apply, &GenServer.cast(__MODULE__, {:apply_block, &1}))

      :ok = OMG.DB.multi_update(db_updates)
      :ok = RootChainCoordinator.check_in(synced_height, __MODULE__)
      {:ok, _} = schedule_sync_height()

      {:noreply, state}
    else
      :nosync ->
        :ok = RootChainCoordinator.check_in(state.synced_height, __MODULE__)
        {:noreply, state}
    end
  end

  defp run_block_download_task(state) do
    {:ok, next_child} = Eth.RootChain.get_next_child_block()
    {new_state, blocks_numbers} = Core.get_numbers_of_blocks_to_download(state, next_child)

    blocks_numbers
    |> Enum.each(
      # captures the result in handle_info/2 with the atom: downloaded_block
      &Task.async(fn -> {:downloaded_block, download_block(&1)} end)
    )

    new_state
  end

  defp schedule_sync_height do
    Application.fetch_env!(:omg_watcher, :block_getter_loops_interval_ms)
    |> :timer.send_after(self(), :sync)
  end

  defp schedule_producer do
    Application.fetch_env!(:omg_watcher, :block_getter_loops_interval_ms)
    |> :timer.send_after(self(), :producer)
  end

  @spec download_block(pos_integer()) :: Core.validate_download_response_result_t()
  defp download_block(requested_number) do
    {:ok, {requested_hash, block_timestamp}} = Eth.RootChain.get_child_chain(requested_number)
    response = Client.get_block(requested_hash)

    Core.validate_download_response(
      response,
      requested_hash,
      requested_number,
      block_timestamp,
      :os.system_time(:millisecond)
    )
  end
end
