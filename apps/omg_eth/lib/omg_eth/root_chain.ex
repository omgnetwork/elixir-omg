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
  use Spandex.Decorators
  import OMG.Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  @deposit_created_event_signature "DepositCreated(address,uint256,address,uint256)"

  @type optional_addr_t() :: <<_::160>> | nil
  @type in_flight_exit_piggybacked_event() :: %{owner: <<_::160>>, tx_hash: <<_::256>>, output_index: non_neg_integer}
  @spec submit_block(binary, pos_integer, pos_integer, optional_addr_t(), optional_addr_t()) ::
          {:error, binary() | atom() | map()}
          | {:ok, binary()}
  def submit_block(hash, nonce, gas_price, from \\ nil, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    from = from || from_hex(Application.fetch_env!(:omg_eth, :authority_addr))

    # NOTE: we're not using any defaults for opts here!
    Eth.contract_transact(
      from,
      contract,
      "submitBlock(bytes32)",
      [hash],
      nonce: nonce,
      gasPrice: gas_price,
      value: 0,
      gas: 100_000
    )
  end

  ########################
  # READING THE CONTRACT #
  ########################

  # some constant-like getters to start

  @spec get_child_block_interval :: {:ok, pos_integer} | :error
  def get_child_block_interval, do: Application.fetch_env(:omg_eth, :child_block_interval)

  @doc """
  This is what the contract understands as the address of native Ether token
  """
  @spec eth_pseudo_address :: <<_::160>>
  def eth_pseudo_address, do: Eth.zero_address()

  # actual READING THE CONTRACT

  @doc """
  Returns next blknum that is supposed to be mined by operator
  """
  def get_next_child_block(contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "nextChildBlock()", [], [{:uint, 256}])
  end

  @doc """
  Returns blknum that was already mined by operator (with exception for 0)
  """
  def get_mined_child_block(contract \\ nil) do
    with {:ok, next} <- get_next_child_block(contract),
         {:ok, interval} <- get_child_block_interval(),
         do: {:ok, next - interval}
  end

  @doc """
  Returns exit for a specific utxo. Calls contract method.

  #TODO - can exits accept a list of exits? Look at ExitProcessor.handle_call({:new_exits, new_exits})
  """
  def get_standard_exit(exit_id, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "exits(uint192)", [exit_id], [:address, :address, {:uint, 256}, {:uint, 192}])
  end

  def get_standard_exit_id(txbytes, utxo_pos, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "getStandardExitId(bytes,uint256)", [txbytes, utxo_pos], [{:uint, 192}])
  end

  @doc """
  Returns in flight exit for a specific id. Calls contract method.
  #TODO - can exits accept a list of in_flight_exit_id? Look at ExitProcessor.handle_call({:new_in_flight_exits, events})
  """
  def get_in_flight_exit(in_flight_exit_id, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    # solidity does not return arrays of structs
    return_struct = [
      {:uint, 256},
      {:uint, 256},
      {:uint, 256},
      :address,
      {:uint, 256}
    ]

    Eth.call_contract(contract, "inFlightExits(uint192)", [in_flight_exit_id], return_struct)
  end

  def get_in_flight_exit_id(tx_bytes, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "getInFlightExitId(bytes)", [tx_bytes], [{:uint, 192}])
  end

  def get_child_chain(blknum, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "blocks(uint256)", [blknum], [{:bytes, 32}, {:uint, 256}])
  end

  ########################
  # EVENTS #
  ########################

  @doc """
  Returns lists of deposits sorted by child chain block number
  """
  def get_deposits(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, @deposit_created_event_signature, contract),
         do: {:ok, Enum.map(logs, &decode_deposit/1)}
  end

  @spec get_piggybacks(non_neg_integer, non_neg_integer, optional_addr_t) ::
          {:ok, [in_flight_exit_piggybacked_event]}
  def get_piggybacks(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.get_env(:omg_eth, :contract_addr))
    signature = "InFlightExitPiggybacked(address,bytes32,uint8)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_piggybacked/1)}
  end

  @doc """
  Returns lists of block submissions from Ethereum logs
  """
  def get_block_submitted_events({block_from, block_to}, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "BlockSubmitted(uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &Eth.parse_event(&1, {signature, [:blknum]}))}
  end

  # NOT USED
  @doc """
  Returns finalizations of exits from a range of blocks from Ethereum logs.
  """
  def get_finalizations(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "ExitFinalized(uint192)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_finalized/1)}
  end

  # NOT USED
  @doc """
  Returns challenges of exits from a range of blocks from Ethereum logs.
  """
  def get_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "ExitChallenged(uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_challenged/1)}
  end

  # NOT USED
  @doc """
    Returns challenges of in flight exits from a range of blocks from Ethereum logs.
  """
  def get_in_flight_exit_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
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

            types = [:bytes, :uint8, :bytes, :uint8, :uint256, :bytes, :bytes]
            hash = from_hex(log["transactionHash"])
            call_data = Eth.get_call_data(hash, "challengeInFlightExitNotCanonical", args, types)

            Map.put(decode_in_flight_exit_challenged, :call_data, call_data)
          end)

        {:ok, challenges}

      other ->
        other
    end
  end

  # NOT USED
  @doc """
    Returns responds to challenges of in flight exits from a range of blocks from Ethereum logs.
  """
  def get_responds_to_in_flight_exit_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitChallengeResponded(address,bytes32,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_in_flight_exit_challenge_responded/1)}
  end

  # NOT USED
  @doc """
    Returns challenges of piggybacks from a range of block from Ethereum logs.
  """
  def get_piggybacks_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitOutputBlocked(address,bytes32,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_piggyback_challenged/1)}
  end

  # NOT USED
  @doc """
    Returns finalizations of in flight exits from a range of blocks from Ethereum logs.
  """
  def get_in_flight_exit_finalizations(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitFinalized(uint192,uint8)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_in_flight_exit_output_finalized/1)}
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

  @spec contract_ready(optional_addr_t()) ::
          :ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}
  def contract_ready(contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    try do
      {:ok, addr} = authority(contract)

      case addr do
        <<0::256>> -> {:error, :root_chain_authority_is_nil}
        _ -> :ok
      end
    rescue
      _ -> {:error, :root_chain_contract_not_available}
    end
  end

  # TODO - missing description + could this be moved to a statefull process?
  @spec get_root_deployment_height(binary() | nil, optional_addr_t()) ::
          {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ nil, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
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
  def get_standard_exits(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "ExitStarted(address,uint192)"

    case Eth.get_ethereum_events(block_from, block_to, signature, contract) do
      {:ok, logs} ->
        exits =
          Enum.map(logs, fn log ->
            decode_exit_started = decode_exit_started(log)
            args = [:utxo_pos, :output_tx, :output_tx_inclusion_proof]
            types = [:uint192, :bytes, :bytes]
            hash = from_hex(log["transactionHash"])
            transaction_hash = Eth.get_call_data(hash, "startStandardExit", args, types)
            Map.put(decode_exit_started, :call_data, transaction_hash)
          end)

        {:ok, exits}

      other ->
        other
    end
  end

  @doc """
  Returns InFlightExit from a range of blocks.
  """
  def get_in_flight_exit_starts(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.get_env(:omg_eth, :contract_addr))
    signature = "InFlightExitStarted(address,bytes32)"

    case Eth.get_ethereum_events(block_from, block_to, signature, contract) do
      {:ok, logs} ->
        args = [:in_flight_tx, :inputs_txs, :input_inclusion_proofs, :in_flight_tx_sigs]
        types = [:bytes, :bytes, :bytes, :bytes]

        result =
          Enum.map(logs, fn log ->
            transaction_hash = from_hex(log["transactionHash"])
            start_in_flight_exit = Eth.get_call_data(transaction_hash, "startInFlightExit", args, types)
            decode_in_flight_exit = decode_in_flight_exit(log)
            Map.put(decode_in_flight_exit, :call_data, start_in_flight_exit)
          end)

        {:ok, result}

      other ->
        other
    end
  end

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
    non_indexed_key_types = [{:uint, 192}]
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
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "operator()", [], [:address])
  end

  defp decode_piggyback_challenged(log) do
    non_indexed_keys = [:tx_hash, :output_index]
    non_indexed_key_types = [{:bytes, 32}, {:uint, 256}]
    indexed_keys = [:challenger]
    indexed_keys_types = [:address]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp decode_piggybacked(log) do
    non_indexed_keys = [:tx_hash, :output_index]
    non_indexed_key_types = [{:bytes, 32}, {:uint, 256}]
    indexed_keys = [:owner]
    indexed_keys_types = [:address]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp decode_exit_finalized(log) do
    non_indexed_keys = []
    non_indexed_key_types = []
    indexed_keys = [:exit_id]
    indexed_keys_types = [{:uint, 256}]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  def decode_in_flight_exit_output_finalized(log) do
    non_indexed_keys = [:in_flight_exit_id, :output_index]
    non_indexed_key_types = [{:uint, 192}, {:uint, 8}]
    indexed_keys = indexed_keys_types = []

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
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
end
