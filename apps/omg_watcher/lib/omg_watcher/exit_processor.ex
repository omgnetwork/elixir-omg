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

defmodule OMG.Watcher.ExitProcessor do
  @moduledoc """
  Imperative shell here, for functional core and more info see `OMG.Watcher.ExitProcessor.Core`

  NOTE: Note that all calls return `db_updates` and relay on the caller to do persistence.
  """

  alias OMG.Block
  alias OMG.DB
  alias OMG.Eth
  alias OMG.State
  alias OMG.State.Transaction
  alias OMG.Utxo
  # NOTE: future of using `ExitProcessor.Request` struct not certain, see that module for details
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.StandardExitChallenge
  alias OMG.Watcher.Recorder

  use OMG.Utils.Metrics
  use OMG.Utils.LoggerExt
  require Utxo

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Accepts events and processes them in the state - new exits are tracked.
  Returns `db_updates`
  """
  @decorate measure_event()
  def new_exits(exits) do
    GenServer.call(__MODULE__, {:new_exits, exits})
  end

  @doc """
  Accepts events and processes them in the state - new in flight exits are tracked.
  Returns `db_updates`
  """
  @decorate measure_event()
  def new_in_flight_exits(in_flight_exit_started_events) do
    GenServer.call(__MODULE__, {:new_in_flight_exits, in_flight_exit_started_events})
  end

  @doc """
  Accepts events and processes them in the state - finalized exits are untracked _if valid_ otherwise raises alert
  Returns `db_updates`
  """
  @decorate measure_event()
  def finalize_exits(finalizations) do
    GenServer.call(__MODULE__, {:finalize_exits, finalizations})
  end

  @doc """
  Accepts events and processes them in the state - new piggybacks are tracked, if invalid raises an alert
  Returns `db_updates`
  """
  @decorate measure_event()
  def piggyback_exits(piggybacks) do
    GenServer.call(__MODULE__, {:piggyback_exits, piggybacks})
  end

  @doc """
  Accepts events and processes them in the state - challenged exits are untracked
  Returns `db_updates`
  """
  @decorate measure_event()
  def challenge_exits(challenges) do
    GenServer.call(__MODULE__, {:challenge_exits, challenges})
  end

  @doc """
  Accepts events and processes them in the state.
  Competitors are stored for future use(i.e. to challenge an in flight exit).
  Returns `db_updates`
  """
  @decorate measure_event()
  def new_ife_challenges(challenges) do
    GenServer.call(__MODULE__, {:new_ife_challenges, challenges})
  end

  @doc """
  Accepts events and processes them in state.
  Returns `db_updates`
  """
  @decorate measure_event()
  def respond_to_in_flight_exits_challenges(responds) do
    GenServer.call(__MODULE__, {:respond_to_in_flight_exits_challenges, responds})
  end

  @doc """
  Accepts events and processes them in state.
  Challenged piggybacks are forgotten.
  Returns `db_updates`
  """
  @decorate measure_event()
  def challenge_piggybacks(challenges) do
    GenServer.call(__MODULE__, {:challenge_piggybacks, challenges})
  end

  @doc """
    Accepts events and processes them in state - finalized outputs are applied to the state.
    Returns `db_updates`
  """
  @decorate measure_event()
  def finalize_in_flight_exits(finalizations) do
    GenServer.call(__MODULE__, {:finalize_in_flight_exits, finalizations})
  end

  @doc """
  Checks validity of all exit-related events and returns the list of actionable items.
  Works with `OMG.State` to discern validity.

  This function may also update some internal caches to make subsequent calls not redo the work,
  but under unchanged conditions, it should have unchanged behavior from POV of an outside caller.
  """
  @decorate measure_event()
  def check_validity do
    GenServer.call(__MODULE__, :check_validity)
  end

  @doc """
  Returns a map of requested in flight exits, keyed by transaction hash
  """
  @decorate measure_event()
  @spec get_active_in_flight_exits() :: {:ok, Core.in_flight_exits_response_t()}
  def get_active_in_flight_exits do
    GenServer.call(__MODULE__, :get_active_in_flight_exits)
  end

  @doc """
  Returns all information required to produce a transaction to the root chain contract to present a competitor for
  a non-canonical in-flight exit
  """
  @decorate measure_event()
  @spec get_competitor_for_ife(binary()) :: {:ok, Core.competitor_data_t()} | {:error, :competitor_not_found}
  def get_competitor_for_ife(txbytes) do
    GenServer.call(__MODULE__, {:get_competitor_for_ife, txbytes})
  end

  @doc """
  Returns all information required to produce a transaction to the root chain contract to present a proof of canonicity
  for a challenged in-flight exit
  """
  @decorate measure_event()
  @spec prove_canonical_for_ife(binary()) :: {:ok, Core.prove_canonical_data_t()} | {:error, :canonical_not_found}
  def prove_canonical_for_ife(txbytes) do
    GenServer.call(__MODULE__, {:prove_canonical_for_ife, txbytes})
  end

  @decorate measure_event()
  @spec get_input_challenge_data(Transaction.Signed.tx_bytes(), Transaction.input_index_t()) ::
          {:ok, Core.input_challenge_data()} | {:error, Core.piggyback_challenge_data_error()}
  def get_input_challenge_data(txbytes, input_index) do
    GenServer.call(__MODULE__, {:get_input_challenge_data, txbytes, input_index})
  end

  @decorate measure_event()
  @spec get_output_challenge_data(Transaction.Signed.tx_bytes(), Transaction.input_index_t()) ::
          {:ok, Core.output_challenge_data()} | {:error, Core.piggyback_challenge_data_error()}
  def get_output_challenge_data(txbytes, output_index) do
    GenServer.call(__MODULE__, {:get_output_challenge_data, txbytes, output_index})
  end

  @doc """
  Returns challenge for an exit
  """
  @decorate measure_event()
  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, StandardExitChallenge.t()} | {:error, :utxo_not_spent | :exit_not_found}
  def create_challenge(exiting_utxo_pos) do
    GenServer.call(__MODULE__, {:create_challenge, exiting_utxo_pos})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, db_exits} = DB.exit_infos()
    {:ok, db_ifes} = DB.in_flight_exits_info()
    {:ok, db_competitors} = DB.competitors_info()

    sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)

    processor = Core.init(db_exits, db_ifes, db_competitors, sla_margin)

    {:ok, _} = Recorder.start_link(%Recorder{name: __MODULE__.Recorder, parent: self()})

    _ = Logger.info("Initializing with: #{inspect(processor)}")
    processor
  end

  def handle_call({:new_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized exits: #{inspect(exits)}")

    exit_contract_statuses =
      Enum.map(exits, fn %{exit_id: exit_id} ->
        {:ok, result} = Eth.RootChain.get_standard_exit(exit_id)
        result
      end)

    {new_state, db_updates} = Core.new_exits(state, exits, exit_contract_statuses)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:new_in_flight_exits, events}, _from, state) do
    _ = if not Enum.empty?(events), do: Logger.info("Recognized in-flight exits: #{inspect(events)}")

    ife_contract_statuses =
      Enum.map(
        events,
        fn %{call_data: %{in_flight_tx: bytes}} ->
          {:ok, contract_ife_id} = Eth.RootChain.get_in_flight_exit_id(bytes)
          {:ok, {timestamp, _, _, _, _}} = Eth.RootChain.get_in_flight_exit(contract_ife_id)
          {timestamp, contract_ife_id}
        end
      )

    {new_state, db_updates} = Core.new_in_flight_exits(state, events, ife_contract_statuses)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:finalize_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized finalizations: #{inspect(exits)}")

    exits =
      exits
      |> Enum.map(fn %{exit_id: exit_id} ->
        {:ok, {_, _, _, utxo_pos}} = Eth.RootChain.get_standard_exit(exit_id)
        Utxo.Position.decode!(utxo_pos)
      end)

    {:ok, db_updates_from_state, validities} = State.exit_utxos(exits)
    {new_state, event_triggers, db_updates} = Core.finalize_exits(state, validities)

    :ok = OMG.InternalEventBus.broadcast("events", {:emit_events, event_triggers})

    {:reply, {:ok, db_updates ++ db_updates_from_state}, new_state}
  end

  def handle_call({:piggyback_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized piggybacks: #{inspect(exits)}")
    {new_state, db_updates} = Core.new_piggybacks(state, exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:challenge_exits, exits}, _from, state) do
    _ = if not Enum.empty?(exits), do: Logger.info("Recognized challenges: #{inspect(exits)}")
    {new_state, db_updates} = Core.challenge_exits(state, exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:new_ife_challenges, challenges}, _from, state) do
    _ = if not Enum.empty?(challenges), do: Logger.info("Recognized ife challenges: #{inspect(challenges)}")
    {new_state, db_updates} = Core.new_ife_challenges(state, challenges)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:challenge_piggybacks, challenges}, _from, state) do
    _ = if not Enum.empty?(challenges), do: Logger.info("Recognized piggyback challenges: #{inspect(challenges)}")
    {new_state, db_updates} = Core.challenge_piggybacks(state, challenges)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:respond_to_in_flight_exits_challenges, responds}, _from, state) do
    _ = if not Enum.empty?(responds), do: Logger.info("Recognized response to IFE challenge: #{inspect(responds)}")
    {new_state, db_updates} = Core.respond_to_in_flight_exits_challenges(state, responds)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:finalize_in_flight_exits, finalizations}, _from, state) do
    _ = if not Enum.empty?(finalizations), do: Logger.info("Recognized ife finalizations: #{inspect(finalizations)}")

    {:ok, exits} = Core.prepare_utxo_exits_for_in_flight_exit_finalizations(state, finalizations)

    # NOTE: it's not straightforward to track from utxo position returned when exiting utxo in State to ife id
    # See issue #671 https://github.com/omisego/elixir-omg/issues/671
    {invalidities, state_db_updates} = Enum.reduce(exits, {%{}, []}, &collect_invalidities_and_state_db_updates/2)

    {:ok, state, db_updates} = Core.finalize_in_flight_exits(state, finalizations, invalidities)

    {:reply, {:ok, state_db_updates ++ db_updates}, state}
  end

  def handle_call(:check_validity, _from, state) do
    new_state = update_with_ife_txs_from_blocks(state)

    response =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(new_state)
      |> Core.check_validity(new_state)

    {:reply, response, new_state}
  end

  def handle_call(:get_active_in_flight_exits, _from, state),
    do: {:reply, {:ok, Core.get_active_in_flight_exits(state)}, state}

  def handle_call({:get_competitor_for_ife, txbytes}, _from, state) do
    # TODO: run_status_gets and getting all non-existent UTXO positions imaginable can be optimized out heavily
    #       only the UTXO positions being inputs to `txbytes` must be looked at, but it becomes problematic as
    #       txbytes can be invalid so we'd need a with here...
    competitor_result =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(state)
      |> Core.get_competitor_for_ife(state, txbytes)

    {:reply, competitor_result, state}
  end

  def handle_call({:prove_canonical_for_ife, txbytes}, _from, state) do
    # TODO: same comment as above in get_competitor_for_ife
    canonicity_result =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(state)
      |> Core.prove_canonical_for_ife(txbytes)

    {:reply, canonicity_result, state}
  end

  def handle_call({:get_input_challenge_data, txbytes, input_index}, _from, state) do
    response =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(state)
      |> Core.get_input_challenge_data(state, txbytes, input_index)

    {:reply, response, state}
  end

  def handle_call({:get_output_challenge_data, txbytes, output_index}, _from, state) do
    new_state = update_with_ife_txs_from_blocks(state)

    response =
      %ExitProcessor.Request{}
      |> fill_request_with_spending_data(new_state)
      |> Core.get_output_challenge_data(new_state, txbytes, output_index)

    {:reply, response, new_state}
  end

  def handle_call({:create_challenge, exiting_utxo_pos}, _from, state) do
    request = %ExitProcessor.Request{se_exiting_pos: exiting_utxo_pos}

    response =
      with {:ok, request_with_queries} <- Core.determine_standard_challenge_queries(request, state),
           do:
             request_with_queries
             |> fill_request_with_standard_challenge_data()
             |> Core.determine_exit_txbytes(state)
             |> fill_request_with_standard_exit_id()
             |> Core.create_challenge(state)

    {:reply, response, state}
  end

  defp fill_request_with_standard_challenge_data(
         %ExitProcessor.Request{se_spending_blocks_to_get: positions, se_creating_blocks_to_get: blknums} = request
       ) do
    %ExitProcessor.Request{
      request
      | se_spending_blocks_result: do_get_spending_blocks(positions),
        se_creating_blocks_result: do_get_blocks(blknums)
    }
  end

  defp fill_request_with_standard_exit_id(
         %ExitProcessor.Request{se_exit_id_to_get: creating_txbytes, se_exiting_pos: utxo_pos} = request
       ) do
    {:ok, exit_id} = OMG.Eth.RootChain.get_standard_exit_id(creating_txbytes, Utxo.Position.encode(utxo_pos))
    %ExitProcessor.Request{request | se_exit_id_result: exit_id}
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

  defp run_status_gets(%ExitProcessor.Request{} = request) do
    {:ok, eth_height_now} = Eth.get_ethereum_height()
    {blknum_now, _} = State.get_status()

    _ = Logger.debug("eth_height_now: #{inspect(eth_height_now)}, blknum_now: #{inspect(blknum_now)}")
    %{request | eth_height_now: eth_height_now, blknum_now: blknum_now}
  end

  defp get_utxo_existence(%ExitProcessor.Request{utxos_to_check: positions} = request),
    do: %{request | utxo_exists_result: do_utxo_exists?(positions)}

  defp get_ife_input_utxo_existence(%ExitProcessor.Request{ife_input_utxos_to_check: positions} = request),
    do: %{request | ife_input_utxo_exists_result: do_utxo_exists?(positions)}

  defp do_utxo_exists?(positions) do
    result = positions |> Enum.map(&State.utxo_exists?/1)
    _ = Logger.debug("utxos_to_check: #{inspect(positions)}, utxo_exists_result: #{inspect(result)}")
    result
  end

  defp get_spending_blocks(%ExitProcessor.Request{spends_to_get: positions} = request),
    do: %{request | blocks_result: do_get_spending_blocks(positions)}

  defp get_ife_input_spending_blocks(%ExitProcessor.Request{ife_input_spends_to_get: positions} = request),
    do: %{request | ife_input_spending_blocks_result: do_get_spending_blocks(positions)}

  defp do_get_spending_blocks(spent_positions_to_get) do
    blknums = spent_positions_to_get |> Enum.map(&do_get_spent_blknum/1)
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

    blocks |> Enum.map(&Block.from_db_value/1)
  end

  defp do_get_spent_blknum(position) do
    {:ok, spend_blknum} = position |> Utxo.Position.to_db_key() |> OMG.DB.spent_blknum()
    spend_blknum
  end

  defp collect_invalidities_and_state_db_updates(
         {ife_id, {input_exits, output_exits}},
         {invalidities_by_ife_id, state_db_updates}
       ) do
    # we can't call `State.exit_utxos(input_exits ++ output_exits)`
    # because the types of these enumerable items are distinct
    {:ok, input_exits_state_updates, {_, input_invalidities}} = State.exit_utxos(input_exits)
    {:ok, output_exits_state_updates, {_, output_invalidities}} = State.exit_utxos(output_exits)

    exit_invalidities = input_invalidities ++ output_invalidities

    _ =
      if not Enum.empty?(exit_invalidities),
        do: Logger.warn("Invalid in-flight exit finalization: #{inspect(exit_invalidities)}")

    invalidities_by_ife_id = Map.put(invalidities_by_ife_id, ife_id, exit_invalidities)
    state_db_updates = input_exits_state_updates ++ output_exits_state_updates ++ state_db_updates
    {invalidities_by_ife_id, state_db_updates}
  end
end
