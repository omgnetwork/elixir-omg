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

defmodule OMG.Eth.RootChain do
  @moduledoc """
  Adapter/port to RootChain contract

  Handles sending transactions and fetching events
  """

  alias OMG.Eth
  alias OMG.Eth.Config

  require Logger
  import OMG.Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  @type optional_address_t() :: %{atom => Eth.address()} | %{atom => nil}
  # FIXME, revert and refresh, after the EEL pipes are fixed
  @type in_flight_exit_piggybacked_event() :: %{
          owner: <<_::160>>,
          tx_hash: <<_::256>>,
          output_index: {:input | :output, non_neg_integer}
        }

  ########################
  # READING THE CONTRACT #
  ########################

  # some constant-like getters to start

  @spec get_child_block_interval() :: {:ok, pos_integer()} | :error
  def get_child_block_interval(), do: Application.fetch_env(:omg_eth, :child_block_interval)

  @doc """
  This is what the contract understands as the address of native Ether token
  """
  @spec eth_pseudo_address() :: <<_::160>>
  def eth_pseudo_address(), do: Eth.zero_address()

  # actual READING THE CONTRACT

  @doc """
  Returns next blknum that is supposed to be mined by operator
  """
  def get_next_child_block(contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "nextChildBlock()", [], [{:uint, 256}])
  end

  @doc """
  Returns blknum that was already mined by operator (with exception for 0)
  """
  def get_mined_child_block(contract \\ %{}) do
    with {:ok, next} <- get_next_child_block(contract),
         {:ok, interval} <- get_child_block_interval(),
         do: {:ok, next - interval}
  end

  @doc """
  Returns exit for a specific utxo. Calls contract method.

  #TODO - can exits accept a list of exits? Look at ExitProcessor.handle_call({:new_exits, new_exits})
  """
  def get_standard_exit(exit_id, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    return_fields = [:bool, {:uint, 192}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]
    Eth.call_contract(contract, "standardExits(uint160)", [exit_id], return_fields)
  end

  @doc """
  Returns in flight exit for a specific id. Calls contract method.
  #TODO - can exits accept a list of in_flight_exit_id? Look at ExitProcessor.handle_call({:new_in_flight_exits, events})
  """
  def get_in_flight_exit(in_flight_exit_id, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)

    # solidity does not return arrays of structs
    return_struct = [
      {:uint, 256},
      {:uint, 256},
      {:uint, 256},
      :address,
      {:uint, 256}
    ]

    Eth.call_contract(contract, "inFlightExits(uint160)", [in_flight_exit_id], return_struct)
  end

  # TODO: we're storing exit_ids for SEs, we should do the same for IFEs and remove this
  def get_in_flight_exit_id(tx_bytes, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    Eth.call_contract(contract, "getInFlightExitId(bytes)", [tx_bytes], [{:uint, 160}])
  end

  def get_child_chain(blknum, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "blocks(uint256)", [blknum], [{:bytes, 32}, {:uint, 256}])
  end

  ########################
  # EVENTS #
  ########################

  @doc """
  Returns lists of deposits sorted by child chain block number
  """
  def get_deposits(block_from, block_to, contract \\ %{}) do
    # NOTE: see https://github.com/omisego/plasma-contracts/issues/262

    # FIXME: note the `sort_by` here. It is necessary so that the (superfluous, see fixme there) check doesn't filter out
    #        good deposits: `apps/omg/lib/omg/state/core.ex:231`
    #        when the EthereumEventListener pipe refactor is done, the sorting can be removed and events treated separate
    contract_eth = Config.maybe_fetch_addr!(contract, :eth_vault)
    contract_erc20 = Config.maybe_fetch_addr!(contract, :erc20_vault)

    event_signature = "DepositCreated(address,uint256,address,uint256)"

    with {:ok, logs_eth} <-
           Eth.get_ethereum_events(block_from, block_to, event_signature, contract_eth),
         {:ok, logs_erc20} <-
           Eth.get_ethereum_events(block_from, block_to, event_signature, contract_erc20),
         all_sorted_logs =
           [logs_eth, logs_erc20]
           |> Enum.concat()
           |> Enum.sort_by(fn event -> {event["blockNumber"], event["logIndex"]} end),
         do: {:ok, Enum.map(all_sorted_logs, &decode_deposit/1)}
  end

  # FIXME: move to new spot
  @spec get_piggybacks(non_neg_integer, non_neg_integer, optional_address_t) ::
          {:ok, [in_flight_exit_piggybacked_event]}
  def get_piggybacks(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitPiggybacked(address,bytes32,uint8)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_piggybacked/1)}
  end

  @doc """
  Returns lists of block submissions from Ethereum logs
  """
  def get_block_submitted_events({block_from, block_to}, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    signature = "BlockSubmitted(uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &Eth.parse_event(&1, {signature, [:blknum]}))}
  end

  @doc """
  Returns finalizations of exits from a range of blocks from Ethereum logs.
  """
  def get_finalizations(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "ExitFinalized(uint160)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_finalized/1)}
  end

  @doc """
  Returns challenges of exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "ExitChallenged(uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_challenged/1)}
  end

  @doc """
  Returns challenges of in flight exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_in_flight_exit_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitChallenged(address,bytes32,uint256)"

    case Eth.get_ethereum_events(block_from, block_to, signature, contract) do
      {:ok, logs} ->
        challenges =
          Enum.map(logs, fn log ->
            decode_in_flight_exit_challenged = decode_in_flight_exit_challenged(log)

            args = [
              :in_flight_tx,
              :in_flight_input_index,
              :competing_tx,
              :competing_tx_input_index,
              :competing_tx_pos,
              :competing_tx_inclusion_proof,
              :competing_tx_sig
            ]

            types = ["bytes", "uint8", "bytes", "uint8", "uint256", "bytes", "bytes"]
            hash = from_hex(log["transactionHash"])
            call_data = Eth.get_call_data(hash, "challengeInFlightExitNotCanonical", args, types)

            Map.put(decode_in_flight_exit_challenged, :call_data, call_data)
          end)

        {:ok, challenges}

      other ->
        other
    end
  end

  @doc """
  Returns responds to challenges of in flight exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_responds_to_in_flight_exit_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitChallengeResponded(address,bytes32,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_in_flight_exit_challenge_responded/1)}
  end

  @spec get_piggybacks(non_neg_integer, non_neg_integer, optional_addr_t) ::
          {:ok, [in_flight_exit_piggybacked_event]}
  def get_piggybacks(block_from, block_to, contract \\ %{}) do
    contract = maybe_fetch_addr!(contract, :payment_exit_game)
    # FIXME: since intrictate processing of events doesn't fit into the scope of `RootChain` here, the plan is to:
    #   - add `EthereumEventListener.EventProcessors.Piggyback/PiggybackBlocked/Deposit` (yes Deposit too)
    #     machines that will do the processing and be tested
    #     they will be what is hooked up to EELs in the supervisors, instead of the usual sinks (there can be more of these)
    #   - let's proceed without this refactor though
    input_signature = "InFlightExitInputPiggybacked(address,bytes32,uint16)"
    output_signature = "InFlightExitOutputPiggybacked(address,bytes32,uint16)"

    with {:ok, ilogs} <- Eth.get_ethereum_events(block_from, block_to, input_signature, contract),
         {:ok, ologs} <- Eth.get_ethereum_events(block_from, block_to, output_signature, contract),
         do: {
           :ok,
           Enum.concat(
             Enum.map(ilogs, &decode_piggybacked(&1, :input)),
             Enum.map(ologs, &decode_piggybacked(&1, :output))
           )
         }
  end

  @doc """
  Returns challenges of piggybacks from a range of block from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_piggybacks_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    input_signature = "InFlightExitInputBlocked(address,bytes32,uint16)"
    output_signature = "InFlightExitOutputBlocked(address,bytes32,uint16)"

    with {:ok, ilogs} <- Eth.get_ethereum_events(block_from, block_to, input_signature, contract),
         {:ok, ologs} <- Eth.get_ethereum_events(block_from, block_to, output_signature, contract),
         do: {
           :ok,
           Enum.concat(
             Enum.map(ilogs, &decode_piggyback_challenged(&1, :input)),
             Enum.map(ologs, &decode_piggyback_challenged(&1, :output))
           )
         }
  end

  @doc """
  Returns finalizations of in flight exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_in_flight_exit_finalizations(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    input_signature = "InFlightExitInputWithdrawn(uint160,uint16)"
    output_signature = "InFlightExitOutputWithdrawn(uint160,uint16)"

    with {:ok, ilogs} <- Eth.get_ethereum_events(block_from, block_to, input_signature, contract),
         {:ok, ologs} <- Eth.get_ethereum_events(block_from, block_to, output_signature, contract),
         do: {
           :ok,
           Enum.concat(
             Enum.map(ilogs, &decode_in_flight_exit_output_finalized(&1, :input)),
             Enum.map(ologs, &decode_in_flight_exit_output_finalized(&1, :output))
           )
         }
  end

  def decode_in_flight_exit_challenge_responded(log) do
    non_indexed_keys = [:challenger, :tx_hash, :challenge_position]
    non_indexed_key_types = [:address, {:bytes, 32}, {:uint, 256}]
    indexed_keys = indexed_keys_types = []

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  ########################
  # MISC #
  ########################

  @spec contract_ready(optional_address_t()) ::
          :ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}
  def contract_ready(contract \\ %{}) do
    {:ok, addr} = authority(contract)

    case addr do
      <<0::256>> -> {:error, :root_chain_authority_is_nil}
      _ -> :ok
    end
  rescue
    error ->
      _ = Logger.error("The call to contract_ready failed with: #{inspect(error)}")
      {:error, :root_chain_contract_not_available}
  end

  # TODO - missing description + could this be moved to a statefull process?
  @spec get_root_deployment_height(binary() | nil, optional_address_t()) ::
          {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ nil, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    txhash = txhash || from_hex(Application.fetch_env!(:omg_eth, :txhash_contract))

    # the back&forth is just the dumb but natural way to go about Ethereumex/Eth APIs conventions for encoding
    hex_contract = to_hex(contract)

    case txhash |> to_hex() |> Ethereumex.HttpClient.eth_get_transaction_receipt() do
      {:ok, %{"contractAddress" => ^hex_contract, "blockNumber" => height}} ->
        {:ok, int_from_hex(height)}

      {:ok, _} ->
        # TODO this should be an alarm
        {:error, :wrong_contract_address}

      other ->
        other
    end
  end

  @doc """
  Returns standard exits from a range of blocks. Collects exits from Ethereum logs.
  """
  def get_standard_exits(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "ExitStarted(address,uint160)"

    case Eth.get_ethereum_events(block_from, block_to, signature, contract) do
      {:ok, logs} ->
        args = [:args]
        types = ["(uint192,bytes,bytes,bytes)"]
        tuple_arg_names = [:utxo_pos, :output_tx, :output_guard_preimage, :output_tx_inclusion_proof]

        exits =
          Enum.map(logs, fn log ->
            decode_exit_started = decode_exit_started(log)

            call_data =
              Eth.get_call_data(decode_exit_started.root_chain_txhash, "startStandardExit", args, types,
                unpack_tuple_args: tuple_arg_names
              )

            Map.put(decode_exit_started, :call_data, call_data)
          end)

        {:ok, exits}

      other ->
        other
    end
  end

  @doc """
  Returns InFlightExit from a range of blocks.
  """
  def get_in_flight_exit_starts(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitStarted(address,bytes32)"

    case Eth.get_ethereum_events(block_from, block_to, signature, contract) do
      # FIXME: split into functions, here and elsewhere
      {:ok, logs} ->
        args = [:args]
        types = ["(bytes,bytes[],uint256[],uint256[],bytes[],bytes[],bytes[],bytes[],bytes[])"]

        tuple_arg_names = [
          :in_flight_tx,
          :inputs_txs,
          :input_tx_types,
          :input_utxos_pos,
          :output_guard_preimages_for_inputs,
          :input_inclusion_proofs,
          :in_flight_tx_confirm_sigs,
          :in_flight_tx_sigs,
          :optional_args
        ]

        result =
          Enum.map(logs, fn log ->
            decode_in_flight_exit = decode_in_flight_exit(log)

            call_data =
              Eth.get_call_data(decode_in_flight_exit.root_chain_txhash, "startInFlightExit", args, types,
                unpack_tuple_args: tuple_arg_names
              )

            Map.put(decode_in_flight_exit, :call_data, call_data)
          end)

        {:ok, result}

      other ->
        other
    end
  end

  @doc """
  Hexifies the entire contract map, assuming `contract_map` is a map of `%{atom => raw_binary_address}`
  """
  def contract_map_to_hex(contract_map),
    do: Enum.into(contract_map, %{}, fn {name, addr} -> {name, to_hex(addr)} end)

  @doc """
  Unhexifies the entire contract map, assuming `contract_map` is a map of `%{atom => raw_binary_address}`
  """
  def contract_map_from_hex(contract_map),
    do: Enum.into(contract_map, %{}, fn {name, addr} -> {name, from_hex(addr)} end)

  def decode_deposit(log) do
    non_indexed_keys = [:amount]
    non_indexed_key_types = [{:uint, 256}]
    indexed_keys = [:owner, :blknum, :currency]
    indexed_keys_types = [:address, {:uint, 256}, :address]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp decode_exit_started(log) do
    non_indexed_keys = [:exit_id]
    non_indexed_key_types = [{:uint, 160}]
    indexed_keys = [:owner]
    indexed_keys_types = [:address]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp decode_in_flight_exit(log) do
    non_indexed_keys = [:tx_hash]
    non_indexed_key_types = [{:bytes, 32}]
    indexed_keys = [:initiator]
    indexed_keys_types = [:address]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp authority(contract) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "operator()", [], [:address])
  end

  defp decode_piggyback_challenged(log, type) do
    non_indexed_keys = [:tx_hash, :output_index]
    non_indexed_key_types = [{:bytes, 32}, {:uint, 16}]
    indexed_keys = [:challenger]
    indexed_keys_types = [:address]

    decoded_event =
      Eth.parse_events_with_indexed_fields(
        log,
        {non_indexed_keys, non_indexed_key_types},
        {indexed_keys, indexed_keys_types}
      )

    update_with_output_type(decoded_event, type)
  end

  defp decode_piggybacked(log, type) do
    non_indexed_keys = [:tx_hash, :output_index]
    non_indexed_key_types = [{:bytes, 32}, {:uint, 16}]
    indexed_keys = [:owner]
    indexed_keys_types = [:address]

    decoded_event =
      Eth.parse_events_with_indexed_fields(
        log,
        {non_indexed_keys, non_indexed_key_types},
        {indexed_keys, indexed_keys_types}
      )

    update_with_output_type(decoded_event, type)
  end

  defp decode_exit_finalized(log) do
    non_indexed_keys = []
    non_indexed_key_types = []
    indexed_keys = [:exit_id]
    indexed_keys_types = [{:uint, 160}]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  def decode_in_flight_exit_output_finalized(log, type) do
    non_indexed_keys = [:output_index]
    non_indexed_key_types = [{:uint, 16}]
    indexed_keys = [:in_flight_exit_id]
    indexed_keys_types = [{:uint, 160}]

    decoded_event =
      Eth.parse_events_with_indexed_fields(
        log,
        {non_indexed_keys, non_indexed_key_types},
        {indexed_keys, indexed_keys_types}
      )

    update_with_output_type(decoded_event, type)
  end

  defp decode_exit_challenged(log) do
    indexed_keys = [:utxo_pos]
    indexed_keys_types = [{:uint, 256}]

    Eth.parse_events_with_indexed_fields(
      log,
      {[], []},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp decode_in_flight_exit_challenged(log) do
    non_indexed_keys = [:tx_hash, :competitor_position]
    non_indexed_key_types = [{:bytes, 32}, {:uint, 256}]
    indexed_keys = [:challenger]
    indexed_keys_types = [:address]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp update_with_output_type(event, type),
    do: Map.update(event, :omg_data, %{piggyback_type: type}, &Map.put(&1, :piggyback_type, type))
end
