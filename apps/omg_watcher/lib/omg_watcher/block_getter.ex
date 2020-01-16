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

defmodule OMG.Watcher.BlockGetter do
  @moduledoc """
  Downloads blocks from child chain, validates them and updates watcher state.
  Manages simultaneous getting and stateless-processing of blocks.
  Detects byzantine behaviors like invalid blocks and block withholding and exposes those events.

  Responsible for processing all block submissions and processing them once, regardless of the reorg situation.
  Note that the former responsibility is quite involved, as `BlockGetter` shouldn't have any finality margin configured,
  i.e. it should be prepared to be served events from zero-confirmation Ethereum blocks from the `OMG.RootChainCoordinator`
  """

  alias OMG.Eth
  alias OMG.RootChainCoordinator
  alias OMG.RootChainCoordinator.SyncGuide
  alias OMG.State
  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.Watcher.BlockGetter.Core
  alias OMG.Watcher.BlockGetter.Status
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.HttpRPC.Client

  use GenServer
  use OMG.Utils.LoggerExt
  use Spandex.Decorators

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Retrieves the freshest information about `OMG.Watcher.BlockGetter`'s status, as stored by the slave process `Status`
  """
  @spec get_events() :: {:ok, Core.chain_ok_response_t()}
  def get_events, do: __MODULE__.Status.get_events()

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

    # how many eth blocks backward can change during an reorg
    block_getter_reorg_margin = Application.fetch_env!(:omg_watcher, :block_getter_reorg_margin)

    maximum_block_withholding_time_ms = Application.fetch_env!(:omg_watcher, :maximum_block_withholding_time_ms)

    maximum_number_of_unapplied_blocks = Application.fetch_env!(:omg_watcher, :maximum_number_of_unapplied_blocks)

    # TODO rethink posible solutions see issue #724
    # if we do not wait here, `ExitProcessor.check_validity()` may timeouts,
    # which causes State and BlockGetter to reboot, fetches entire UTXO set again, and then timeout...
    _ = :sys.get_status(ExitProcessor, 10 * 60_000)
    exit_processor_initial_results = ExitProcessor.check_validity()

    {:ok, state} =
      Core.init(
        child_top_block_number,
        child_block_interval,
        synced_height,
        block_getter_reorg_margin,
        state_at_block_beginning,
        exit_processor_initial_results,
        maximum_block_withholding_time_ms: maximum_block_withholding_time_ms,
        maximum_number_of_unapplied_blocks: maximum_number_of_unapplied_blocks,
        # NOTE: not elegant, but this should limit the number of heavy-lifting workers and chance to starve the rest
        maximum_number_of_pending_blocks: System.schedulers()
      )

    :ok = check_in_to_coordinator(synced_height)
    {:ok, _} = schedule_sync_height()
    {:ok, _} = schedule_producer()

    {:ok, _} = __MODULE__.Status.start_link()
    :ok = update_status(state)

    {:ok, _} =
      :timer.send_interval(
        Application.fetch_env!(:omg_watcher, :metrics_collection_interval),
        self(),
        :send_metrics
      )

    _ = Logger.info("Started #{inspect(__MODULE__)}, synced_height: #{inspect(synced_height)}")

    {:noreply, state}
  end

  def handle_continue({:apply_block_step, :execute_transactions, block_application}, state) do
    tx_exec_results = for(tx <- block_application.transactions, do: OMG.State.exec(tx, :no_fees_required))

    case Core.validate_executions(tx_exec_results, block_application, state) do
      {:ok, state} ->
        :ok = OMG.Bus.direct_local_broadcast("block.get", {:block_received, block_application})

        {:noreply, state, {:continue, {:apply_block_step, :run_block_download_task, block_application}}}

      {{:error, _} = error, new_state} ->
        :ok = update_status(new_state)
        _ = Logger.error("Invalid block #{inspect(block_application.number)}, because of #{inspect(error)}")
        {:noreply, new_state}
    end
  end

  def handle_continue({:apply_block_step, :run_block_download_task, block_application}, state),
    do:
      {:noreply, run_block_download_task(state),
       {:continue, {:apply_block_step, :close_and_apply_block, block_application}}}

  def handle_continue({:apply_block_step, :close_and_apply_block, block_application}, state) do
    {:ok, db_updates_from_state} = OMG.State.close_block()

    {state, synced_height, db_updates} = Core.apply_block(state, block_application)

    _ = Logger.debug("Synced height update: #{inspect(db_updates)}")

    :ok = OMG.DB.multi_update(db_updates ++ db_updates_from_state)
    :ok = check_in_to_coordinator(synced_height)

    _ =
      Logger.info(
        "Applied block: \##{inspect(block_application.number)}, from eth height: #{
          inspect(block_application.eth_height)
        } " <>
          "with #{inspect(length(block_application.transactions))} txs"
      )

    {:noreply, state, {:continue, {:apply_block_step, :check_validity}}}
  end

  def handle_continue({:apply_block_step, :check_validity}, state) do
    exit_processor_results = ExitProcessor.check_validity()
    state = Core.consider_exits(state, exit_processor_results)
    :ok = update_status(state)
    {:noreply, state}
  end

  def handle_cast({:apply_block, %BlockApplication{} = block_application}, state) do
    case Core.chain_ok(state) do
      {:ok, _} ->
        {:noreply, state, {:continue, {:apply_block_step, :execute_transactions, block_application}}}

      error ->
        :ok = update_status(state)

        _ =
          Logger.warn(
            "Chain already invalid before applying block #{inspect(block_application.number)} because of #{
              inspect(error)
            }"
          )

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

  def handle_info(:producer, state), do: do_producer(state)
  def handle_info({_ref, {:downloaded_block, response}}, state), do: do_downloaded_block(response, state)
  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state), do: {:noreply, state}
  def handle_info(:sync, state), do: do_sync(state)

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  defp do_producer(state) do
    with {:ok, _} <- Core.chain_ok(state) do
      new_state = run_block_download_task(state)
      {:ok, _} = schedule_producer()
      :ok = update_status(new_state)
      {:noreply, new_state}
    else
      {:error, _} = error ->
        :ok = update_status(state)
        _ = Logger.warn("Chain invalid when trying to download blocks, because of #{inspect(error)}, won't try again")
        {:noreply, state}
    end
  end

  defp do_downloaded_block(response, state) do
    # 1/ process the block that arrived and consume

    with {:ok, state} <- Core.handle_downloaded_block(state, response) do
      state = run_block_download_task(state)
      :ok = update_status(state)
      {:noreply, state}
    else
      {{:error, _} = error, state} ->
        :ok = update_status(state)
        _ = Logger.error("Error while handling downloaded block because of #{inspect(error)}")
        {:noreply, state}
    end
  end

  defp do_sync(state) do
    with {:ok, _} <- Core.chain_ok(state),
         %SyncGuide{sync_height: next_synced_height} <- RootChainCoordinator.get_sync_info() do
      block_range = Core.get_eth_range_for_block_submitted_events(state, next_synced_height)

      {:ok, submissions} = get_block_submitted_events(block_range)

      {blocks_to_apply, synced_height, db_updates, state} =
        Core.get_blocks_to_apply(state, submissions, next_synced_height)

      _ = Logger.debug("Synced height is #{inspect(synced_height)}, got #{length(blocks_to_apply)} blocks to apply")

      Enum.each(blocks_to_apply, &GenServer.cast(__MODULE__, {:apply_block, &1}))

      :ok = OMG.DB.multi_update(db_updates)
      :ok = check_in_to_coordinator(synced_height)
      {:ok, _} = schedule_sync_height()
      :ok = update_status(state)

      {:noreply, state}
    else
      :nosync ->
        :ok = check_in_to_coordinator(state.synced_height)
        :ok = update_status(state)
        {:ok, _} = schedule_sync_height()
        {:noreply, state}

      {:error, _} = error ->
        :ok = update_status(state)
        _ = Logger.warn("Chain invalid when trying to sync, because of #{inspect(error)}, won't try again")
        {:noreply, state}
    end
  end

  @decorate trace(tracer: OMG.Watcher.Tracer, type: :backend, service: :block_getter)
  defp get_block_submitted_events(block_range), do: Eth.RootChain.get_block_submitted_events(block_range)

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
    child_chain_url = Application.get_env(:omg_watcher, :child_chain_url)
    response = Client.get_block(requested_hash, child_chain_url)

    Core.validate_download_response(
      response,
      requested_hash,
      requested_number,
      block_timestamp,
      :os.system_time(:millisecond)
    )
  end

  defp check_in_to_coordinator(synced_height), do: RootChainCoordinator.check_in(synced_height, :block_getter)

  defp update_status(%Core{} = state), do: Status.update(Core.chain_ok(state))
end
