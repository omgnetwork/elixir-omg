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

defmodule OMG.Watcher.ExitProcessor do
  @moduledoc """
  Encapsulates managing and executing the behaviors related to treating exits by the child chain and watchers
  Keeps a state of exits that are in progress, updates it with news from the root chain, compares to the
  state of the ledger (`OMG.API.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.

  NOTE: Note that all calls return `db_updates` and relay on the caller to do persistence.
  """

  alias OMG.API.EventerAPI
  alias OMG.API.State
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  require Utxo
  alias OMG.DB
  alias OMG.Eth
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Challenge
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  use OMG.API.LoggerExt

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Accepts events and processes them in the state - new exits are tracked.
  Returns `db_updates`
  """
  def new_exits(exits) do
    GenServer.call(__MODULE__, {:new_exits, exits})
  end

  @doc """
  Accepts events and processes them in the state - new in flight exits are tracked.
  Returns `db_updates`
  """
  def new_in_flight_exits(in_flight_exit_started_events) do
    GenServer.call(__MODULE__, {:new_in_flight_exits, in_flight_exit_started_events})
  end

  @doc """
  Accepts events and processes them in the state - finalized exits are untracked _if valid_ otherwise raises alert
  Returns `db_updates`
  """
  def finalize_exits(finalizations) do
    GenServer.call(__MODULE__, {:finalize_exits, finalizations})
  end

  @doc """
  Accepts events and processes them in the state - new piggybacks are tracked, if invalid raises an alert
  Returns `db_updates`
  """
  def piggyback_exits(piggybacks) do
    GenServer.call(__MODULE__, {:piggyback_exits, piggybacks})
  end

  @doc """
  Accepts events and processes them in the state - challenged exits are untracked
  Returns `db_updates`
  """
  def challenge_exits(challenges) do
    GenServer.call(__MODULE__, {:challenge_exits, challenges})
  end

  @doc """
  Accepts events and processes them in the state.
  Competitors are stored for future use(i.e. to challenge an in flight exit).
  Returns `db_updates`
  """
  def new_ife_challenges(challenges) do
    GenServer.call(__MODULE__, {:new_ife_challenges, challenges})
  end

  @doc """
  Accepts events and processes them in state.
  Returns `db_updates`
  """
  def respond_to_in_flight_exits_challenges(responds) do
    GenServer.call(__MODULE__, {:respond_to_in_flight_exits_challenges, responds})
  end

  @doc """
  Accepts events and processes them in state.
  Challenged piggybacks are forgotten.
  Returns `db_updates`
  """
  def challenge_piggybacks(challenges) do
    GenServer.call(__MODULE__, {:challenge_piggybacks, challenges})
  end

  @doc """
    Accepts events and processes them in state - finalized outputs are applied to the state.
    Returns `db_updates`
  """
  def finalize_in_flight_exits(finalizations) do
    GenServer.call(__MODULE__, {:finalize_in_flight_exits, finalizations})
  end

  @doc """
  Checks validity and causes event emission to `OMG.Watcher.Eventer`. Works with `OMG.API.State` to discern validity
  """
  def check_validity do
    GenServer.call(__MODULE__, :check_validity)
  end

  @doc """
  Returns a map of requested in flight exits, where keys are IFE hashes and values are IFES
  If given empty list of hashes, all IFEs are returned.
  """
  @spec get_active_in_flight_exits() :: {:ok, %{binary() => InFlightExitInfo.t()}}
  def get_active_in_flight_exits do
    GenServer.call(__MODULE__, :get_active_in_flight_exits)
  end

  @doc """
  Returns all information required to produce a transaction to the root chain contract to present a competitor for
  a non-canonical in-flight exit
  """
  @spec get_competitor_for_ife(binary()) :: {:ok, Core.competitor_data_t()} | {:error, :competitor_not_found}
  def get_competitor_for_ife(txbytes) do
    GenServer.call(__MODULE__, {:get_competitor_for_ife, txbytes})
  end

  @doc """
  Returns all information required to produce a transaction to the root chain contract to present a proof of canonicity
  for a challenged in-flight exit
  """
  @spec prove_canonical_for_ife(binary()) :: {:ok, Core.prove_canonical_data_t()} | {:error, :canonical_not_found}
  def prove_canonical_for_ife(txbytes) do
    GenServer.call(__MODULE__, {:prove_canonical_for_ife, txbytes})
  end

  @spec get_input_challenge_data(Transaction.Signed.tx_bytes(), Transaction.input_index_t()) ::
          {:ok, Core.input_challenge_data()} | {:error, Core.piggyback_challenge_data_error()}
  def get_input_challenge_data(txbytes, input_index) do
    GenServer.call(__MODULE__, {:get_input_challenge_data, txbytes, input_index})
  end

  @spec get_output_challenge_data(Transaction.Signed.tx_bytes(), Transaction.input_index_t()) ::
          {:ok, Core.output_challenge_data()} | {:error, Core.piggyback_challenge_data_error()}
  def get_output_challenge_data(txbytes, output_index) do
    GenServer.call(__MODULE__, {:get_output_challenge_data, txbytes, output_index})
  end

  @doc """
  Returns challenge for an exit
  """
  @spec create_challenge(Utxo.Position.t()) ::
          {:ok, Challenge.t()} | {:error, :utxo_not_spent | :exit_not_found}
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
        Utxo.Position.decode(utxo_pos)
      end)

    {:ok, exit_event_triggers, db_updates_from_state, validities} = State.exit_utxos(exits)

    _ = if not Enum.empty?(exit_event_triggers), do: Logger.info("Finalized exits: #{inspect(validities)}")

    exit_event_triggers
    |> Core.create_exit_finalized_events()
    |> EventerAPI.emit_events()

    {new_state, db_updates} = Core.finalize_exits(state, validities)
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

    case Core.finalize_in_flight_exits(state, finalizations) do
      {:ok, state, db_updates} ->
        {:reply, {:ok, db_updates}, state}

      {:not_piggybacked, not_piggybacked} ->
        _ = Logger.error("Outputs not piggybacked: #{inspect(not_piggybacked)}")
        {:stop, :not_piggybacked, state}

      {:unknown_in_flight_exit, unknown_ifes} ->
        _ = Logger.error("Unknown in-flight exits: #{inspect(unknown_ifes)}")
        {:stop, :unknown_in_flight_exit, Elixir.Agent.Server, state}
    end
  end

  @doc """
  Combine data from `ExitProcessor` and `API.State` to figure out what to do about exits
  """
  def handle_call(:check_validity, _from, state) do
    {state1, request} = prepare_validity_check(state)
    {chain_status, events} = Core.invalid_exits(request, state1)
    {:reply, {chain_status, events}, state}
  end

  def handle_call(:get_active_in_flight_exits, _from, state),
    do: {:reply, {:ok, Core.get_active_in_flight_exits(state)}, state}

  def handle_call({:get_competitor_for_ife, txbytes}, _from, state) do
    # NOTE: future of using `ExitProcessor.Request` struct not certain, see that module for details
    competitor_result =
      %ExitProcessor.Request{}
      # TODO: run_status_gets and getting all non-existent UTXO positions imaginable can be optimized out heavily
      #       only the UTXO positions being inputs to `txbytes` must be looked at, but it becomes problematic as
      #       txbytes can be invalid so we'd need a with here...
      |> run_status_gets()
      |> Core.determine_utxo_existence_to_get(state)
      |> run_utxo_exists()
      |> Core.determine_spends_to_get(state)
      |> run_spend_getting()
      |> Core.determine_blocks_to_get()
      |> run_block_getting()
      |> Core.get_competitor_for_ife(state, txbytes)

    {:reply, competitor_result, state}
  end

  def handle_call({:prove_canonical_for_ife, txbytes}, _from, state) do
    # NOTE: future of using `ExitProcessor.Request` struct not certain, see that module for details
    canonicity_result =
      %ExitProcessor.Request{}
      # TODO: same comment as above in get_competitor_for_ife
      |> run_status_gets()
      |> Core.determine_utxo_existence_to_get(state)
      |> run_utxo_exists()
      |> Core.determine_spends_to_get(state)
      |> run_spend_getting()
      |> Core.determine_blocks_to_get()
      |> run_block_getting()
      |> Core.prove_canonical_for_ife(txbytes)

    {:reply, canonicity_result, state}
  end

  def handle_call({:get_input_challenge_data, txbytes, input_index}, _from, state) do
    response =
      %ExitProcessor.Request{}
      |> run_status_gets()
      |> Core.determine_utxo_existence_to_get(state)
      |> run_utxo_exists()
      |> Core.determine_spends_to_get(state)
      |> run_spend_getting()
      |> Core.determine_blocks_to_get()
      |> run_block_getting()
      |> Core.get_input_challenge_data(state, txbytes, input_index)

    {:reply, response, state}
  end

  def handle_call({:get_output_challenge_data, txbytes, output_index}, _from, state) do
    {state1, request} = prepare_validity_check(state)
    response = Core.get_output_challenge_data(request, state1, txbytes, output_index)
    {:reply, response, state}
  end

  def handle_call({:create_challenge, Utxo.position(blknum, txindex, oindex) = exiting_utxo_pos}, _from, state) do
    with spending_blknum_response <- exiting_utxo_pos |> Utxo.Position.to_db_key() |> OMG.DB.spent_blknum(),
         %{txhash: txhash} <- OMG.Watcher.DB.Transaction.get_by_position(blknum, txindex),
         {:ok, exit_id} <- OMG.Eth.RootChain.get_standard_exit_id(txhash, oindex),
         {:ok, raw_spending_proof, exit_info} <-
           Core.get_challange_data(spending_blknum_response, exiting_utxo_pos, state) do
      # TODO: we're violating the shell/core pattern here, refactor!
      spending_proof =
        case raw_spending_proof do
          raw_blknum when is_number(raw_blknum) ->
            {:ok, hashes} = OMG.DB.block_hashes([raw_blknum])
            {:ok, [spending_block]} = OMG.DB.blocks(hashes)
            spending_block

          signed_tx ->
            signed_tx
        end

      {:reply, {:ok, Core.create_challenge(exit_info, spending_proof, exiting_utxo_pos, exit_id)}, state}
    else
      error -> {:reply, error, state}
    end
  end

  defp prepare_validity_check(state) do
    # NOTE: future of using `ExitProcessor.Request` struct not certain, see that module for details
    {request, state} =
      %ExitProcessor.Request{}
      |> run_status_gets()
      # To find if IFE was included, see first if its inputs were spent.
      |> Core.determine_ife_input_utxos_existence_to_get(state)
      |> run_ife_input_utxo_existance()
      # Next, check by what transactions they were spent.
      |> Core.determine_ife_spends_to_get(state)
      |> run_ife_spend_getting()
      # Find tx bodies.
      |> Core.determine_ife_blocks_to_get()
      |> run_ife_block_getting()
      # Compare found txes with ife.tx.
      # If equal, persist information about position.
      |> Core.find_ifes_in_blocks(state)

    request =
      request
      |> Core.determine_utxo_existence_to_get(state)
      |> run_utxo_exists()
      |> Core.determine_spends_to_get(state)
      |> run_spend_getting()
      |> Core.determine_blocks_to_get()
      |> run_block_getting()

    {state, request}
  end

  defp run_status_gets(%ExitProcessor.Request{} = request) do
    {:ok, eth_height_now} = Eth.get_ethereum_height()
    {blknum_now, _} = State.get_status()

    _ = Logger.debug("eth_height_now: #{inspect(eth_height_now)}, blknum_now: #{inspect(blknum_now)}")
    %{request | eth_height_now: eth_height_now, blknum_now: blknum_now}
  end

  defp run_utxo_exists(%ExitProcessor.Request{utxos_to_check: positions} = request) do
    result = positions |> Enum.map(&State.utxo_exists?/1)
    _ = Logger.debug("utxos_to_check: #{inspect(positions)}, utxo_exists_result: #{inspect(result)}")
    %{request | utxo_exists_result: result}
  end

  defp run_ife_input_utxo_existance(%ExitProcessor.Request{piggybacked_utxos_to_check: positions} = request) do
    result = positions |> Enum.map(&State.utxo_exists?/1)

    _ =
      Logger.debug(
        "piggybacked_utxos_to_check: #{inspect(positions)}, piggybacked_utxo_exists_result: #{inspect(result)}"
      )

    %{request | piggybacked_utxo_exists_result: result}
  end

  defp run_spend_getting(%ExitProcessor.Request{spends_to_get: positions} = request) do
    result = positions |> Enum.map(&single_spend_getting/1)
    _ = Logger.debug("spends_to_get: #{inspect(positions)}, spent_blknum_result: #{inspect(result)}")
    %{request | spent_blknum_result: result}
  end

  defp run_ife_spend_getting(%ExitProcessor.Request{piggybacked_spends_to_get: positions} = request) do
    result = positions |> Enum.map(&single_spend_getting/1)

    _ =
      Logger.debug(
        "piggybacked_spends_to_get: #{inspect(positions)}, piggybacked_spent_blknum_result: #{inspect(result)}"
      )

    %{request | piggybacked_spent_blknum_result: result}
  end

  defp single_spend_getting(position) do
    {:ok, spend_blknum} =
      position
      |> Utxo.Position.to_db_key()
      |> OMG.DB.spent_blknum()

    spend_blknum
  end

  defp run_block_getting(%ExitProcessor.Request{blknums_to_get: blknums} = request) do
    _ = Logger.debug("blknums_to_get: #{inspect(blknums)}")
    {:ok, hashes} = OMG.DB.block_hashes(blknums)
    _ = Logger.debug("hashes: #{inspect(hashes)}")
    {:ok, blocks} = OMG.DB.blocks(hashes)
    _ = Logger.debug("blocks_result: #{inspect(blocks)}")
    %{request | blocks_result: blocks}
  end

  defp run_ife_block_getting(%ExitProcessor.Request{piggybacked_blknums_to_get: blknums} = request) do
    _ = Logger.debug("piggybacked_blknums_to_get: #{inspect(blknums)}")
    {:ok, hashes} = OMG.DB.block_hashes(blknums)
    _ = Logger.debug("piggybacked_hashes: #{inspect(hashes)}")
    {:ok, blocks} = OMG.DB.blocks(hashes)
    _ = Logger.debug("piggybacked_blocks_result: #{inspect(blocks)}")
    %{request | piggybacked_blocks_result: blocks}
  end
end
