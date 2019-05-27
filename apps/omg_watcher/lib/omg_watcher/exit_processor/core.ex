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

defmodule OMG.Watcher.ExitProcessor.Core do
  @moduledoc """
  Encapsulates managing and executing the behaviors related to treating exits by the child chain and watchers
  Keeps a state of exits that are in progress, updates it with news from the root chain, compares to the
  state of the ledger (`OMG.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.

  This is the functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - enabling to challenge invalid exits
    - figuring out critical failure of invalid exit challenging (aka `:unchallenged_exit` event)
    - MoreVP protocol managing in general

  For the imperative shell, see `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.CompetitorInfo
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.ExitProcessor.StandardExitChallenge
  alias OMG.Watcher.ExitProcessor.Tools.DoubleSpend
  alias OMG.Watcher.ExitProcessor.Tools.KnownTx
  alias OMG.Watcher.ExitProcessor.TxAppendix

  import OMG.Watcher.ExitProcessor.Tools

  require Utxo
  require Transaction

  use OMG.Utils.LoggerExt

  @default_sla_margin 10
  @zero_address OMG.Eth.zero_address()

  @type contract_piggyback_offset_t() :: 0..7

  defstruct [:sla_margin, exits: %{}, in_flight_exits: %{}, competitors: %{}]

  @type t :: %__MODULE__{
          sla_margin: non_neg_integer(),
          exits: %{Utxo.Position.t() => ExitInfo.t()},
          in_flight_exits: %{Transaction.tx_hash() => InFlightExitInfo.t()},
          competitors: %{Transaction.tx_hash() => CompetitorInfo.t()}
        }

  @type check_validity_result_t :: {:ok | {:error, :unchallenged_exit}, list(Event.byzantine_t())}

  @type competitor_data_t :: %{
          in_flight_txbytes: binary(),
          in_flight_input_index: non_neg_integer(),
          competing_txbytes: binary(),
          competing_input_index: non_neg_integer(),
          competing_sig: binary(),
          competing_tx_pos: Utxo.Position.t(),
          competing_proof: binary()
        }

  @type prove_canonical_data_t :: %{
          in_flight_txbytes: binary(),
          in_flight_tx_pos: Utxo.Position.t(),
          in_flight_proof: binary()
        }

  @type input_challenge_data :: %{
          in_flight_txbytes: Transaction.tx_bytes(),
          in_flight_input_index: 0..3,
          spending_txbytes: Transaction.tx_bytes(),
          spending_input_index: 0..3,
          spending_sig: <<_::520>>
        }

  @type output_challenge_data :: %{
          in_flight_txbytes: Transaction.tx_bytes(),
          in_flight_output_pos: pos_integer(),
          in_flight_input_index: 4..7,
          spending_txbytes: Transaction.tx_bytes(),
          spending_input_index: 0..3,
          spending_sig: <<_::520>>
        }

  @type piggyback_challenge_data_error() ::
          :ife_not_known_for_tx
          | Transaction.decode_error()
          | :no_double_spend_on_particular_piggyback

  @type spent_blknum_result_t() :: pos_integer | :not_found

  @type piggyback_type_t() :: :input | :output
  @type piggyback_t() :: {piggyback_type_t(), non_neg_integer()}

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
          sla_margin :: non_neg_integer
        ) :: {:ok, t()}
  def init(db_exits, db_in_flight_exits, db_competitors, sla_margin \\ @default_sla_margin) do
    {:ok,
     %__MODULE__{
       exits: db_exits |> Enum.map(&ExitInfo.from_db_kv/1) |> Map.new(),
       in_flight_exits: db_in_flight_exits |> Enum.map(&InFlightExitInfo.from_db_kv/1) |> Map.new(),
       competitors: db_competitors |> Enum.map(&CompetitorInfo.from_db_kv/1) |> Map.new(),
       sla_margin: sla_margin
     }}
  end

  @doc """
  Add new exits from Ethereum events into tracked state.

  The list of `exit_contract_statuses` is used to track current (as in wall-clock "now", not syncing "now") status.
  This is to prevent spurious invalid exit events being fired during syncing for exits that were challenged/finalized
  Still we do want to track these exits when syncing, to have them spend from `OMG.State` on their finalization
  """
  @spec new_exits(t(), list(map()), list(map)) :: {t(), list()} | {:error, :unexpected_events}
  def new_exits(state, new_exits, exit_contract_statuses)

  def new_exits(_, new_exits, exit_contract_statuses) when length(new_exits) != length(exit_contract_statuses) do
    {:error, :unexpected_events}
  end

  def new_exits(%__MODULE__{exits: exits} = state, new_exits, exit_contract_statuses) do
    new_exits_kv_pairs =
      new_exits
      |> Enum.zip(exit_contract_statuses)
      |> Enum.map(fn {event, contract_status} ->
        {ExitInfo.new_key(contract_status, event), ExitInfo.new(contract_status, event)}
      end)

    db_updates = new_exits_kv_pairs |> Enum.map(&ExitInfo.make_db_update/1)
    new_exits_map = Map.new(new_exits_kv_pairs)

    {%{state | exits: Map.merge(exits, new_exits_map)}, db_updates}
  end

  @doc """
  Finalize exits based on Ethereum events, removing from tracked state if valid.

  Invalid finalizing exits should continue being tracked as `is_active`, to continue emitting events.
  This includes non-`is_active` exits that finalize invalid, which are turned to be `is_active` now.
  """
  @spec finalize_exits(t(), validities :: {list(Utxo.Position.t()), list(Utxo.Position.t())}) :: {t(), list(), list()}
  def finalize_exits(%__MODULE__{exits: exits} = state, {valid_finalizations, invalid}) do
    # handling valid finalizations
    exit_event_triggers =
      valid_finalizations
      |> Enum.map(fn utxo_pos ->
        %ExitInfo{owner: owner, currency: currency, amount: amount} = exits[utxo_pos]

        %{exit_finalized: %{owner: owner, currency: currency, amount: amount, utxo_pos: utxo_pos}}
      end)

    state_without_valid_ones = %{state | exits: Map.drop(exits, valid_finalizations)}
    db_updates = delete_positions(valid_finalizations)

    # invalid ones - activating, in case they were inactive, to keep being invalid forever
    {new_state, activating_db_updates} = activate_on_invalid_finalization(state_without_valid_ones, invalid)

    {new_state, exit_event_triggers, db_updates ++ activating_db_updates}
  end

  defp activate_on_invalid_finalization(%__MODULE__{exits: exits} = state, invalid_finalizations) do
    exits_to_activate =
      exits
      |> Map.take(invalid_finalizations)
      |> Enum.map(fn {k, v} -> {k, Map.update!(v, :is_active, fn _ -> true end)} end)
      |> Map.new()

    activating_db_updates =
      exits_to_activate
      |> Enum.map(&ExitInfo.make_db_update/1)

    state = %{state | exits: Map.merge(exits, exits_to_activate)}
    {state, activating_db_updates}
  end

  @spec challenge_exits(t(), list(map)) :: {t(), list}
  def challenge_exits(%__MODULE__{exits: exits} = state, challenges) do
    challenged_positions = get_positions_from_events(challenges)
    state = %{state | exits: Map.drop(exits, challenged_positions)}
    db_updates = delete_positions(challenged_positions)
    {state, db_updates}
  end

  defp get_positions_from_events(exits) do
    exits
    |> Enum.map(fn %{utxo_pos: utxo_pos} = _finalization_info -> Utxo.Position.decode!(utxo_pos) end)
  end

  defp delete_positions(utxo_positions),
    do: utxo_positions |> Enum.map(&{:delete, :exit_info, Utxo.Position.to_db_key(&1)})

  # TODO: syncing problem (look new exits)
  @doc """
   Add new in flight exits from Ethereum events into tracked state.
  """
  @spec new_in_flight_exits(t(), list(map()), list(map())) :: {t(), list()} | {:error, :unexpected_events}
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
    |> Map.take(updated_ife_keys)
    |> Enum.map(&InFlightExitInfo.make_db_update/1)
  end

  @doc """
    Add piggybacks from Ethereum events into tracked state.
  """
  @spec new_piggybacks(t(), [%{tx_hash: Transaction.tx_hash(), output_index: contract_piggyback_offset_t()}]) ::
          {t(), list()}
  def new_piggybacks(%__MODULE__{} = state, piggyback_events) when is_list(piggyback_events) do
    consume_events(state, piggyback_events, :output_index, &InFlightExitInfo.piggyback/2)
  end

  @spec new_ife_challenges(t(), [map()]) :: {t(), list()}
  def new_ife_challenges(%__MODULE__{} = state, challenges_events) do
    {updated_state, ife_db_updates} =
      consume_events(state, challenges_events, :competitor_position, &InFlightExitInfo.challenge/2)

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
    consume_events(state, responds_events, :challenge_position, &InFlightExitInfo.respond_to_challenge/2)
  end

  @spec challenge_piggybacks(t(), [map()]) :: {t(), list()}
  def challenge_piggybacks(%__MODULE__{} = state, challenges) do
    consume_events(state, challenges, :output_index, &InFlightExitInfo.challenge_piggyback/2)
  end

  # produces new state and some db_updates based on
  #   - an enumerable of Ethereum events with tx_hash and some field
  #   - name of that other field
  #   - a function operating on a single IFE structure and that fields value
  # Leverages the fact, that operating on various IFE-related events follows the same pattern
  defp consume_events(%__MODULE__{} = state, events, event_field, ife_f) do
    processing_f = process_reducing_events_f(event_field, ife_f)
    {updated_state, updated_ife_keys} = Enum.reduce(events, {state, MapSet.new()}, processing_f)
    db_updates = ife_db_updates(updated_state, updated_ife_keys)
    {updated_state, db_updates}
  end

  # produces an `Enum.reduce`-able function that: grabs an IFE by tx_hash from the event, invokes a function on that
  # using the value of a different field from the event, returning updated state and mapset of modified keys.
  # Pseudocode:
  # `event |> get IFE by tx_hash |> ife_f.(event[event_field])`
  defp process_reducing_events_f(event_field, ife_f) do
    fn event, {%__MODULE__{in_flight_exits: ifes} = state, updated_ife_keys} ->
      tx_hash = event.tx_hash
      event_field_value = event[event_field]
      updated_ife = ifes |> Map.fetch!(tx_hash) |> ife_f.(event_field_value)

      updated_state = %{state | in_flight_exits: Map.put(ifes, tx_hash, updated_ife)}
      {updated_state, MapSet.put(updated_ife_keys, tx_hash)}
    end
  end

  @doc """
  Returns a tuple of {:ok, map in-flight exit id => {finalized input exits, finalized output exits}}.
  finalized input exits and finalized output exits structures both fit into `OMG.State.exit_utxos/1`.

  When there are invalid finalizations, returns one of the following:
    - {:unknown_piggybacks, list of piggybacks that exit processor state is not aware of}
    - {:unknown_in_flight_exit, set of in-flight exit ids that exit processor is not aware of}
  """
  @spec prepare_utxo_exits_for_in_flight_exit_finalizations(t(), [map()]) ::
          {:ok, map()}
          | {:unknown_piggybacks, list()}
          | {:unknown_in_flight_exit, MapSet.t(non_neg_integer())}
  def prepare_utxo_exits_for_in_flight_exit_finalizations(%__MODULE__{in_flight_exits: ifes}, finalizations) do
    finalizations = finalizations |> Enum.map(&ife_id_to_binary/1)

    with {:ok, ifes_by_id} <- get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes),
         {:ok, []} <- known_piggybacks?(finalizations, ifes_by_id) do
      {exits_by_ife_id, _} =
        finalizations
        |> Enum.reduce({%{}, ifes_by_id}, &prepare_utxo_exits_for_finalization/2)

      {:ok, exits_by_ife_id}
    end
  end

  # converts from int, which is how the contract serves it
  defp ife_id_to_binary(finalization),
    do: Map.update!(finalization, :in_flight_exit_id, fn id -> <<id::192>> end)

  defp get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes) do
    finalizations_ids =
      finalizations
      |> Enum.map(fn %{in_flight_exit_id: id} -> id end)
      |> MapSet.new()

    by_contract_id =
      ifes
      |> Enum.map(fn {tx_hash, %InFlightExitInfo{contract_id: id} = ife} -> {id, {tx_hash, ife}} end)
      |> Map.new()

    known_ifes =
      by_contract_id
      |> Map.keys()
      |> MapSet.new()

    unknown_ifes = MapSet.difference(finalizations_ids, known_ifes)

    if Enum.empty?(unknown_ifes) do
      {:ok, by_contract_id}
    else
      {:unknown_in_flight_exit, unknown_ifes}
    end
  end

  defp known_piggybacks?(finalizations, ifes_by_id) do
    not_piggybacked =
      finalizations
      |> Enum.filter(fn %{in_flight_exit_id: ife_id, output_index: output} ->
        {_, ife} = Map.get(ifes_by_id, ife_id)
        not InFlightExitInfo.is_piggybacked?(ife, output)
      end)

    if Enum.empty?(not_piggybacked) do
      {:ok, []}
    else
      {:unknown_piggybacks, not_piggybacked}
    end
  end

  defp prepare_utxo_exits_for_finalization(
         %{in_flight_exit_id: ife_id, output_index: output},
         {exits, ifes_by_id}
       ) do
    {tx_hash, ife} = Map.get(ifes_by_id, ife_id)
    # a runtime sanity check - if this were false it would mean all piggybacks finalized so contract wouldn't allow that
    true = InFlightExitInfo.is_active?(ife, output)

    {input_exits, output_exits} =
      if output >= 4 do
        {[], [%{tx_hash: tx_hash, output_index: output}]}
      else
        %InFlightExitInfo{tx: %Transaction.Signed{raw_tx: tx}} = ife
        input_exit = tx |> Transaction.get_inputs() |> Enum.at(output)
        {[input_exit], []}
      end

    {input_exits_acc, output_exits_acc} = Map.get(exits, ife_id, {[], []})
    exits = Map.put(exits, ife_id, {input_exits ++ input_exits_acc, output_exits ++ output_exits_acc})
    {exits, ifes_by_id}
  end

  @doc """
  Finalizes in-flight exits.

  Returns a tuple of {:ok, updated state, database updates}.
  When there are invalid finalizations, returns one of the following:
    - {:unknown_piggybacks, list of piggybacks that exit processor state is not aware of}
    - {:unknown_in_flight_exit, set of in-flight exit ids that exit processor is not aware of}
  """
  @spec finalize_in_flight_exits(t(), [map()], map()) ::
          {:ok, t(), list()}
          | {:unknown_piggybacks, list()}
          | {:unknown_in_flight_exit, MapSet.t(non_neg_integer())}
  def finalize_in_flight_exits(%__MODULE__{in_flight_exits: ifes} = state, finalizations, invalidities_by_ife_id) do
    # convert ife_id from int (given by contract) to a binary
    finalizations =
      finalizations
      |> Enum.map(fn %{in_flight_exit_id: id} = map -> Map.replace!(map, :in_flight_exit_id, <<id::192>>) end)

    with {:ok, ifes_by_id} <- get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes),
         {:ok, []} <- known_piggybacks?(finalizations, ifes_by_id) do
      {ifes_by_id, updated_ifes} =
        finalizations
        |> Enum.reduce({ifes_by_id, MapSet.new()}, &finalize_single_exit/2)
        |> activate_on_invalid_utxo_exits(invalidities_by_ife_id)

      db_updates =
        Map.new(ifes_by_id)
        |> Map.take(updated_ifes)
        |> Enum.map(fn {_, value} -> value end)
        |> Enum.map(&InFlightExitInfo.make_db_update/1)

      ifes =
        ifes_by_id
        |> Enum.map(fn {_, value} -> value end)
        |> Map.new()

      {:ok, %{state | in_flight_exits: ifes}, db_updates}
    end
  end

  defp finalize_single_exit(
         %{in_flight_exit_id: ife_id, output_index: output},
         {ifes_by_id, updated_ifes}
       ) do
    {tx_hash, ife} = Map.get(ifes_by_id, ife_id)

    if InFlightExitInfo.is_active?(ife, output) do
      {:ok, finalized_ife} = InFlightExitInfo.finalize(ife, output)
      ifes_by_id = Map.put(ifes_by_id, ife_id, {tx_hash, finalized_ife})
      updated_ifes = MapSet.put(updated_ifes, ife_id)

      {ifes_by_id, updated_ifes}
    else
      {ifes_by_id, updated_ifes}
    end
  end

  defp activate_on_invalid_utxo_exits({ifes_by_id, updated_ifes}, invalidities_by_ife_id) do
    ifes_to_activate =
      invalidities_by_ife_id
      |> Enum.filter(fn {_ife_id, invalidities} -> not Enum.empty?(invalidities) end)
      |> Enum.map(fn {ife_id, _invalidities} -> ife_id end)
      |> MapSet.new()

    ifes_by_id = Enum.map(ifes_by_id, &activate_in_flight_exit(&1, ifes_to_activate))

    updated_ifes = MapSet.to_list(ifes_to_activate) ++ MapSet.to_list(updated_ifes)
    updated_ifes = MapSet.new(updated_ifes)

    {ifes_by_id, updated_ifes}
  end

  defp activate_in_flight_exit({ife_id, {tx_hash, ife}}, ifes_to_activate) do
    if MapSet.member?(ifes_to_activate, ife_id) do
      activated_ife = InFlightExitInfo.activate(ife)
      {ife_id, {tx_hash, activated_ife}}
    else
      {ife_id, {tx_hash, ife}}
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
      when is_integer(blknum_now) do
    ife_input_positions =
      ifes
      |> Map.values()
      |> Enum.filter(&(&1.tx_seen_in_blocks_at == nil))
      |> Enum.filter(& &1.is_active)
      |> Enum.flat_map(&Transaction.get_inputs(&1.tx))
      |> Enum.filter(fn Utxo.position(blknum, _, _) -> blknum < blknum_now end)
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
      when is_integer(blknum_now) do
    %{request | utxos_to_check: do_determine_utxo_existence_to_get(state, blknum_now)}
  end

  defp do_determine_utxo_existence_to_get(%__MODULE__{in_flight_exits: ifes} = state, blknum_now) do
    standard_exits_pos = StandardExitChallenge.exiting_positions(state)

    active_ifes = ifes |> Map.values() |> Enum.filter(& &1.is_active)
    ife_inputs_pos = active_ifes |> Enum.flat_map(&Transaction.get_inputs(&1.tx))
    ife_outputs_pos = active_ifes |> Enum.flat_map(&InFlightExitInfo.get_piggybacked_outputs_positions/1)

    (ife_outputs_pos ++ ife_inputs_pos ++ standard_exits_pos)
    |> Enum.filter(fn Utxo.position(blknum, _, _) -> blknum != 0 and blknum < blknum_now end)
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
        InFlightExitInfo.get_piggybacked_outputs_positions(ife) ++ Transaction.get_inputs(tx)
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

    {_, blknums_to_get} = Enum.unzip(founds)

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
          utxo_exists_result: utxo_exists_result
        } = request,
        %__MODULE__{} = state
      )
      when is_integer(eth_height_now) do
    utxo_exists? = Enum.zip(utxos_to_check, utxo_exists_result) |> Map.new()

    {invalid_exits, late_invalid_exits} = StandardExitChallenge.get_invalid(state, utxo_exists?, eth_height_now)

    invalid_exit_events =
      invalid_exits
      |> Enum.map(fn {position, exit_info} -> ExitInfo.make_event_data(Event.InvalidExit, position, exit_info) end)

    late_invalid_exits_events =
      late_invalid_exits
      |> Enum.map(fn {position, late_exit} -> ExitInfo.make_event_data(Event.UnchallengedExit, position, late_exit) end)

    ifes_with_competitors_events =
      get_ife_txs_with_competitors(request, state)
      |> Enum.map(fn txbytes -> %Event.NonCanonicalIFE{txbytes: txbytes} end)

    invalid_piggybacks = get_invalid_piggybacks_events(request, state)

    # TODO: late piggybacks are critical, to be implemented in OMG-408
    late_invalid_piggybacks = []

    has_no_late_invalid_exits = Enum.empty?(late_invalid_exits) and Enum.empty?(late_invalid_piggybacks)

    invalid_ife_challenges_events =
      get_invalid_ife_challenges(state)
      |> Enum.map(fn txbytes -> %Event.InvalidIFEChallenge{txbytes: txbytes} end)

    available_piggybacks_events =
      get_ifes_to_piggyback(state)
      |> Enum.flat_map(&prepare_available_piggyback/1)

    events =
      [
        late_invalid_exits_events,
        invalid_exit_events,
        invalid_piggybacks,
        late_invalid_piggybacks,
        ifes_with_competitors_events,
        invalid_ife_challenges_events,
        available_piggybacks_events
      ]
      |> Enum.concat()

    chain_validity = if has_no_late_invalid_exits, do: :ok, else: {:error, :unchallenged_exit}

    {chain_validity, events}
  end

  def get_input_challenge_data(request, state, txbytes, input_index) do
    case input_index in 0..(Transaction.max_inputs() - 1) do
      true -> get_piggyback_challenge_data(request, state, txbytes, {:input, input_index})
      false -> {:error, :piggybacked_index_out_of_range}
    end
  end

  def get_output_challenge_data(request, state, txbytes, output_index) do
    case output_index in 0..(Transaction.max_outputs() - 1) do
      true -> get_piggyback_challenge_data(request, state, txbytes, {:output, output_index})
      false -> {:error, :piggybacked_index_out_of_range}
    end
  end

  defdelegate determine_standard_challenge_queries(request, state), to: ExitProcessor.StandardExitChallenge
  defdelegate determine_exit_txbytes(request, state), to: ExitProcessor.StandardExitChallenge
  defdelegate create_challenge(request, state), to: ExitProcessor.StandardExitChallenge

  @spec produce_invalid_piggyback_proof(InFlightExitInfo.t(), list(KnownTx.t()), piggyback_t()) ::
          {:ok, input_challenge_data() | output_challenge_data()} | {:error, :no_double_spend_on_particular_piggyback}
  defp produce_invalid_piggyback_proof(ife, known_txs, {pb_type, pb_index} = piggyback) do
    with {:ok, proof_materials} <- get_proofs_for_particular_ife(ife, pb_type, known_txs),
         {:ok, proof} <- get_proof_for_particular_piggyback(pb_index, proof_materials) do
      {:ok, prepare_piggyback_challenge_response(ife, piggyback, proof)}
    end
  end

  # gets all proof materials for all possibly invalid piggybacks for a single ife, for a determined type (input/output)
  defp get_proofs_for_particular_ife(ife, pb_type, known_txs) do
    invalid_piggybacks_by_ife(known_txs, pb_type, [ife])
    |> case do
      [] -> {:error, :no_double_spend_on_particular_piggyback}
      # ife and pb_type are pinned here for a runtime sanity check - we got what we explicitly asked for
      [{^ife, ^pb_type, proof_materials}] -> {:ok, proof_materials}
    end
  end

  # gets any proof of a particular invalid piggyback, after we have figured the exact piggyback index affected
  defp get_proof_for_particular_piggyback(pb_index, proof_materials) do
    proof_materials
    |> Map.get(pb_index)
    |> case do
      nil -> {:error, :no_double_spend_on_particular_piggyback}
      # any challenging tx will do, taking the very first
      [proof | _] -> {:ok, proof}
    end
  end

  @spec prepare_piggyback_challenge_response(InFlightExitInfo.t(), piggyback_t(), DoubleSpend.t()) ::
          input_challenge_data() | output_challenge_data()
  defp prepare_piggyback_challenge_response(ife, {:input, input_index}, proof) do
    %{
      in_flight_txbytes: Transaction.raw_txbytes(ife.tx),
      in_flight_input_index: input_index,
      spending_txbytes: Transaction.raw_txbytes(proof.known_tx.signed_tx),
      spending_input_index: proof.known_spent_index,
      spending_sig: Enum.at(proof.known_tx.signed_tx.sigs, proof.known_spent_index)
    }
  end

  defp prepare_piggyback_challenge_response(ife, {:output, _output_index}, proof) do
    {_, inclusion_proof} = ife.tx_seen_in_blocks_at

    %{
      in_flight_txbytes: Transaction.raw_txbytes(ife.tx),
      in_flight_output_pos: proof.utxo_pos,
      in_flight_proof: inclusion_proof,
      spending_txbytes: Transaction.raw_txbytes(proof.known_tx.signed_tx),
      spending_input_index: proof.known_spent_index,
      spending_sig: Enum.at(proof.known_tx.signed_tx.sigs, proof.known_spent_index)
    }
  end

  # respec
  @spec get_invalid_piggybacks_events(ExitProcessor.Request.t(), __MODULE__.t()) :: list(Event.InvalidPiggyback.t())
  defp get_invalid_piggybacks_events(
         %ExitProcessor.Request{blocks_result: blocks},
         %__MODULE__{in_flight_exits: ifes} = state
       ) do
    known_txs = get_known_txs(state) ++ get_known_txs(blocks)

    ifes
    |> Map.values()
    |> all_invalid_piggybacks_by_ife(known_txs)
    |> group_by_txbytes()
    |> materials_to_events()
  end

  defp all_invalid_piggybacks_by_ife(ifes_values, known_txs),
    do: [:input, :output] |> Enum.flat_map(fn pb_type -> invalid_piggybacks_by_ife(known_txs, pb_type, ifes_values) end)

  # we need to produce only one event per IFE, with both piggybacks on inputs and outputs
  defp group_by_txbytes(invalid_piggybacks) do
    invalid_piggybacks
    |> Enum.map(fn {ife, type, materials} -> {Transaction.raw_txbytes(ife.tx), type, materials} end)
    |> Enum.group_by(&elem(&1, 0), fn {_, type, materials} -> {type, materials} end)
  end

  defp materials_to_events(invalid_piggybacks_by_txbytes) do
    invalid_piggybacks_by_txbytes
    |> Enum.map(fn {txbytes, type_materials_pairs} ->
      %Event.InvalidPiggyback{
        txbytes: txbytes,
        inputs: invalid_piggyback_indices(type_materials_pairs, :input),
        outputs: invalid_piggyback_indices(type_materials_pairs, :output)
      }
    end)
  end

  defp invalid_piggyback_indices(type_materials_pairs, pb_type) do
    # here we need to additionally group the materials found by type input/output
    # then we gut just the list of indices to present to the user in the event
    type_materials_pairs
    |> Enum.filter(fn {type, _materials} -> type == pb_type end)
    |> Enum.flat_map(fn {_type, materials} -> Map.keys(materials) end)
  end

  @spec invalid_piggybacks_by_ife(list(KnownTx.t()), piggyback_type_t(), list(InFlightExitInfo.t())) ::
          list({InFlightExitInfo.t(), piggyback_type_t(), %{non_neg_integer => DoubleSpend.t()}})
  defp invalid_piggybacks_by_ife(known_txs, pb_type, ifes) do
    known_txs = :lists.usort(known_txs)

    # getting invalid piggybacks on inputs
    ifes
    |> Enum.map(&InFlightExitInfo.indexed_piggybacks_by_ife(&1, pb_type))
    |> Enum.filter(&ife_has_something?/1)
    |> Enum.map(fn {ife, indexed_piggybacked_utxo_positions} ->
      proof_materials = all_double_spends_by_index(indexed_piggybacked_utxo_positions, known_txs, ife)
      {ife, pb_type, proof_materials}
    end)
    |> Enum.filter(&ife_has_something?/1)
  end

  defp ife_has_something?({_ife, finds_for_ife}), do: !Enum.empty?(finds_for_ife)
  defp ife_has_something?({_ife, _, finds_for_ife}), do: !Enum.empty?(finds_for_ife)

  defp all_double_spends_by_index(indexed_utxo_positions, known_txs, ife) do
    # Will find all spenders of provided indexed inputs.
    known_txs
    |> Enum.filter(&txs_different(ife.tx, &1.signed_tx))
    |> Enum.flat_map(&double_spends_from_known_tx(indexed_utxo_positions, &1))
    |> Enum.group_by(& &1.index)
  end

  @spec get_piggyback_challenge_data(ExitProcessor.Request.t(), __MODULE__.t(), binary(), piggyback_t()) ::
          {:ok, input_challenge_data() | output_challenge_data()} | {:error, piggyback_challenge_data_error()}
  defp get_piggyback_challenge_data(%ExitProcessor.Request{blocks_result: blocks}, state, txbytes, piggyback) do
    with {:ok, tx} <- Transaction.decode(txbytes),
         {:ok, ife} <- get_ife(tx, state) do
      known_txs = get_known_txs(blocks) ++ get_known_txs(state)
      produce_invalid_piggyback_proof(ife, known_txs, piggyback)
    end
  end

  # Gets the list of open IFEs that have the competitors _somewhere_
  @spec get_ife_txs_with_competitors(ExitProcessor.Request.t(), __MODULE__.t()) :: list(binary())
  defp get_ife_txs_with_competitors(
         %ExitProcessor.Request{blocks_result: blocks},
         %__MODULE__{in_flight_exits: ifes} = state
       ) do
    known_txs = get_known_txs(blocks) ++ get_known_txs(state)

    ifes
    |> Map.values()
    # TODO: expensive!
    |> Stream.map(fn ife -> {ife, Enum.find_value(known_txs, &competitor_for(ife.tx, &1))} end)
    |> Stream.filter(fn {_ife, double_spend} -> !is_nil(double_spend) end)
    |> Stream.filter(fn {ife, %DoubleSpend{known_tx: %KnownTx{utxo_pos: utxo_pos}}} ->
      InFlightExitInfo.is_viable_competitor?(ife, utxo_pos)
    end)
    |> Stream.map(fn {ife, _double_spend} -> Transaction.raw_txbytes(ife.tx) end)
    |> Enum.uniq()
  end

  # Gets the list of open IFEs that have the competitors _somewhere_
  @spec get_invalid_ife_challenges(t()) :: list(binary())
  defp get_invalid_ife_challenges(%__MODULE__{in_flight_exits: ifes}) do
    ifes
    |> Map.values()
    |> Stream.filter(&InFlightExitInfo.is_invalidly_challenged?/1)
    |> Stream.map(&Transaction.raw_txbytes(&1.tx))
    |> Enum.uniq()
  end

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
    {:ok, input_owners} = Transaction.Signed.get_spenders(signed_tx)

    available_inputs =
      input_owners
      |> Enum.filter(&zero_address?/1)
      |> Enum.with_index()
      |> Enum.filter(fn {_, index} -> not InFlightExitInfo.is_input_piggybacked?(ife, index) end)
      |> Enum.map(fn {owner, index} -> %{index: index, address: owner} end)

    available_outputs =
      outputs
      |> Enum.filter(fn %{owner: owner} -> zero_address?(owner) end)
      |> Enum.with_index()
      |> Enum.filter(fn {_, index} -> not InFlightExitInfo.is_output_piggybacked?(ife, index) end)
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

  defp prepare_in_flight_exit({txhash, ife_info}) do
    %{tx: tx, eth_height: eth_height} = ife_info

    %{
      txhash: txhash,
      txbytes: Transaction.raw_txbytes(tx),
      eth_height: eth_height,
      piggybacked_inputs: InFlightExitInfo.piggybacked_inputs(ife_info),
      piggybacked_outputs: InFlightExitInfo.piggybacked_outputs(ife_info)
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
    updated_ifes =
      ifes
      |> Enum.filter(fn {_, ife} -> ife.tx_seen_in_blocks_at == nil end)
      |> Enum.map(fn {hash, ife} -> {hash, ife, find_ife_in_blocks(ife, blocks)} end)
      |> Enum.filter(fn {_hash, _ife, maybepos} -> maybepos != nil end)
      |> Enum.map(fn {hash, ife, {block, position}} ->
        proof = Block.inclusion_proof(block, Utxo.Position.txindex(position))
        {hash, %InFlightExitInfo{ife | tx_seen_in_blocks_at: {position, proof}}}
      end)
      |> Map.new()

    %{state | in_flight_exits: Map.merge(ifes, updated_ifes)}
  end

  defp find_ife_in_blocks(ife, blocks) do
    txbody = Transaction.Signed.encode(ife.tx)

    search_in_block = fn block, _ ->
      case find_tx_in_block(txbody, block) do
        nil ->
          {:cont, nil}

        txindex ->
          {:halt, {block, Utxo.position(block.number, txindex, 0)}}
      end
    end

    blocks
    |> Enum.filter(&(&1 != :not_found))
    |> sort_blocks()
    |> Enum.reduce_while(nil, search_in_block)
  end

  defp find_tx_in_block(txbody, block) do
    block.transactions
    |> Enum.find_index(fn tx -> txbody == tx end)
  end

  @doc """
  Gets the root chain contract-required set of data to challenge a non-canonical ife
  """
  @spec get_competitor_for_ife(ExitProcessor.Request.t(), __MODULE__.t(), binary()) ::
          {:ok, competitor_data_t()} | {:error, :competitor_not_found} | {:error, :no_viable_competitor_found}
  def get_competitor_for_ife(
        %ExitProcessor.Request{blocks_result: blocks},
        %__MODULE__{} = state,
        ife_txbytes
      ) do
    known_txs = get_known_txs(blocks) ++ get_known_txs(state)

    # find its competitor and use it to prepare the requested data
    with {:ok, ife_tx} <- Transaction.decode(ife_txbytes),
         {:ok, ife} <- get_ife(ife_tx, state),
         {:ok, double_spend} <- find_competitor(known_txs, ife.tx),
         %DoubleSpend{known_tx: %KnownTx{utxo_pos: utxo_pos}} = double_spend,
         true <- InFlightExitInfo.is_viable_competitor?(ife, utxo_pos) || {:error, :no_viable_competitor_found},
         do: {:ok, prepare_competitor_response(double_spend, ife.tx, blocks)}
  end

  @doc """
  Gets the root chain contract-required set of data to challenge an ife appearing as non-canonical in the root chain
  contract but which is known to be canonical locally because included in one of the blocks
  """
  @spec prove_canonical_for_ife(t(), binary()) ::
          {:ok, prove_canonical_data_t()} | {:error, :no_viable_canonical_proof_found}
  def prove_canonical_for_ife(%__MODULE__{} = state, ife_txbytes) do
    with {:ok, raw_ife_tx} <- Transaction.decode(ife_txbytes),
         {:ok, ife} <- get_ife(raw_ife_tx, state),
         true <- InFlightExitInfo.is_invalidly_challenged?(ife) || {:error, :no_viable_canonical_proof_found},
         do: {:ok, prepare_canonical_response(ife)}
  end

  defp prepare_competitor_response(
         %DoubleSpend{
           index: in_flight_input_index,
           known_spent_index: competing_input_index,
           known_tx: %KnownTx{signed_tx: known_signed_tx, utxo_pos: known_tx_utxo_pos}
         },
         signed_ife_tx,
         blocks
       ) do
    {:ok, input_owners} = Transaction.Signed.get_spenders(signed_ife_tx)

    owner = Enum.at(input_owners, in_flight_input_index)

    %{
      in_flight_txbytes: signed_ife_tx |> Transaction.raw_txbytes(),
      in_flight_input_index: in_flight_input_index,
      competing_txbytes: known_signed_tx |> Transaction.raw_txbytes(),
      competing_input_index: competing_input_index,
      competing_sig: find_sig!(known_signed_tx, owner),
      competing_tx_pos: known_tx_utxo_pos || Utxo.position(0, 0, 0),
      competing_proof: maybe_calculate_proof(known_tx_utxo_pos, blocks)
    }
  end

  defp prepare_canonical_response(%InFlightExitInfo{tx: tx, tx_seen_in_blocks_at: {pos, proof}}),
    do: %{in_flight_txbytes: Transaction.raw_txbytes(tx), in_flight_tx_pos: pos, in_flight_proof: proof}

  defp maybe_calculate_proof(nil, _), do: <<>>

  defp maybe_calculate_proof(Utxo.position(blknum, txindex, _), blocks) do
    blocks
    |> Enum.find(fn %Block{number: number} -> blknum == number end)
    |> Block.inclusion_proof(txindex)
  end

  defp find_competitor(known_txs, signed_ife_tx) do
    known_txs
    |> Enum.find_value(fn known -> competitor_for(signed_ife_tx, known) end)
    |> case do
      nil -> {:error, :competitor_not_found}
      value -> {:ok, value}
    end
  end

  # Tells whether a single transaction is a competitor for another single transactions, by returning nil or the
  # `DoubleSpend` information package if the `known_tx` is in fact a competitor
  # Returns single result, even if there are multiple double-spends!
  defp competitor_for(tx, %KnownTx{signed_tx: known_signed_tx} = known_tx) do
    with true <- txs_different(tx, known_signed_tx) || nil,
         double_spends = tx |> Transaction.get_inputs() |> Enum.with_index() |> double_spends_from_known_tx(known_tx),
         true <- !Enum.empty?(double_spends) || nil,
         do: hd(double_spends)
  end

  defp txs_different(tx1, tx2), do: Transaction.raw_txhash(tx1) != Transaction.raw_txhash(tx2)

  defp get_known_txs(%__MODULE__{} = state) do
    TxAppendix.get_all(state)
    |> Enum.map(fn signed -> %KnownTx{signed_tx: signed} end)
  end

  defp get_known_txs(%Block{transactions: txs, number: blknum}) do
    txs
    |> Enum.map(fn tx_bytes ->
      {:ok, signed} = Transaction.Signed.decode(tx_bytes)
      signed
    end)
    |> Enum.with_index()
    |> Enum.map(fn {signed, txindex} -> %KnownTx{signed_tx: signed, utxo_pos: Utxo.position(blknum, txindex, 0)} end)
  end

  defp get_known_txs(blocks) when is_list(blocks), do: blocks |> sort_blocks() |> Enum.flat_map(&get_known_txs/1)

  # we're sorting the blocks by their blknum here, because we wan't oldest (best) competitors first always
  defp sort_blocks(blocks), do: blocks |> Enum.sort_by(fn %Block{number: number} -> number end)

  defp zero_address?(address) do
    address != @zero_address
  end

  defp get_ife(ife_tx, %__MODULE__{in_flight_exits: ifes}) do
    case ifes[Transaction.raw_txhash(ife_tx)] do
      nil -> {:error, :ife_not_known_for_tx}
      value -> {:ok, value}
    end
  end
end
