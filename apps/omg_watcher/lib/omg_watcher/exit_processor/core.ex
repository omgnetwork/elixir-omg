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

defmodule OMG.Watcher.ExitProcessor.Core do
  @moduledoc """
  Logic related to treating exits by the Watcher.

  This is the functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - enabling to challenge invalid exits
    - figuring out critical failure of invalid exit challenging (aka `:unchallenged_exit` event)
    - MoreVP protocol managing in general

  This is the functional logic driving the `GenServer` in `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.CompetitorInfo
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.ExitProcessor.KnownTx
  alias OMG.Watcher.ExitProcessor.StandardExit

  import OMG.Watcher.ExitProcessor.Tools

  require Utxo
  require Transaction.Payment

  use OMG.Utils.LoggerExt

  @default_sla_margin 10

  @zero_address OMG.Eth.zero_address()

  @max_inputs Transaction.Payment.max_inputs()
  @max_outputs Transaction.Payment.max_outputs()

  @type new_in_flight_exit_status_t() :: {tuple(), pos_integer()}

  @type piggyback_input_index_t() :: 0..unquote(@max_inputs - 1)
  @type piggyback_output_index_t() :: 0..unquote(@max_outputs - 1)

  @type new_piggyback_input_event_t() :: %{
          tx_hash: Transaction.tx_hash(),
          output_index: piggyback_input_index_t(),
          omg_data: %{piggyback_type: :input}
        }
  @type new_piggyback_output_event_t() :: %{
          tx_hash: Transaction.tx_hash(),
          output_index: piggyback_output_index_t(),
          omg_data: %{piggyback_type: :output}
        }

  @type new_piggyback_event_t() :: new_piggyback_input_event_t() | new_piggyback_output_event_t()

  defstruct [
    :sla_margin,
    :min_exit_period_seconds,
    :child_block_interval,
    exits: %{},
    in_flight_exits: %{},
    exit_ids: %{},
    competitors: %{}
  ]

  @type t :: %__MODULE__{
          sla_margin: non_neg_integer(),
          exits: %{Utxo.Position.t() => ExitInfo.t()},
          in_flight_exits: %{Transaction.tx_hash() => InFlightExitInfo.t()},
          # NOTE: maps only standard exit_ids to the natural keys of standard exits (input pointers/utxo_pos)
          #       rethink the approach to the keys in the data structures - how to manage exit_ids? should the contract
          #       serve more data (e.g. input pointers/tx hashes) where it would normally only serve exit_ids?
          exit_ids: %{non_neg_integer() => Utxo.Position.t()},
          competitors: %{Transaction.tx_hash() => CompetitorInfo.t()},
          min_exit_period_seconds: non_neg_integer(),
          child_block_interval: non_neg_integer()
        }

  @type check_validity_result_t :: {:ok | {:error, :unchallenged_exit}, list(Event.byzantine_t())}

  @type spent_blknum_result_t() :: {:ok, pos_integer} | :not_found

  @type in_flight_exit_response_t() :: %{
          txhash: binary(),
          txbytes: binary(),
          eth_height: non_neg_integer(),
          piggybacked_inputs: list(non_neg_integer()),
          piggybacked_outputs: list(non_neg_integer())
        }
  @type in_flight_exits_response_t() :: %{binary() => in_flight_exit_response_t()}

  @doc """
  Reads database-specific list of exits and turns them into current state
  """
  @spec init(
          db_exits :: [{{pos_integer, non_neg_integer, non_neg_integer}, map}],
          db_in_flight_exits :: [{Transaction.tx_hash(), InFlightExitInfo.t()}],
          db_competitors :: [{Transaction.tx_hash(), CompetitorInfo.t()}],
          min_exit_period_seconds :: non_neg_integer(),
          child_block_interval :: non_neg_integer,
          sla_margin :: non_neg_integer
        ) :: {:ok, t()}
  def init(
        db_exits,
        db_in_flight_exits,
        db_competitors,
        min_exit_period_seconds,
        child_block_interval,
        sla_margin \\ @default_sla_margin
      ) do
    exits = db_exits |> Enum.map(&ExitInfo.from_db_kv/1) |> Map.new()

    exit_ids = Enum.into(exits, %{}, fn {utxo_pos, %ExitInfo{exit_id: exit_id}} -> {exit_id, utxo_pos} end)

    {:ok,
     %__MODULE__{
       exits: exits,
       in_flight_exits: db_in_flight_exits |> Enum.map(&InFlightExitInfo.from_db_kv/1) |> Map.new(),
       exit_ids: exit_ids,
       competitors: db_competitors |> Enum.map(&CompetitorInfo.from_db_kv/1) |> Map.new(),
       sla_margin: sla_margin,
       min_exit_period_seconds: min_exit_period_seconds,
       child_block_interval: child_block_interval
     }}
  end

  @doc """
  Use to check if the settings regarding the `:exit_processor_sla_margin` config of `:omg_watcher` are OK.

  Since there are combinations of our configuration that may lead to a dangerous setup of the Watcher
  (in particular - muting the reports of unchallenged_exits), we're enforcing that the `exit_processor_sla_margin`
  be not larger than `min_exit_period`.
  """
  @spec check_sla_margin(pos_integer(), boolean(), pos_integer(), pos_integer()) :: :ok | {:error, :sla_margin_too_big}
  def check_sla_margin(sla_margin, sla_margin_forced, min_exit_period_seconds, ethereum_block_time_seconds)

  def check_sla_margin(sla_margin, true, min_exit_period_seconds, ethereum_block_time_seconds) do
    _ =
      if !sla_margin_safe?(sla_margin, min_exit_period_seconds, ethereum_block_time_seconds),
        do: Logger.warn("Allowing unsafe sla margin of #{sla_margin} blocks")

    :ok
  end

  def check_sla_margin(sla_margin, false, min_exit_period_seconds, ethereum_block_time_seconds) do
    if sla_margin_safe?(sla_margin, min_exit_period_seconds, ethereum_block_time_seconds),
      do: :ok,
      else: {:error, :sla_margin_too_big}
  end

  def exit_key_by_exit_id(%__MODULE__{exit_ids: exit_ids}, exit_id), do: exit_ids[exit_id]

  @doc """
  Add new exits from Ethereum events into tracked state.

  The list of `exit_contract_statuses` is used to track current (as in wall-clock "now", not syncing "now") status.
  This is to prevent spurious invalid exit events being fired during syncing for exits that were challenged/finalized
  Still we do want to track these exits when syncing, to have them spend from `OMG.State` on their finalization
  """
  @deprecated "Use NextExit.get_db_updates/2 instead"
  @spec new_exits(t(), list(map()), list(map)) :: {t(), list()} | {:error, :unexpected_events}
  def new_exits(state, new_exits, exit_contract_statuses)

  def new_exits(_, new_exits, exit_contract_statuses) when length(new_exits) != length(exit_contract_statuses) do
    {:error, :unexpected_events}
  end

  def new_exits(%__MODULE__{exits: exits, exit_ids: exit_ids} = state, new_exits, exit_contract_statuses) do
    new_exits_kv_pairs =
      new_exits
      |> Enum.zip(exit_contract_statuses)
      |> Enum.map(fn {event, contract_status} ->
        {ExitInfo.new_key(contract_status, event), ExitInfo.new(contract_status, event)}
      end)

    db_updates = new_exits_kv_pairs |> Enum.map(&ExitInfo.make_db_update/1)
    new_exits_map = Map.new(new_exits_kv_pairs)

    new_exit_ids_map =
      new_exits_map |> Enum.into(%{}, fn {utxo_pos, %ExitInfo{exit_id: exit_id}} -> {exit_id, utxo_pos} end)

    {%{state | exits: Map.merge(exits, new_exits_map), exit_ids: Map.merge(exit_ids, new_exit_ids_map)}, db_updates}
  end

  defdelegate finalize_exits(state, validities), to: ExitProcessor.Finalizations
  defdelegate prepare_utxo_exits_for_in_flight_exit_finalizations(state, finalizations), to: ExitProcessor.Finalizations
  defdelegate finalize_in_flight_exits(state, finalizations, validities), to: ExitProcessor.Finalizations

  @spec challenge_exits(t(), list(map)) :: {t(), list}
  def challenge_exits(%__MODULE__{exits: exits} = state, challenges) do
    challenged_positions = get_positions_from_events(challenges)

    new_exits_kv_pairs =
      exits
      |> Map.take(challenged_positions)
      |> Enum.into(%{}, fn {utxo_pos, exit_info} -> {utxo_pos, %ExitInfo{exit_info | is_active: false}} end)

    new_state = %{state | exits: Map.merge(exits, new_exits_kv_pairs)}
    db_updates = new_exits_kv_pairs |> Enum.map(&ExitInfo.make_db_update/1)
    {new_state, db_updates}
  end

  defp get_positions_from_events(exits) do
    exits
    |> Enum.map(fn %{utxo_pos: utxo_pos} = _finalization_info -> Utxo.Position.decode!(utxo_pos) end)
  end

  @doc """
  Add new in flight exits from Ethereum events into tracked state.
  """
  @spec new_in_flight_exits(t(), list(map()), list(new_in_flight_exit_status_t())) ::
          {t(), list()} | {:error, :unexpected_events}
  @deprecated "Use NewInflightExits.get_db_updates/2 instead"
  def new_in_flight_exits(state, new_ifes_events, contract_statuses)

  def new_in_flight_exits(_state, new_ifes_events, contract_statuses)
      when length(new_ifes_events) != length(contract_statuses),
      do: {:error, :unexpected_events}

  def new_in_flight_exits(%__MODULE__{in_flight_exits: ifes} = state, new_ifes_events, contract_statuses) do
    new_ifes =
      new_ifes_events
      |> Enum.zip(contract_statuses)
      |> Enum.map(fn {event, contract_status} -> InFlightExitInfo.new_kv(event, contract_status) end)
      |> Map.new()

    updated_state = %{state | in_flight_exits: Map.merge(ifes, new_ifes)}
    updated_ife_keys = new_ifes |> Enum.unzip() |> elem(0)

    db_updates = ife_db_updates(updated_state, updated_ife_keys)

    {updated_state, db_updates}
  end

  defp ife_db_updates(%__MODULE__{in_flight_exits: ifes}, updated_ife_keys) do
    ifes
    |> Map.take(Enum.to_list(updated_ife_keys))
    |> Enum.map(&InFlightExitInfo.make_db_update/1)
  end

  @doc """
    Add piggybacks from Ethereum events into tracked state.
  """
  @spec new_piggybacks(t(), list(new_piggyback_event_t())) :: {t(), list()}
  def new_piggybacks(%__MODULE__{} = state, piggyback_events) when is_list(piggyback_events) do
    event_field_f = fn event -> {event[:omg_data][:piggyback_type], event[:output_index]} end
    consume_events(state, piggyback_events, event_field_f, &InFlightExitInfo.piggyback/2)
  end

  @spec new_ife_challenges(t(), [map()]) :: {t(), list()}
  def new_ife_challenges(%__MODULE__{} = state, challenges_events) do
    {updated_state, ife_db_updates} =
      consume_events(state, challenges_events, & &1[:competitor_position], &InFlightExitInfo.challenge/2)

    {updated_state2, competitors_db_updates} = append_new_competitors(updated_state, challenges_events)
    {updated_state2, competitors_db_updates ++ ife_db_updates}
  end

  defp append_new_competitors(%__MODULE__{competitors: competitors} = state, challenges_events) do
    new_competitors = challenges_events |> Enum.map(&CompetitorInfo.new/1)
    db_updates = new_competitors |> Enum.map(&CompetitorInfo.make_db_update/1)

    {%{state | competitors: Map.merge(competitors, Map.new(new_competitors))}, db_updates}
  end

  @spec respond_to_in_flight_exits_challenges(t(), [map()]) :: {t(), list()}
  def respond_to_in_flight_exits_challenges(%__MODULE__{} = state, responds_events) do
    consume_events(state, responds_events, & &1[:challenge_position], &InFlightExitInfo.respond_to_challenge/2)
  end

  @spec challenge_piggybacks(t(), [map()]) :: {t(), list()}
  def challenge_piggybacks(%__MODULE__{} = state, challenges) do
    event_field_f = fn event -> {event[:omg_data][:piggyback_type], event[:output_index]} end
    consume_events(state, challenges, event_field_f, &InFlightExitInfo.challenge_piggyback/2)
  end

  # produces new state and some db_updates based on
  #   - an enumerable of Ethereum events with tx_hash and some field
  #   - name of that other field
  #   - a function operating on a single IFE structure and that fields value
  # Leverages the fact, that operating on various IFE-related events follows the same pattern
  defp consume_events(%__MODULE__{} = state, events, event_field_f, ife_f) do
    processing_f = process_reducing_events_f(event_field_f, ife_f)
    {updated_state, updated_ife_keys} = Enum.reduce(events, {state, MapSet.new()}, processing_f)
    db_updates = ife_db_updates(updated_state, updated_ife_keys)
    {updated_state, db_updates}
  end

  # produces an `Enum.reduce`-able function that: grabs an IFE by tx_hash from the event, invokes a function on that
  # using the value of a different field from the event, returning updated state and mapset of modified keys.
  # Pseudocode:
  # `event |> get IFE by tx_hash |> ife_f.(event[event_field])`
  defp process_reducing_events_f(event_field_f, ife_f) do
    fn event, {%__MODULE__{in_flight_exits: ifes} = state, updated_ife_keys} ->
      tx_hash = event.tx_hash
      event_field_value = event_field_f.(event)
      updated_ife = ifes |> Map.fetch!(tx_hash) |> ife_f.(event_field_value)

      updated_state = %{state | in_flight_exits: Map.put(ifes, tx_hash, updated_ife)}
      {updated_state, MapSet.put(updated_ife_keys, tx_hash)}
    end
  end

  @doc """
  Only for the active in-flight exits, based on the current tracked state.
  Only for IFEs which transactions where included into the chain and whose outputs were potentially spent.

  Compare with determine_utxo_existence_to_get/2.
  """
  @spec determine_ife_input_utxos_existence_to_get(ExitProcessor.Request.t(), t()) :: ExitProcessor.Request.t()
  def determine_ife_input_utxos_existence_to_get(
        %ExitProcessor.Request{blknum_now: blknum_now} = request,
        %__MODULE__{in_flight_exits: ifes}
      )
      when not is_nil(blknum_now) do
    ife_input_positions =
      ifes
      |> Map.values()
      |> Enum.filter(&InFlightExitInfo.should_be_seeked_in_blocks?/1)
      |> Enum.filter(&InFlightExitInfo.is_relevant?(&1, blknum_now))
      |> Enum.flat_map(&Transaction.get_inputs(&1.tx))
      |> :lists.usort()

    %{request | ife_input_utxos_to_check: ife_input_positions}
  end

  @doc """
  All the active exits, in-flight exits, exiting output piggybacks etc., based on the current tracked state
  """
  @spec determine_utxo_existence_to_get(ExitProcessor.Request.t(), t()) :: ExitProcessor.Request.t()
  def determine_utxo_existence_to_get(
        %ExitProcessor.Request{blknum_now: blknum_now} = request,
        %__MODULE__{} = state
      )
      when not is_nil(blknum_now) do
    %{request | utxos_to_check: do_determine_utxo_existence_to_get(state, blknum_now)}
  end

  defp do_determine_utxo_existence_to_get(%__MODULE__{in_flight_exits: ifes} = state, blknum_now) do
    standard_exits_pos =
      StandardExit.exiting_positions(state)
      |> Enum.filter(fn Utxo.position(blknum, _, _) -> blknum < blknum_now end)

    active_relevant_ifes =
      ifes
      |> Map.values()
      |> Enum.filter(& &1.is_active)
      |> Enum.filter(&InFlightExitInfo.is_relevant?(&1, blknum_now))

    ife_inputs_pos = active_relevant_ifes |> Enum.flat_map(&Transaction.get_inputs(&1.tx))
    ife_outputs_pos = active_relevant_ifes |> Enum.flat_map(&InFlightExitInfo.get_active_output_piggybacks_positions/1)

    (ife_outputs_pos ++ ife_inputs_pos ++ standard_exits_pos)
    |> :lists.usort()
  end

  @doc """
  Figures out which numbers of "spending transaction blocks" to get for the utxos, based on the existence reported by
  `OMG.State` and possibly other factors, eg. only take the non-existent UTXOs spends (naturally) and ones that
  pertain to IFE transaction inputs.

  Assumes that UTXOs that haven't been checked (i.e. not a key in `utxo_exists?` map) **exist**

  To proceed with validation/proof building, this function must ask for blocks that satisfy following criteria:
    1/ blocks where any input to any IFE was spent
    2/ blocks where any output to any IFE was spent
  """
  @spec determine_spends_to_get(ExitProcessor.Request.t(), __MODULE__.t()) :: ExitProcessor.Request.t()
  def determine_spends_to_get(
        %ExitProcessor.Request{
          utxos_to_check: utxos_to_check,
          utxo_exists_result: utxo_exists_result
        } = request,
        %__MODULE__{in_flight_exits: ifes}
      ) do
    utxo_exists? = Enum.zip(utxos_to_check, utxo_exists_result) |> Map.new()

    spends_to_get =
      ifes
      |> Map.values()
      |> Enum.flat_map(fn %{tx: tx} = ife ->
        InFlightExitInfo.get_active_output_piggybacks_positions(ife) ++ Transaction.get_inputs(tx)
      end)
      |> only_utxos_checked_and_missing(utxo_exists?)
      |> :lists.usort()

    %{request | spends_to_get: spends_to_get}
  end

  @doc """
  Figures out which numbers of "spending transaction blocks" to get for the outputs on IFEs utxos.

  To proceed with validation/proof building, this function must ask for blocks that satisfy following criteria:
    1/ blocks, where any output from an IFE tx might have been created, by including such IFE tx

  Similar to `determine_spends_to_get`, otherwise.
  """
  @spec determine_ife_spends_to_get(ExitProcessor.Request.t(), __MODULE__.t()) :: ExitProcessor.Request.t()
  def determine_ife_spends_to_get(
        %ExitProcessor.Request{
          ife_input_utxos_to_check: utxos_to_check,
          ife_input_utxo_exists_result: utxo_exists_result
        } = request,
        %__MODULE__{in_flight_exits: ifes}
      ) do
    utxo_exists? = Enum.zip(utxos_to_check, utxo_exists_result) |> Map.new()

    spends_to_get =
      ifes
      |> Map.values()
      |> Enum.flat_map(&Transaction.get_inputs(&1.tx))
      |> only_utxos_checked_and_missing(utxo_exists?)
      |> :lists.usort()

    %{request | ife_input_spends_to_get: spends_to_get}
  end

  @doc """
  Filters out all the spends that have not been found (`:not_found` instead of a block)
  This might occur if a UTXO is exited by exit finalization. A block spending such UTXO will not exist.
  """
  @spec handle_spent_blknum_result(list(spent_blknum_result_t()), list(Utxo.Position.t())) :: list(pos_integer())
  def handle_spent_blknum_result(spent_blknum_result, spent_positions_to_get) do
    {not_founds, founds} =
      Stream.zip(spent_positions_to_get, spent_blknum_result)
      |> Enum.split_with(fn {_utxo_pos, result} -> result == :not_found end)

    blknums_to_get = founds |> Enum.unzip() |> elem(1) |> Enum.map(fn {:ok, blknum} -> blknum end)

    warn? = !Enum.empty?(not_founds)
    _ = if warn?, do: Logger.warn("UTXO doesn't exists but no spend registered (spent in exit?) #{inspect(not_founds)}")

    Enum.uniq(blknums_to_get)
  end

  @doc """
  Based on the result of exit validity (utxo existence), return invalid exits or appropriate notifications

  NOTE: We're using `ExitStarted`-height with `sla_exit_margin` added on top, to determine old, unchallenged invalid
        exits. This is different than documented, according to what we ought to be using
        `exitable_at - sla_exit_margin_s` to determine such exits.

  NOTE: If there were any exits unchallenged for some time in chain history, this might detect breach of SLA,
        even if the exits were eventually challenged (e.g. during syncing)
  """
  @spec check_validity(ExitProcessor.Request.t(), t()) :: check_validity_result_t()
  def check_validity(
        %ExitProcessor.Request{
          eth_height_now: eth_height_now,
          utxos_to_check: utxos_to_check,
          utxo_exists_result: utxo_exists_result,
          blocks_result: blocks
        },
        %__MODULE__{} = state
      )
      when not is_nil(eth_height_now) do
    utxo_exists? = Enum.zip(utxos_to_check, utxo_exists_result) |> Map.new()

    {invalid_exits, late_invalid_exits} = StandardExit.get_invalid(state, utxo_exists?, eth_height_now)

    invalid_exit_events =
      invalid_exits
      |> Enum.map(fn {position, exit_info} -> ExitInfo.make_event_data(Event.InvalidExit, position, exit_info) end)

    late_invalid_exits_events =
      late_invalid_exits
      |> Enum.map(fn {position, late_exit} -> ExitInfo.make_event_data(Event.UnchallengedExit, position, late_exit) end)

    known_txs_by_input = KnownTx.get_all_from_blocks_appendix(blocks, state)

    {non_canonical_ife_events, late_non_canonical_ife_events} =
      ExitProcessor.Canonicity.get_ife_txs_with_competitors(state, known_txs_by_input, eth_height_now)

    invalid_ife_challenges_events = ExitProcessor.Canonicity.get_invalid_ife_challenges(state)

    {invalid_piggybacks_events, late_invalid_piggybacks_events} =
      ExitProcessor.Piggyback.get_invalid_piggybacks_events(state, known_txs_by_input, eth_height_now)

    available_piggybacks_events =
      state
      |> get_ifes_to_piggyback()
      |> Enum.flat_map(&prepare_available_piggyback/1)

    unchallenged_exit_events =
      late_non_canonical_ife_events ++ late_invalid_exits_events ++ late_invalid_piggybacks_events

    chain_validity = if Enum.empty?(unchallenged_exit_events), do: :ok, else: {:error, :unchallenged_exit}

    events =
      Enum.concat([
        unchallenged_exit_events,
        invalid_exit_events,
        invalid_piggybacks_events,
        non_canonical_ife_events,
        invalid_ife_challenges_events,
        available_piggybacks_events
      ])

    {chain_validity, events}
  end

  defdelegate get_competitor_for_ife(request, state, ife_txbytes), to: ExitProcessor.Canonicity
  defdelegate prove_canonical_for_ife(state, ife_txbytes), to: ExitProcessor.Canonicity

  defdelegate get_input_challenge_data(request, state, txbytes, input_index), to: ExitProcessor.Piggyback
  defdelegate get_output_challenge_data(request, state, txbytes, output_index), to: ExitProcessor.Piggyback

  defdelegate determine_standard_challenge_queries(request, state, exiting_utxo_exists), to: ExitProcessor.StandardExit
  defdelegate create_challenge(request, state), to: ExitProcessor.StandardExit

  @spec get_ifes_to_piggyback(t()) :: list(InFlightExitInfo.t())
  defp get_ifes_to_piggyback(%__MODULE__{in_flight_exits: ifes}) do
    ifes
    |> Map.values()
    |> Stream.filter(fn %InFlightExitInfo{is_active: is_active, tx_seen_in_blocks_at: seen} -> is_active && !seen end)
    |> Enum.uniq_by(fn %InFlightExitInfo{tx: signed_tx} -> signed_tx end)
  end

  @spec prepare_available_piggyback(InFlightExitInfo.t()) :: list(Event.PiggybackAvailable.t())
  defp prepare_available_piggyback(%InFlightExitInfo{tx: signed_tx} = ife) do
    outputs = Transaction.get_outputs(signed_tx)
    {:ok, input_witnesses} = Transaction.Signed.get_witnesses(signed_tx)

    available_inputs =
      input_witnesses
      |> Enum.filter(fn {index, _} -> not InFlightExitInfo.is_piggybacked?(ife, {:input, index}) end)
      |> Enum.map(fn {index, owner} -> %{index: index, address: owner} end)

    available_outputs =
      outputs
      |> Enum.filter(fn %{owner: owner} -> zero_address?(owner) end)
      |> Enum.with_index()
      |> Enum.filter(fn {_, index} -> not InFlightExitInfo.is_piggybacked?(ife, {:output, index}) end)
      |> Enum.map(fn {%{owner: owner}, index} -> %{index: index, address: owner} end)

    if Enum.empty?(available_inputs) and Enum.empty?(available_outputs) do
      []
    else
      [
        %Event.PiggybackAvailable{
          txbytes: Transaction.raw_txbytes(signed_tx),
          available_outputs: available_outputs,
          available_inputs: available_inputs
        }
      ]
    end
  end

  @doc """
  Returns a map of active in flight exits, where keys are IFE hashes and values are IFES
  """
  @spec get_active_in_flight_exits(__MODULE__.t()) :: list(map)
  def get_active_in_flight_exits(%__MODULE__{in_flight_exits: ifes}) do
    ifes
    |> Enum.filter(fn {_, %InFlightExitInfo{is_active: is_active}} -> is_active end)
    |> Enum.map(&prepare_in_flight_exit/1)
  end

  @doc """
  Returns a set of utxo positions for standard exiting utxos
  """
  @spec active_standard_exiting_utxos(list(map)) :: MapSet.t(Utxo.Position.t())
  def active_standard_exiting_utxos(db_exits) do
    db_exits
    |> Stream.map(&ExitInfo.from_db_kv/1)
    |> Stream.filter(fn {_, exit_info} -> exit_info.is_active end)
    |> Enum.map(&Kernel.elem(&1, 0))
    |> MapSet.new()
  end

  defp prepare_in_flight_exit({txhash, ife_info}) do
    %{tx: tx, eth_height: eth_height} = ife_info

    %{
      txhash: txhash,
      txbytes: Transaction.raw_txbytes(tx),
      eth_height: eth_height,
      piggybacked_inputs: InFlightExitInfo.actively_piggybacked_inputs(ife_info),
      piggybacked_outputs: InFlightExitInfo.actively_piggybacked_outputs(ife_info)
    }
  end

  @doc """
  If IFE's spend is in blocks, find its txpos and update the IFE.
  Note: this change is not persisted later!
  """
  def find_ifes_in_blocks(
        %__MODULE__{in_flight_exits: ifes} = state,
        %ExitProcessor.Request{ife_input_spending_blocks_result: blocks}
      ) do
    # precompute some useful maps first
    blocks = Enum.filter(blocks, &(&1 != :not_found))
    positions_by_tx_hash = KnownTx.get_positions_by_txhash(blocks)
    blocks_by_blknum = KnownTx.get_blocks_by_blknum(blocks)

    new_ifes =
      ifes
      |> Enum.filter(fn {_, ife} -> InFlightExitInfo.should_be_seeked_in_blocks?(ife) end)
      |> Enum.map(fn {hash, ife} ->
        {hash, ife, KnownTx.find_tx_in_blocks(hash, positions_by_tx_hash, blocks_by_blknum)}
      end)
      |> Enum.filter(fn {_hash, _ife, maybepos} -> maybepos != nil end)
      |> Enum.into(ifes, fn {hash, ife, {block, position}} ->
        Utxo.position(_, txindex, _) = position
        proof = Block.inclusion_proof(block, txindex)
        {hash, %InFlightExitInfo{ife | tx_seen_in_blocks_at: {position, proof}}}
      end)

    %{state | in_flight_exits: new_ifes}
  end

  defp zero_address?(address) do
    address != @zero_address
  end

  defp sla_margin_safe?(exit_processor_sla_margin, min_exit_period_seconds, ethereum_block_time_seconds),
    do: exit_processor_sla_margin * ethereum_block_time_seconds < min_exit_period_seconds
end
