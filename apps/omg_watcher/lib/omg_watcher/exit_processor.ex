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

defmodule OMG.Watcher.ExitProcessor do
  @moduledoc """
  Tracks and handles the exits from the child chain, their validity and challenges.

  Keeps a state of exits that are in progress, updates it with news from the root chain contract, compares to the
  state of the ledger (`OMG.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.

  For functional logic and more info see `OMG.Watcher.ExitProcessor.Core`

  NOTE: Note that all calls return `db_updates` and relay on the caller to do persistence.
  """

  alias OMG.Block
  alias OMG.DB
  alias OMG.DB.Models.PaymentExitInfo
  alias OMG.Eth
  alias OMG.Eth.EthereumHeight
  alias OMG.Eth.RootChain
  alias OMG.State
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.Tools

  use OMG.Utils.LoggerExt
  require Utxo

  ### Client

  @doc """
  Starts the `GenServer` process with options. For documentation of the options see `init/1`
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.drop(args, [:name]), name: args[:name])
  end

  ### Server

  use GenServer

  @doc """
  Initializes the state of the `ExitProcessor`'s `GenServer`.

  Reads the exit data from `OMG.DB`.

  Options:
    - `exit_processor_sla_margin`: number of blocks after exit start before it's considered late (and potentially:
      unchallenged)
    - `exit_processor_sla_margin_forced`: if `true` will override the check of `exit_processor_sla_margin` against
      `min_exit_period_seconds`
    - `min_exit_period_seconds`: should reflect the value of this parameter for the specific child chain watched,
    - `ethereum_block_time_seconds`: just to relate blocks to seconds for the `exit_processor_sla_margin` check
    - `metrics_collection_interval`: how often are the metrics sent to `telemetry` (in milliseconds)
  """
  def init(
        exit_processor_sla_margin: exit_processor_sla_margin,
        exit_processor_sla_margin_forced: exit_processor_sla_margin_forced,
        metrics_collection_interval: metrics_collection_interval,
        min_exit_period_seconds: min_exit_period_seconds,
        ethereum_block_time_seconds: ethereum_block_time_seconds,
        child_block_interval: child_block_interval
      ) do
    # TODO: only load relevant exits based on type
    # payment v1 should load records that don't have
    # the namespace as well (old records)
    {:ok, db_exits} = PaymentExitInfo.all_exit_infos()
    {:ok, db_ifes} = PaymentExitInfo.all_in_flight_exits_infos()
    {:ok, db_competitors} = DB.competitors_info()

    :ok =
      Core.check_sla_margin(
        exit_processor_sla_margin,
        exit_processor_sla_margin_forced,
        min_exit_period_seconds,
        ethereum_block_time_seconds
      )

    {:ok, processor} =
      Core.init(
        db_exits,
        db_ifes,
        db_competitors,
        min_exit_period_seconds,
        child_block_interval,
        exit_processor_sla_margin
      )

    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    _ = Logger.info("Initializing with: #{inspect(processor)}")
    {:ok, processor}
  end

  @doc """
  See `new_exits/1`. Flow:

  - takes a list of standard exit start events from the contract
  - fetches the currently observed exit status in the contract (to decide if exits are "inactive on recognition", which
    helps cover the case when the Watcher is syncing up)
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """
  def handle_call({:new_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized #{Enum.count(exits)} exits: #{inspect(exits)}")

    {:ok, exit_contract_statuses} = Eth.RootChain.get_standard_exit_structs(get_in(exits, [Access.all(), :exit_id]))

    exit_maps =
      exits
      |> Task.async_stream(
        fn exit_event ->
          put_timestamp_and_sft(exit_event, state.min_exit_period_seconds, state.child_block_interval)
        end,
        timeout: 50_000,
        on_timeout: :exit,
        max_concurrency: System.schedulers_online() * 2
      )
      |> Enum.map(fn {:ok, result} -> result end)

    {new_state, db_updates} = Core.new_exits(state, exit_maps, exit_contract_statuses)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `new_in_flight_exits/1`. Flow:

  - takes a list of IFE exit start events from the contract
  - fetches the currently observed exit status in the contract (to decide if exits are "inactive on recognition", which
    helps cover the case when the Watcher is syncing up)
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """
  def handle_call({:new_in_flight_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized #{Enum.count(exits)} in-flight exits: #{inspect(exits)}")

    contract_ife_ids =
      Enum.map(exits, fn %{call_data: %{in_flight_tx: txbytes}} ->
        ExPlasma.InFlightExit.txbytes_to_id(txbytes)
      end)

    # Prepare events data for internal bus
    :ok =
      exits
      |> Enum.map(fn %{call_data: %{input_utxos_pos: inputs}} = event ->
        {event, inputs}
      end)
      |> Tools.to_bus_events_data()
      |> publish_internal_bus_events("InFlightExitStarted")

    {:ok, statuses} = Eth.RootChain.get_in_flight_exit_structs(contract_ife_ids)
    ife_contract_statuses = Enum.zip(statuses, contract_ife_ids)
    {new_state, db_updates} = Core.new_in_flight_exits(state, exits, ife_contract_statuses)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `finalize_exits/1`. Flow:

  - takes a list of standard exit finalization events from the contract
  - discovers the `OMG.State`'s native key for the finalizing exits (`utxo_pos`) (`Core.exit_key_by_exit_id/2`)
  - marks as spent these UTXOs in `OMG.State` expecting it to tell which of those were valid finalizations (UTXOs exist)
  - reflects this result in the `ExitProcessor`'s state
  - returns `db_updates`, concatenated with those related to the call to `OMG.State`
  """
  def handle_call({:finalize_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized #{Enum.count(exits)} finalizations: #{inspect(exits)}")

    {:ok, db_updates_from_state, validities} =
      exits |> Enum.map(&Core.exit_key_by_exit_id(state, &1.exit_id)) |> State.exit_utxos()

    {new_state, db_updates} = Core.finalize_exits(state, validities)

    {:reply, {:ok, db_updates ++ db_updates_from_state}, new_state}
  end

  @doc """
  See `piggyback_exits/1`. Flow:

  - takes a list of IFE piggybacking events from the contract
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """
  def handle_call({:piggyback_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized #{Enum.count(exits)} piggybacks: #{inspect(exits)}")
    {new_state, db_updates} = Core.new_piggybacks(state, exits)

    :ok =
      exits
      |> Tools.to_bus_events_data()
      |> publish_internal_bus_events("InFlightTxOutputPiggybacked")

    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `challenge_exits/1`. Flow:

  - takes a list of standard exit challenge events from the contract
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """
  def handle_call({:challenge_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized #{Enum.count(exits)} challenges: #{inspect(exits)}")
    {new_state, db_updates} = Core.challenge_exits(state, exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `new_ife_challenges/1`. Flow:

  - takes a list of IFE exit canonicity challenge events from the contract
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """
  def handle_call({:new_ife_challenges, challenges}, _from, state) do
    _ =
      if not Enum.empty?(challenges),
        do: Logger.info("Recognized #{Enum.count(challenges)} ife challenges: #{inspect(challenges)}")

    {new_state, db_updates} = Core.new_ife_challenges(state, challenges)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `challenge_piggybacks/1`. Flow:

  - takes a list of IFE piggyback challenge events from the contract
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """

  def handle_call({:challenge_piggybacks, challenges}, _from, state) do
    _ =
      if not Enum.empty?(challenges),
        do: Logger.info("Recognized #{Enum.count(challenges)} piggyback challenges: #{inspect(challenges)}")

    {new_state, db_updates} = Core.challenge_piggybacks(state, challenges)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `respond_to_in_flight_exits_challenges/1`. Flow:

  - takes a list of IFE exit canonicity challenge response events from the contract
  - updates the `ExitProcessor`'s state
  - returns `db_updates`
  """
  def handle_call({:respond_to_in_flight_exits_challenges, responds}, _from, state) do
    _ =
      if not Enum.empty?(responds),
        do: Logger.info("Recognized #{Enum.count(responds)} response to IFE challenge: #{inspect(responds)}")

    {new_state, db_updates} = Core.respond_to_in_flight_exits_challenges(state, responds)
    {:reply, {:ok, db_updates}, new_state}
  end

  @doc """
  See `finalize_in_flight_exits/1`. Flow:

  - takes a list of IFE exit finalization events from the contract
  - pulls current information on IFE transaction inclusion
  - discovers the `OMG.State`'s native key for the finalizing exits (`utxo_pos`)
    (`Core.prepare_utxo_exits_for_in_flight_exit_finalizations/2`)
  - marks as spent these UTXOs in `OMG.State` expecting it to tell which of those were valid finalizations (UTXOs exist)
  - reflects this result in the `ExitProcessor`'s state
  - returns `db_updates`, concatenated with those related to the call to `OMG.State`
  """

  def handle_call({:finalize_in_flight_exits, finalizations}, _from, state) do
    _ = Logger.info("Recognized #{Enum.count(finalizations)} ife finalizations: #{inspect(finalizations)}")

    # necessary, so that the processor knows the current state of inclusion of exiting IFE txs
    state2 = update_with_ife_txs_from_blocks(state)

    {:ok, exiting_positions, events_with_utxos} =
      Core.prepare_utxo_exits_for_in_flight_exit_finalizations(state2, finalizations)

    # NOTE: it's not straightforward to track from utxo position returned when exiting utxo in State to ife id
    # See issue #671 https://github.com/omisego/elixir-omg/issues/671
    {invalidities, state_db_updates} =
      Enum.reduce(exiting_positions, {%{}, []}, &collect_invalidities_and_state_db_updates/2)

    {:ok, state3, db_updates} = Core.finalize_in_flight_exits(state2, finalizations, invalidities)

    :ok =
      events_with_utxos
      |> Tools.to_bus_events_data()
      |> publish_internal_bus_events("InFlightExitOutputWithdrawn")

    {:reply, {:ok, state_db_updates ++ db_updates}, state3}
  end

  @doc """
  See `check_validity/0`. Flow:

  - pulls current information on IFE transaction inclusion
  - gets a list of interesting UTXOs to check for existence in `OMG.State`
  - combines this information to discover the state of all the exits to report (mainly byzantine events)
  """
  def handle_call(:check_validity, _from, state) do
    new_state = update_with_ife_txs_from_blocks(state)

    response =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(new_state)
      |> Core.check_validity(new_state)

    {:reply, response, new_state}
  end

  @doc """
  See `get_active_in_flight_exits/0`.
  """
  def handle_call(:get_active_in_flight_exits, _from, state) do
    {:reply, {:ok, Core.get_active_in_flight_exits(state)}, state}
  end

  @doc """
  See `get_competitor_for_ife/1`. Flow:

  - pulls current information on IFE transaction inclusion
  - gets a list of interesting UTXOs to check for existence in `OMG.State`
  - combines this information to compose the challenge data
  """
  def handle_call({:get_competitor_for_ife, txbytes}, _from, state) do
    # TODO: run_status_gets and getting all non-existent UTXO positions imaginable can be optimized out heavily
    #       only the UTXO positions being inputs to `txbytes` must be looked at, but it becomes problematic as
    #       txbytes can be invalid so we'd need a with here...
    new_state = update_with_ife_txs_from_blocks(state)

    competitor_result =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(new_state)
      |> Core.get_competitor_for_ife(new_state, txbytes)

    {:reply, competitor_result, new_state}
  end

  @doc """
  See `prove_canonical_for_ife/1`. Flow:

  - pulls current information on IFE transaction inclusion
  - gets a list of interesting UTXOs to check for existence in `OMG.State`
  - combines this information to compose the challenge data
  """
  def handle_call({:prove_canonical_for_ife, txbytes}, _from, state) do
    new_state = update_with_ife_txs_from_blocks(state)
    canonicity_result = Core.prove_canonical_for_ife(new_state, txbytes)

    {:reply, canonicity_result, new_state}
  end

  @doc """
  See `get_input_challenge_data/2`. Flow:

  - gets a list of interesting UTXOs to check for existence in `OMG.State`
  - combines this information to compose the challenge data
  """
  def handle_call({:get_input_challenge_data, txbytes, input_index}, _from, state) do
    response =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(state)
      |> Core.get_input_challenge_data(state, txbytes, input_index)

    {:reply, response, state}
  end

  @doc """
  See `get_output_challenge_data/2`. Flow:

  - pulls current information on IFE transaction inclusion
  - gets a list of interesting UTXOs to check for existence in `OMG.State`
  - combines this information to compose the challenge data
  """
  def handle_call({:get_output_challenge_data, txbytes, output_index}, _from, state) do
    new_state = update_with_ife_txs_from_blocks(state)

    response =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(new_state)
      |> Core.get_output_challenge_data(new_state, txbytes, output_index)

    {:reply, response, new_state}
  end

  @doc """
  See `create_challenge/1`. Flow:

  - leverages `OMG.State` to quickly learn if the exiting UTXO exists or was spent
  - pulls some additional data from `OMG.DB`, if needed
  - combines this information to compose the challenge data
  """
  def handle_call({:create_challenge, exiting_utxo_pos}, _from, state) do
    request = %ExitProcessor.Request{se_exiting_pos: exiting_utxo_pos}
    exiting_utxo_exists = State.utxo_exists?(exiting_utxo_pos)

    response =
      with {:ok, request} <- Core.determine_standard_challenge_queries(request, state, exiting_utxo_exists),
           do:
             request
             |> fill_request_with_standard_challenge_data()
             |> Core.create_challenge(state)

    {:reply, response, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  defp fill_request_with_standard_challenge_data(%ExitProcessor.Request{se_spending_blocks_to_get: positions} = request) do
    %ExitProcessor.Request{request | se_spending_blocks_result: do_get_spending_blocks(positions)}
  end

  # based on the exits being processed, fills the request structure with data required to process queries
  @spec fill_request_with_spending_data(ExitProcessor.Request.t(), Core.t()) :: ExitProcessor.Request.t()
  defp fill_request_with_spending_data(request, state) do
    request
    |> run_status_gets()
    |> Core.determine_utxo_existence_to_get(state)
    |> get_utxo_existence()
    |> Core.determine_spends_to_get(state)
    |> get_spending_blocks()
  end

  # based on in-flight exiting transactions, updates the state with witnesses of those transactions' inclusions in block
  @spec update_with_ife_txs_from_blocks(Core.t()) :: Core.t()
  defp update_with_ife_txs_from_blocks(state) do
    prepared_request =
      %ExitProcessor.Request{}
      |> run_status_gets()
      # To find if IFE was included, see first if its inputs were spent.
      |> Core.determine_ife_input_utxos_existence_to_get(state)
      |> get_ife_input_utxo_existence()
      # Next, check by what transactions they were spent.
      |> Core.determine_ife_spends_to_get(state)
      |> get_ife_input_spending_blocks()

    # Compare found txes with ife.tx.
    # If equal, persist information about position.
    Core.find_ifes_in_blocks(state, prepared_request)
  end

  defp run_status_gets(%ExitProcessor.Request{eth_height_now: nil, blknum_now: nil} = request) do
    {:ok, eth_height_now} = EthereumHeight.get()
    {blknum_now, _} = State.get_status()

    _ = Logger.debug("eth_height_now: #{inspect(eth_height_now)}, blknum_now: #{inspect(blknum_now)}")
    %{request | eth_height_now: eth_height_now, blknum_now: blknum_now}
  end

  defp get_utxo_existence(%ExitProcessor.Request{utxos_to_check: positions} = request),
    do: %{request | utxo_exists_result: do_utxo_exists?(positions)}

  defp get_ife_input_utxo_existence(%ExitProcessor.Request{ife_input_utxos_to_check: positions} = request),
    do: %{request | ife_input_utxo_exists_result: do_utxo_exists?(positions)}

  defp do_utxo_exists?(positions) do
    result = Enum.map(positions, &State.utxo_exists?/1)
    _ = Logger.debug("utxos_to_check: #{inspect(positions)}, utxo_exists_result: #{inspect(result)}")
    result
  end

  defp get_spending_blocks(%ExitProcessor.Request{spends_to_get: positions} = request) do
    %{request | blocks_result: do_get_spending_blocks(positions)}
  end

  defp get_ife_input_spending_blocks(%ExitProcessor.Request{ife_input_spends_to_get: positions} = request) do
    %{request | ife_input_spending_blocks_result: do_get_spending_blocks(positions)}
  end

  defp do_get_spending_blocks(spent_positions_to_get) do
    blknums = Enum.map(spent_positions_to_get, &do_get_spent_blknum/1)
    _ = Logger.debug("spends_to_get: #{inspect(spent_positions_to_get)}, spent_blknum_result: #{inspect(blknums)}")

    blknums
    |> Core.handle_spent_blknum_result(spent_positions_to_get)
    |> do_get_blocks()
  end

  defp do_get_blocks(blknums) do
    {:ok, hashes} = OMG.DB.block_hashes(blknums)
    _ = Logger.debug("blknums: #{inspect(blknums)}, hashes: #{inspect(hashes)}")
    {:ok, blocks} = OMG.DB.blocks(hashes)
    _ = Logger.debug("blocks_result: #{inspect(blocks)}")

    Enum.map(blocks, &Block.from_db_value/1)
  end

  defp do_get_spent_blknum(position) do
    position |> Utxo.Position.to_input_db_key() |> OMG.DB.spent_blknum()
  end

  defp collect_invalidities_and_state_db_updates(
         {ife_id, exiting_positions},
         {invalidities_by_ife_id, state_db_updates}
       ) do
    {:ok, exits_state_updates, {_, invalidities}} = State.exit_utxos(exiting_positions)

    _ =
      if not Enum.empty?(invalidities), do: Logger.warn("Invalid in-flight exit finalization: #{inspect(invalidities)}")

    invalidities_by_ife_id = Map.put(invalidities_by_ife_id, ife_id, invalidities)
    state_db_updates = exits_state_updates ++ state_db_updates

    {invalidities_by_ife_id, state_db_updates}
  end

  @spec put_timestamp_and_sft(map(), pos_integer(), pos_integer()) :: map()
  defp put_timestamp_and_sft(
         %{eth_height: eth_height, call_data: %{utxo_pos: utxo_pos_enc}} = exit_event,
         min_exit_period_seconds,
         child_block_interval
       ) do
    {:utxo_position, blknum, _, _} = Utxo.Position.decode!(utxo_pos_enc)
    {_block_hash, utxo_creation_block_timestamp} = RootChain.blocks(blknum)
    {:ok, exit_block_timestamp} = Eth.get_block_timestamp_by_number(eth_height)

    {:ok, scheduled_finalization_time} =
      ExitInfo.calculate_sft(
        blknum,
        exit_block_timestamp,
        utxo_creation_block_timestamp,
        min_exit_period_seconds,
        child_block_interval
      )

    exit_event
    |> Map.put(:scheduled_finalization_time, scheduled_finalization_time)
    |> Map.put(:block_timestamp, exit_block_timestamp)
  end

  defp publish_internal_bus_events([], _), do: :ok

  defp publish_internal_bus_events(events_data, topic) when is_list(events_data) and is_binary(topic) do
    {:watcher, topic}
    |> OMG.Bus.Event.new(:data, events_data)
    |> OMG.Bus.direct_local_broadcast()
  end
end
