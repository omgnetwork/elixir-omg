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

defmodule OMG.Watcher.ExitProcessor.Core do
  @moduledoc """
  The functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - MoreVP protocol managing should go here
  """

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.ExitProcessor.Tools
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.CompetitorInfo
  alias OMG.Watcher.ExitProcessor.Challenge
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.ExitProcessor.Tools
  alias OMG.Watcher.ExitProcessor.TxAppendix

  @default_sla_margin 10
  @zero_address Crypto.zero_address()

  @type tx_hash() :: <<_::32>>
  @type output_offset() :: 0..7

  defstruct [:sla_margin, exits: %{}, in_flight_exits: %{}, competitors: %{}]

  @type t :: %__MODULE__{
          sla_margin: non_neg_integer(),
          exits: %{Utxo.Position.t() => ExitInfo.t()},
          in_flight_exits: %{tx_hash() => InFlightExitInfo.t()},
          competitors: %{tx_hash() => CompetitorInfo.t()}
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

  defmodule KnownTx do
    @moduledoc """
    Wrapps information about a particular signed transaction known from somewhere, optionally with its UTXO position

    Private
    """
    defstruct [:signed_tx, :utxo_pos]

    @type t() :: %__MODULE__{
            signed_tx: Transaction.Signed.t(),
            utxo_pos: Utxo.Position.t()
          }
  end

  @doc """
  Reads database-specific list of exits and turns them into current state
  """
  @spec init(
          db_exits :: [{{pos_integer, non_neg_integer, non_neg_integer}, map}],
          db_in_flight_exits :: [{tx_hash(), InFlightExitInfo.t()}],
          db_competitors :: [{tx_hash(), CompetitorInfo.t()}],
          sla_margin :: non_neg_integer
        ) :: {:ok, t()}
  def init(db_exits, db_in_flight_exits, db_competitors, sla_margin \\ @default_sla_margin) do
    {:ok,
     %__MODULE__{
       exits:
         db_exits
         |> Enum.map(fn {db_utxo_pos, v} ->
           {Utxo.Position.from_db_key(db_utxo_pos), struct!(ExitInfo, v)}
         end)
         |> Map.new(),
       in_flight_exits: db_in_flight_exits |> Map.new(),
       competitors: db_competitors |> Map.new(),
       sla_margin: sla_margin
     }}
  end

  @doc """
  Add new exits from Ethereum events into tracked state.

  The list of `exit_contract_statuses` is used to track current (as in wall-clock "now", not syncing "now") status.
  This is to prevent spurious invalid exit events being fired during syncing for exits that were challenged/finalized
  Still we do want to track these exits when syncing, to have them spend from `OMG.API.State` on their finalization
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
      |> Enum.map(fn {%{utxo_pos: utxo_pos} = exit_info, contract_status} ->
        is_active = parse_contract_exit_status(contract_status)
        map_exit_info = exit_info |> Map.delete(:utxo_pos) |> Map.put(:is_active, is_active)
        {Utxo.Position.decode(utxo_pos), struct!(ExitInfo, map_exit_info)}
      end)

    db_updates =
      new_exits_kv_pairs
      |> Enum.map(&ExitInfo.make_db_update/1)

    new_exits_map = Map.new(new_exits_kv_pairs)

    {%{state | exits: Map.merge(exits, new_exits_map)}, db_updates}
  end

  defp parse_contract_exit_status({@zero_address, _contract_token, _contract_amount}), do: false
  defp parse_contract_exit_status({_contract_owner, _contract_token, _contract_amount}), do: true

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
    new_ifes_kv_pairs =
      new_ifes_events
      |> Enum.zip(contract_statuses)
      |> Enum.map(fn {%{eth_height: eth_height, call_data: %{in_flight_tx: tx_bytes, in_flight_tx_sigs: signatures}},
                      {timestamp, contract_ife_id} = contract_status} ->
        is_active = parse_contract_in_flight_exit_status(contract_status)
        InFlightExitInfo.new(tx_bytes, signatures, contract_ife_id, timestamp, is_active, eth_height)
      end)

    db_updates =
      new_ifes_kv_pairs
      |> Enum.map(&InFlightExitInfo.make_db_update/1)

    new_ifes = new_ifes_kv_pairs |> Map.new()

    {%{state | in_flight_exits: Map.merge(ifes, new_ifes)}, db_updates}
  end

  defp parse_contract_in_flight_exit_status({timestamp, _contract_id}), do: timestamp != 0

  @doc """
    Add piggybacks from Ethereum events into tracked state.
  """
  @spec new_piggybacks(t(), [%{tx_hash: tx_hash(), output_index: output_offset()}]) :: {t(), list()}
  def new_piggybacks(%__MODULE__{} = state, piggybacks) do
    {updated_state, updated_pairs} = Enum.reduce(piggybacks, {state, %{}}, &process_piggyback/2)
    {updated_state, Enum.map(updated_pairs, &InFlightExitInfo.make_db_update/1)}
  end

  defp process_piggyback(
         %{tx_hash: tx_hash, output_index: output_index},
         {%__MODULE__{in_flight_exits: ifes} = state, db_updates}
       ) do
    {:ok, ife} = Map.fetch(ifes, tx_hash)
    {:ok, updated_ife} = InFlightExitInfo.piggyback(ife, output_index)

    updated_state = %{state | in_flight_exits: Map.put(ifes, tx_hash, updated_ife)}
    {updated_state, Map.put(db_updates, tx_hash, updated_ife)}
  end

  @doc """
  Finalize exits based on Ethereum events, removing from tracked state if valid.

  Invalid finalizing exits should continue being tracked as `is_active`, to continue emitting events.
  This includes non-`is_active` exits that finalize invalid, which are turned to be `is_active` now.
  """
  @spec finalize_exits(t(), validities :: {list(Utxo.Position.t()), list(Utxo.Position.t())}) :: {t(), list()}
  def finalize_exits(%__MODULE__{exits: exits} = state, {valid_finalizations, invalid}) do
    # handling valid finalizations
    state = %{state | exits: Map.drop(exits, valid_finalizations)}
    db_updates = delete_positions(valid_finalizations)

    {state, activating_db_updates} = activate_on_invalid_finalization(state, invalid)

    {state, db_updates ++ activating_db_updates}
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
    |> Enum.map(fn %{utxo_pos: utxo_pos} = _finalization_info -> Utxo.Position.decode(utxo_pos) end)
  end

  defp delete_positions(utxo_positions),
    do: utxo_positions |> Enum.map(&{:delete, :exit_info, Utxo.Position.to_db_key(&1)})

  # TODO: simplify flow
  # https://github.com/omisego/elixir-omg/pull/361#discussion_r247481397
  @spec new_ife_challenges(t(), [map()]) :: {t(), list()}
  def new_ife_challenges(%__MODULE__{in_flight_exits: ifes, competitors: competitors} = state, challenges_events) do
    challenges =
      challenges_events
      |> Enum.map(fn %{
                       call_data: %{
                         competing_tx: competing_tx_bytes,
                         competing_tx_input_index: competing_input_index,
                         competing_tx_sig: signature
                       }
                     } ->
        CompetitorInfo.new(competing_tx_bytes, competing_input_index, signature)
      end)

    new_competitors = challenges |> Map.new()
    competitors_db_updates = challenges |> Enum.map(&CompetitorInfo.make_db_update/1)

    updated_ifes =
      challenges_events
      |> Enum.map(fn %{tx_hash: tx_hash, competitor_position: position} ->
        updated_ife = ifes |> Map.fetch!(tx_hash) |> InFlightExitInfo.challenge(position)
        {tx_hash, updated_ife}
      end)

    ife_db_updates = updated_ifes |> Enum.map(&InFlightExitInfo.make_db_update/1)

    state = %{
      state
      | competitors: Map.merge(competitors, new_competitors),
        in_flight_exits: Map.merge(ifes, Map.new(updated_ifes))
    }

    {state, competitors_db_updates ++ ife_db_updates}
  end

  @spec respond_to_in_flight_exits_challenges(t(), [map()]) :: {t(), list()}
  def respond_to_in_flight_exits_challenges(%__MODULE__{in_flight_exits: _ifes} = state, _responds_events) do
    # TODO: implement and test (in InFlightExitInfo callback is already written)
    {state, []}
  end

  # TODO: simplify flow
  # https://github.com/omisego/elixir-omg/pull/361#discussion_r247483185
  @spec challenge_piggybacks(t(), [map()]) :: {t(), list()}
  def challenge_piggybacks(%__MODULE__{in_flight_exits: ifes} = state, challenges) do
    ifes_to_update =
      challenges
      |> Enum.map(fn %{tx_hash: tx_hash} -> tx_hash end)
      |> (&Map.take(ifes, &1)).()
      # initialises all ifes as not updated
      |> Enum.map(fn {key, value} -> {key, {value, false}} end)
      |> Map.new()

    updated_ifes =
      challenges
      |> Enum.reduce(ifes_to_update, fn %{tx_hash: tx_hash, output_index: output_index}, acc ->
        with {:ok, {ife, _}} <- Map.fetch(acc, tx_hash),
             {:ok, updated_ife} <- InFlightExitInfo.challenge_piggyback(ife, output_index) do
          # mark as updated
          %{acc | tx_hash => {updated_ife, true}}
        else
          _ -> acc
        end
      end)
      |> Enum.reduce([], fn
        {tx_hash, {ife, true}}, acc -> [{tx_hash, ife} | acc]
        _, acc -> acc
      end)
      |> Map.new()

    db_updates = updated_ifes |> Enum.map(&InFlightExitInfo.make_db_update/1)

    {%{state | in_flight_exits: Map.merge(ifes, updated_ifes)}, db_updates}
  end

  # NOTE: write tests - OMG-381
  # TODO: simplify flow
  # https://github.com/omisego/elixir-omg/pull/361#discussion_r247485778
  @spec finalize_in_flight_exits(t(), [map()]) :: {t(), list()}
  def finalize_in_flight_exits(%__MODULE__{in_flight_exits: ifes} = state, finalizations) do
    ifes_to_update =
      finalizations
      |> Enum.reduce(%{}, fn %{in_flight_exit_id: id}, acc ->
        with :not_found <-
               Enum.find(ifes, :not_found, fn {_tx_hash, %InFlightExitInfo{contract_id: contract_id}} ->
                 id == contract_id
               end) do
          acc
        else
          # map by id from contract and mark as not updated
          {tx_hash, ife} ->
            %{acc | id => {tx_hash, ife, false}}
        end
      end)

    updated_ifes =
      finalizations
      |> Enum.reduce(ifes_to_update, fn %{in_flight_exit_id: id, output_index: output}, acc ->
        with {:ok, {tx_hash, ife, _}} <- Enum.fetch(acc, id),
             {:ok, updated_ife} <- InFlightExitInfo.finalize(ife, output) do
          # update value and flag as updated
          %{acc | id => {tx_hash, updated_ife, true}}
        else
          _ -> acc
        end
      end)
      |> Enum.reduce([], fn
        {_, {tx_hash, ife, true}}, acc -> [{tx_hash, ife} | acc]
        _, acc -> acc
      end)
      |> Map.new()

    db_updates = updated_ifes |> Enum.map(&InFlightExitInfo.make_db_update/1)

    {%{state | in_flight_exits: Map.merge(ifes, updated_ifes)}, db_updates}
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

  defp do_determine_utxo_existence_to_get(%__MODULE__{exits: exits, in_flight_exits: ifes}, blknum_now) do
    standard_exits_pos =
      exits
      |> Enum.filter(fn {_key, %ExitInfo{is_active: is_active}} -> is_active end)
      |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)

    ife_pos =
      ifes
      |> Enum.flat_map(fn {_, ife} -> InFlightExitInfo.get_exiting_utxo_positions(ife) end)

    (ife_pos ++ standard_exits_pos)
    |> Enum.filter(&Utxo.Position.non_zero?/1)
    |> Enum.filter(fn Utxo.position(blknum, _, _) -> blknum < blknum_now end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Figures out which numbers of "spending transaction blocks" to get for the utxos, based on the existence reported by
  `OMG.API.State` and possibly other factors, eg. only take the non-existent UTXOs spends (naturally) and ones that
  pertain to IFE transaction inputs.

  Assmues that UTXOs that haven't been checked at all **exist**
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
      |> Enum.filter(& &1.is_active)
      |> Enum.flat_map(fn %{tx: %Transaction.Signed{raw_tx: tx}} -> Transaction.get_inputs(tx) end)
      |> only_utxos_checked_and_missing(utxo_exists?)
      |> Enum.uniq()

    %{request | spends_to_get: spends_to_get}
  end

  @doc """
  Figures out which block numbers to ask from the database, based on the blknums where relevant UTXOs were spent and
  (in the future) some additional insights from the state of ExitProcessor (eg. only get the oldest block per ife)

  This function must return blocks that satisfy following criteria:
    1/ blocks where any input to any IFE was spent
    2/ blocks where any output to any IFE was spent
    3/ blocks where the whole IFE transaction **might've** been included, to get piggyback availability and to get InvalidIFEChallenge's

  """
  @spec determine_blocks_to_get(ExitProcessor.Request.t()) :: ExitProcessor.Request.t()
  def determine_blocks_to_get(
        %ExitProcessor.Request{
          spent_blknum_result: spent_blknum_result
        } = request
      ) do
    # TODO: consider Enum.uniq here
    %{request | blknums_to_get: spent_blknum_result}
  end

  @doc """
  Based on the result of exit validity (utxo existence), return invalid exits or appropriate notifications

  NOTE: We're using `ExitStarted`-height with `sla_exit_margin` added on top, to determine old, unchallenged invalid
        exits. This is different than documented, according to what we ought to be using
        `exitable_at - sla_exit_margin_s` to determine such exits.

  NOTE: If there were any exits unchallenged for some time in chain history, this might detect breach of SLA,
        even if the exits were eventually challenged (e.g. during syncing)
  """
  @spec invalid_exits(ExitProcessor.Request.t(), t()) :: check_validity_result_t()
  def invalid_exits(
        %ExitProcessor.Request{
          eth_height_now: eth_height_now,
          utxos_to_check: utxos_to_check,
          utxo_exists_result: utxo_exists_result
        } = request,
        %__MODULE__{exits: exits, sla_margin: sla_margin} = state
      )
      when is_integer(eth_height_now) do
    utxo_exists? = Enum.zip(utxos_to_check, utxo_exists_result) |> Map.new()

    invalid_exit_positions =
      exits
      |> Enum.filter(fn {_key, %ExitInfo{is_active: is_active}} -> is_active end)
      |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)
      |> only_utxos_checked_and_missing(utxo_exists?)

    # get exits which are still invalid and after the SLA margin
    late_invalid_exits =
      exits
      |> Map.take(invalid_exit_positions)
      |> Enum.filter(fn {_, %ExitInfo{eth_height: eth_height}} -> eth_height + sla_margin <= eth_height_now end)

    has_no_late_invalid_exits = Enum.empty?(late_invalid_exits)

    non_late_events =
      invalid_exit_positions
      |> Enum.map(fn position -> ExitInfo.make_event_data(Event.InvalidExit, position, exits[position]) end)

    # get exits which are invalid because of being spent in IFEs
    invalid_exits_based_on_ifes_events =
      get_invalid_exits_based_on_ifes(state)
      |> Enum.map(fn {position, exit_info} -> ExitInfo.make_event_data(Event.InvalidExit, position, exit_info) end)

    ifes_with_competitors_events =
      get_ifes_with_competitors(request, state)
      |> Enum.map(fn txbytes -> %Event.NonCanonicalIFE{txbytes: txbytes} end)

    invalid_ife_challenges_events =
      get_invalid_ife_challenges(request, state)
      |> Enum.map(fn txbytes -> %Event.InvalidIFEChallenge{txbytes: txbytes} end)

    available_piggybacks_events =
      get_ifes_to_piggyback(request, state)
      |> Enum.map(&prepare_available_piggyback/1)

    late_invalid_exits_events =
      late_invalid_exits
      |> Enum.map(fn {position, late_exit} -> ExitInfo.make_event_data(Event.UnchallengedExit, position, late_exit) end)

    invalid_exit_events =
      invalid_exits_based_on_ifes_events
      |> Enum.concat(non_late_events)
      |> Enum.uniq_by(fn %Event.InvalidExit{utxo_pos: utxo_pos} -> utxo_pos end)

    events =
      [
        invalid_exit_events,
        late_invalid_exits_events,
        ifes_with_competitors_events,
        invalid_ife_challenges_events,
        available_piggybacks_events
      ]
      |> Enum.concat()

    chain_validity = if has_no_late_invalid_exits, do: :ok, else: {:error, :unchallenged_exit}

    {chain_validity, events}
  end

  defp get_invalid_exits_based_on_ifes(%__MODULE__{exits: exits} = state) do
    exiting_utxo_positions =
      get_known_txs(state)
      |> Enum.flat_map(fn %KnownTx{signed_tx: %Transaction.Signed{raw_tx: %Transaction{} = tx}} ->
        Transaction.get_inputs(tx)
      end)

    exits
    |> Enum.filter(fn {utxo_pos, _exit_info} ->
      Enum.find(exiting_utxo_positions, fn exiting_utxo_pos -> utxo_pos == exiting_utxo_pos end)
    end)
  end

  # Gets the list of open IFEs that have the competitors _somewhere_
  @spec get_ifes_with_competitors(ExitProcessor.Request.t(), __MODULE__.t()) :: list(binary())
  defp get_ifes_with_competitors(
         %ExitProcessor.Request{blocks_result: blocks},
         %__MODULE__{in_flight_exits: ifes} = state
       ) do
    known_txs = get_known_txs(blocks) ++ get_known_txs(state)

    ifes
    |> Map.values()
    |> Stream.filter(&InFlightExitInfo.is_canonical?/1)
    |> Stream.map(fn %InFlightExitInfo{tx: tx} -> tx end)
    # TODO: expensive!
    |> Stream.filter(fn tx -> known_txs |> Enum.find(&competitor_for(tx, &1)) end)
    |> Stream.map(fn %{raw_tx: raw_tx} -> Transaction.encode(raw_tx) end)
    |> Enum.uniq()
  end

  # Gets the list of open IFEs that have the competitors _somewhere_
  @spec get_invalid_ife_challenges(ExitProcessor.Request.t(), __MODULE__.t()) :: list(binary())
  defp get_invalid_ife_challenges(
         %ExitProcessor.Request{blocks_result: blocks},
         %__MODULE__{in_flight_exits: ifes}
       ) do
    known_txs = get_known_txs(blocks)

    ifes
    |> Map.values()
    |> Stream.filter(&(not InFlightExitInfo.is_canonical?(&1)))
    |> Stream.map(fn %InFlightExitInfo{tx: %Transaction.Signed{raw_tx: raw_tx}} -> raw_tx end)
    # TODO: expensive!
    |> Stream.filter(fn raw_tx ->
      is_among_known_txs?(raw_tx, known_txs)
    end)
    |> Stream.map(&Transaction.encode/1)
    |> Enum.uniq()
  end

  @spec get_ifes_to_piggyback(ExitProcessor.Request.t(), __MODULE__.t()) :: list(Transaction.Signed.t())
  defp get_ifes_to_piggyback(
         %ExitProcessor.Request{blocks_result: blocks},
         %__MODULE__{in_flight_exits: ifes}
       ) do
    known_txs = get_known_txs(blocks)

    ifes
    |> Map.values()
    |> Stream.map(fn %InFlightExitInfo{tx: signed_tx} -> signed_tx end)
    # TODO: expensive!
    |> Stream.filter(fn %Transaction.Signed{raw_tx: raw_tx} ->
      !is_among_known_txs?(raw_tx, known_txs)
    end)
    |> Enum.uniq()
  end

  @spec prepare_available_piggyback(Transaction.Signed.t()) :: Event.PiggybackAvailable.t()
  defp prepare_available_piggyback(%Transaction.Signed{raw_tx: %Transaction{outputs: outputs} = tx} = signed_tx) do
    {:ok, %Transaction.Recovered{spenders: input_owners}} = Transaction.Recovered.recover_from(signed_tx)

    available_inputs =
      input_owners
      |> Enum.filter(&zero_address?/1)
      |> Enum.with_index()
      |> Enum.map(fn {owner, index} -> %{index: index, address: owner} end)

    available_outputs =
      outputs
      |> Enum.filter(fn %{owner: owner} -> zero_address?(owner) end)
      |> Enum.with_index()
      |> Enum.map(fn {%{owner: owner}, index} -> %{index: index, address: owner} end)

    %Event.PiggybackAvailable{
      txbytes: Transaction.encode(tx),
      available_outputs: available_outputs,
      available_inputs: available_inputs
    }
  end

  @doc """
  Returns a map of all in flight exits, where keys are IFE hashes and values are IFES
  """
  @spec get_in_flight_exits(__MODULE__.t()) :: list(map)
  def get_in_flight_exits(%__MODULE__{in_flight_exits: ifes}) do
    ifes
    |> Enum.map(&get_in_flight_exit/1)
  end

  defp get_in_flight_exit({txhash, ife_info}) do
    %{tx: %Transaction.Signed{raw_tx: raw_tx}, eth_height: eth_height} = ife_info

    %{
      txhash: txhash,
      txbytes: Transaction.encode(raw_tx),
      eth_height: eth_height,
      piggybacked_inputs: InFlightExitInfo.piggybacked_inputs(ife_info),
      piggybacked_outputs: InFlightExitInfo.piggybacked_outputs(ife_info)
    }
  end

  @doc """
  Gets the root chain contract-required set of data to challenge a non-canonical ife
  """
  @spec get_competitor_for_ife(ExitProcessor.Request.t(), __MODULE__.t(), binary()) ::
          {:ok, competitor_data_t()} | {:error, :competitor_not_found}
  def get_competitor_for_ife(
        %ExitProcessor.Request{blocks_result: blocks},
        %__MODULE__{} = state,
        ife_txbytes
      ) do
    known_txs = get_known_txs(blocks) ++ get_known_txs(state)

    # find its competitor and use it to prepare the requested data
    with {:ok, %InFlightExitInfo{tx: %Transaction.Signed{} = signed_ife_tx}} <- get_ife(ife_txbytes, state),
         {:ok, known_signed_tx} <- find_competitor(known_txs, signed_ife_tx),
         do: {:ok, prepare_competitor_response(known_signed_tx, signed_ife_tx, blocks)}
  end

  @doc """
  Gets the root chain contract-required set of data to challenge an ife appearing as non-canonical in the root chain
  contract but which is known to be canonical locally because included in one of the blocks
  """
  @spec prove_canonical_for_ife(ExitProcessor.Request.t(), binary()) ::
          {:ok, prove_canonical_data_t()} | {:error, :canonical_not_found}
  def prove_canonical_for_ife(
        %ExitProcessor.Request{blocks_result: blocks},
        ife_txbytes
      ) do
    known_txs = get_known_txs(blocks)
    {:ok, raw_ife_tx} = Transaction.decode(ife_txbytes)

    with {:ok, %KnownTx{utxo_pos: known_tx_utxo_pos}} <- find_canonical(known_txs, raw_ife_tx),
         do: {:ok, prepare_canonical_response(ife_txbytes, known_tx_utxo_pos, blocks)}
  end

  defp prepare_competitor_response(
         %KnownTx{signed_tx: known_signed_tx, utxo_pos: known_tx_utxo_pos},
         %Transaction.Signed{raw_tx: raw_ife_tx} = signed_ife_tx,
         blocks
       ) do
    ife_inputs = Transaction.get_inputs(raw_ife_tx) |> Enum.filter(&Utxo.Position.non_zero?/1)

    %Transaction.Signed{raw_tx: raw_known_tx} = known_signed_tx
    known_spent_inputs = Transaction.get_inputs(raw_known_tx) |> Enum.filter(&Utxo.Position.non_zero?/1)
    {:ok, %Transaction.Recovered{spenders: input_owners}} = Transaction.Recovered.recover_from(signed_ife_tx)

    # get info about the double spent input and it's respective indices in transactions
    spent_input = competitor_for(signed_ife_tx, known_signed_tx)
    in_flight_input_index = Enum.find_index(ife_inputs, &(&1 == spent_input))
    competing_input_index = Enum.find_index(known_spent_inputs, &(&1 == spent_input))

    owner = Enum.at(input_owners, in_flight_input_index)

    # if this returns nil it means somethings very wrong - the owner taken (effectively) from the contract
    # doesn't appear to have signed the potential competitor, which means that some prior signature checking was skipped
    {:ok, competing_sig} = Tools.find_sig(known_signed_tx, owner)

    %{
      in_flight_txbytes: raw_ife_tx |> Transaction.encode(),
      in_flight_input_index: in_flight_input_index,
      competing_txbytes: raw_known_tx |> Transaction.encode(),
      competing_input_index: competing_input_index,
      competing_sig: competing_sig,
      competing_tx_pos: known_tx_utxo_pos || Utxo.position(0, 0, 0),
      competing_proof: maybe_calculate_proof(known_tx_utxo_pos, blocks)
    }
  end

  defp prepare_canonical_response(ife_txbytes, known_tx_utxo_pos, blocks) do
    %{
      in_flight_txbytes: ife_txbytes,
      in_flight_tx_pos: known_tx_utxo_pos,
      in_flight_proof: maybe_calculate_proof(known_tx_utxo_pos, blocks)
    }
  end

  defp maybe_calculate_proof(nil, _), do: <<>>

  defp maybe_calculate_proof(Utxo.position(blknum, txindex, _), blocks) do
    blocks
    |> Enum.find(fn %Block{number: number} -> blknum == number end)
    |> Block.inclusion_proof(txindex)
  end

  defp find_competitor(known_txs, signed_ife_tx) do
    known_txs
    |> Enum.find(fn known -> competitor_for(signed_ife_tx, known) end)
    |> case do
      nil -> {:error, :competitor_not_found}
      value -> {:ok, value}
    end
  end

  defp find_canonical(known_txs, raw_ife_tx) do
    known_txs
    |> Enum.find(fn %KnownTx{signed_tx: %Transaction.Signed{raw_tx: block_raw_tx}} -> block_raw_tx == raw_ife_tx end)
    |> case do
      nil -> {:error, :canonical_not_found}
      value -> {:ok, value}
    end
  end

  # tells whether a signle transaction is a competitor for another single transactions, by returning nil or the
  # UTXO position of the input double spent
  defp competitor_for(%Transaction.Signed{raw_tx: raw_tx}, %Transaction{} = known_raw_tx) do
    inputs = Transaction.get_inputs(raw_tx) |> Enum.filter(&Utxo.Position.non_zero?/1)
    known_spent_inputs = Transaction.get_inputs(known_raw_tx) |> Enum.filter(&Utxo.Position.non_zero?/1)

    with true <- Transaction.hash(known_raw_tx) != Transaction.hash(raw_tx),
         Utxo.position(_, _, _) = double_spent_input <- inputs |> Enum.find(&Enum.member?(known_spent_inputs, &1)),
         do: double_spent_input
  end

  # this function doesn't care, if the second argument holds additional information about the utxo position
  defp competitor_for(signed1, %KnownTx{signed_tx: signed2}),
    do: competitor_for(signed1, signed2)

  # it also doesn't care if the second argument is signed or not
  defp competitor_for(signed1, %Transaction.Signed{raw_tx: known_raw_tx}),
    do: competitor_for(signed1, known_raw_tx)

  defp get_known_txs(%__MODULE__{} = state) do
    TxAppendix.get_all(state)
    |> Enum.map(fn signed -> %KnownTx{signed_tx: signed} end)
  end

  defp get_known_txs(%Block{transactions: txs, number: blknum}) do
    txs
    |> Enum.map(fn tx_bytes ->
      %Transaction.Recovered{signed_tx: signed} = recover_correct_tx_from_block(tx_bytes)
      signed
    end)
    |> Enum.with_index()
    |> Enum.map(fn {signed, txindex} -> %KnownTx{signed_tx: signed, utxo_pos: Utxo.position(blknum, txindex, 0)} end)
  end

  defp get_known_txs([]), do: []

  # we're sorting the blocks by their blknum here, because we wan't oldest (best) competitors first always
  defp get_known_txs([%Block{} | _] = blocks),
    do: blocks |> Enum.sort_by(fn block -> block.number end) |> Enum.flat_map(&get_known_txs/1)

  defp recover_correct_tx_from_block(tx_bytes) do
    {:ok, recovered} = OMG.API.Core.recover_tx(tx_bytes)
    recovered
  end

  # based on an enumberable of `Utxo.Position` and a mapping that tells whether one exists it will pick
  # only those that **were checked** and were missing
  # (i.e. those not checked are assumed to be present)
  defp only_utxos_checked_and_missing(utxo_positions, utxo_exists?) do
    # the default value below is true, so that the assumption is that utxo not checked is **present**
    # TODO: rather inefficient, but no as inefficient as the nested `filter` calls in searching for competitors
    #       consider optimizing using `MapSet`
    utxo_positions
    |> Enum.filter(fn pos -> !Map.get(utxo_exists?, pos, true) end)
  end

  defp is_among_known_txs?(raw_tx, known_txs) do
    Enum.find(known_txs, fn %KnownTx{signed_tx: %Transaction.Signed{raw_tx: block_raw_tx}} ->
      raw_tx == block_raw_tx
    end)
  end

  defp zero_address?(address) do
    address != Crypto.zero_address()
  end

  defp get_ife(txbytes, %__MODULE__{in_flight_exits: ifes}) do
    {:ok, raw_ife_tx} = Transaction.decode(txbytes)

    case ifes[Transaction.hash(raw_ife_tx)] do
      nil -> {:error, :ife_not_known_for_tx}
      value -> {:ok, value}
    end
  end

  # Challenger part

  @doc """
  Creates a challenge for exiting utxo.
  """
  @spec create_challenge(ExitInfo.t(), Block.t(), Utxo.Position.t()) :: Challenge.t()
  def create_challenge(%ExitInfo{owner: owner}, spending_block, Utxo.position(_, _, _) = utxo_exit) do
    {%Transaction.Signed{raw_tx: challenging_tx} = challenging_signed, input_index} =
      get_spending_transaction_with_index(spending_block, utxo_exit)

    %Challenge{
      utxo_pos: Utxo.Position.encode(utxo_exit),
      input_index: input_index,
      txbytes: challenging_tx |> Transaction.encode(),
      sig: find_sig(challenging_signed, owner)
    }
  end

  @doc """
  Checks whether database responses hold all the relevant data succesfully fetched:
   - a block number which can be used to retrieve needed information to challenge.
   - the relevant exit information
  """
  @spec ensure_challengeable(tuple(), tuple()) :: {:ok, pos_integer(), ExitInfo.t()} | {:error, atom()}
  def ensure_challengeable(spending_blknum_response, exit_response)

  def ensure_challengeable({:ok, :not_found}, _), do: {:error, :utxo_not_spent}
  def ensure_challengeable(_, {:ok, :not_found}), do: {:error, :exit_not_found}

  def ensure_challengeable({:ok, blknum}, {:ok, {_, exit_info}}) when is_integer(blknum),
    do: {:ok, blknum, ExitInfo.from_db_value(exit_info)}

  def ensure_challengeable({:error, error}, _), do: {:error, error}
  def ensure_challengeable(_, {:error, error}), do: {:error, error}

  # finds transaction in given block and input index spending given utxo
  @spec get_spending_transaction_with_index(Block.t(), Utxo.Position.t()) ::
          {Transaction.Signed.t(), non_neg_integer()} | false
  defp get_spending_transaction_with_index(%Block{transactions: txs}, utxo_pos) do
    txs
    |> Enum.map(&Transaction.Signed.decode/1)
    |> Enum.find_value(fn {:ok, %Transaction.Signed{raw_tx: tx} = tx_signed} ->
      # `Enum.find_value/2` allows to find tx that spends `utxo_pos` and return it along with input index in one run
      inputs = Transaction.get_inputs(tx)

      if input_index = Enum.find_index(inputs, &(&1 == utxo_pos)) do
        {tx_signed, input_index}
      else
        false
      end
    end)
  end

  defp find_sig(tx, owner) do
    # at this point having a tx that wasn't actually signed is an error, hence pattern match
    {:ok, sig} = Tools.find_sig(tx, owner)
    sig
  end
end
