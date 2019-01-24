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

defmodule OMG.Eth.RootChain do
  @moduledoc """
  Adapter/port to RootChain contract

  Handles sending transactions and fetching events
  """

  alias OMG.Eth

  import Eth.Encoding

  @tx_defaults Eth.Defaults.tx_defaults()

  @deposit_created_event_signature "DepositCreated(address,uint256,address,uint256)"
  @challenge_ife_func_signature "challengeInFlightExitNotCanonical(bytes,uint8,bytes,uint8,uint256,bytes,bytes)"

  @type optional_addr_t() :: <<_::160>> | nil

  @gas_start_exit 1_000_000
  @gas_deposit 180_000
  @gas_deposit_from 250_000
  @gas_init 1_000_000
  @standard_exit_bond 31_415_926_535
  @piggyback_bond 31_415_926_535

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

  def start_exit(output_id, tx_bytes, proof, from, contract \\ nil, opts \\ []) do
    defaults =
      @tx_defaults
      |> Keyword.put(:gas, @gas_start_exit)
      |> Keyword.put(:value, @standard_exit_bond)

    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    Eth.contract_transact(
      from,
      contract,
      "startStandardExit(uint192,bytes,bytes)",
      [output_id, tx_bytes, proof],
      opts
    )
  end

  def piggyback_in_flight_exit(in_flight_tx, output_index, from, contract \\ nil, opts \\ []) do
    defaults =
      @tx_defaults
      |> Keyword.put(:gas, 1_000_000)
      |> Keyword.put(:value, @piggyback_bond)

    opts = defaults |> Keyword.merge(opts)
    contract = contract || from_hex(Application.get_env(:omg_eth, :contract_addr))
    Eth.contract_transact(from, contract, "piggybackInFlightExit(bytes,uint8)", [in_flight_tx, output_index], opts)
  end

  def deposit(tx_bytes, value, from, contract \\ nil, opts \\ []) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_deposit)

    opts =
      defaults
      |> Keyword.merge(opts)
      |> Keyword.put(:value, value)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.contract_transact(from, contract, "deposit(bytes)", [tx_bytes], opts)
  end

  def deposit_from(tx, from, contract \\ nil, opts \\ []) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_deposit_from)
    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.contract_transact(from, contract, "depositFrom(bytes)", [tx], opts)
  end

  def add_token(token, contract \\ nil, opts \\ []) do
    opts = @tx_defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()

    Eth.contract_transact(from_hex(from), contract, "addToken(address)", [token], opts)
  end

  def challenge_exit(output_id, challenge_tx, input_index, challenge_tx_sig, from, contract \\ nil, opts \\ []) do
    opts = @tx_defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "challengeStandardExit(uint192,bytes,uint256,bytes)"
    args = [output_id, challenge_tx, input_index, challenge_tx_sig]
    Eth.contract_transact(from, contract, signature, args, opts)
  end

  def init(from \\ nil, contract \\ nil, opts \\ []) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_init)
    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    from = from || from_hex(Application.fetch_env!(:omg_eth, :authority_addr))

    Eth.contract_transact(from, contract, "init()", [], opts)
  end

  def in_flight_exit(
        in_flight_tx,
        input_txs,
        input_txs_inclusion_proofs,
        in_flight_tx_sigs,
        from,
        contract \\ nil,
        opts \\ []
      ) do
    defaults = @tx_defaults |> Keyword.put(:value, @standard_exit_bond)
    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "startInFlightExit(bytes,bytes,bytes,bytes)"
    args = [in_flight_tx, input_txs, input_txs_inclusion_proofs, in_flight_tx_sigs]
    Eth.contract_transact(from, contract, signature, args, opts)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def challenge_in_flight_exit_not_canonical(
        inflight_txbytes,
        inflight_input_index,
        competing_txbytes,
        competing_input_index,
        competing_txid,
        competing_proof,
        competing_sig,
        from,
        contract \\ nil,
        opts \\ []
      ) do
    defaults = @tx_defaults
    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = @challenge_ife_func_signature

    args = [
      inflight_txbytes,
      inflight_input_index,
      competing_txbytes,
      competing_input_index,
      competing_txid,
      competing_proof,
      competing_sig
    ]

    Eth.contract_transact(from, contract, signature, args, opts)
  end

  def respond_to_non_canonical_challenge(
        in_flight_tx,
        in_flight_tx_id,
        in_flight_tx_inclusion_proof,
        from,
        contract \\ nil,
        opts \\ []
      ) do
    defaults = @tx_defaults
    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "respondToNonCanonicalChallenge(bytes,uint256,bytes)"

    args = [in_flight_tx, in_flight_tx_id, in_flight_tx_inclusion_proof]

    Eth.contract_transact(from, contract, signature, args, opts)
  end

  ########################
  # READING THE CONTRACT #
  ########################

  @spec get_child_block_interval :: {:ok, pos_integer} | :error
  def get_child_block_interval, do: Application.fetch_env(:omg_eth, :child_block_interval)

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

  def authority(contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "operator()", [], [:address])
  end

  @doc """
  Returns exit for a specific utxo. Calls contract method.
  """
  def get_exit(exit_id, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "exits(uint192)", [exit_id], [:address, :address, {:uint, 256}])
  end

  def get_standard_exit_id(utxo_pos, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "getStandardExitId(uint256)", [utxo_pos], [{:uint, 192}])
  end

  @doc """
  Returns in flight exit for a specific id. Calls contract method.
  """
  def get_in_flight_exit(in_flight_exit_id, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    # solidity does not return arrays of structs
    return_struct = [
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

  def has_token(token, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    Eth.call_contract(contract, "hasToken(address)", [token], [:bool])
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

  def get_piggybacks(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.get_env(:omg_eth, :contract_addr))
    signature = "InFlightExitPiggybacked(address,bytes32,uint256)"

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

  @doc """
  Returns exits from a range of blocks. Collects exits from Ethereum logs.
  """
  def get_exits(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "ExitStarted(address,uint256,uint256,address)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_started/1)}
  end

  @doc """
  Returns InFlightExit from a range of blocks.
  """
  def get_in_flight_exit_starts(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.get_env(:omg_eth, :contract_addr))
    signature = "InFlightExitStarted(address,bytes32)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract) do
      {:ok,
       Enum.map(logs, fn log ->
         Map.put(
           decode_in_flight_exit(log),
           :call_data,
           Eth.get_call_data(
             from_hex(log["transactionHash"]),
             "startInFlightExit",
             [:in_flight_tx, :inputs_txs, :input_includion_proofs, :in_flight_tx_sigs],
             [:bytes, :bytes, :bytes, :bytes]
           )
         )
       end)}
    end
  end

  @doc """
  Returns finalizations of exits from a range of blocks from Ethereum logs.
  """
  def get_finalizations(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "ExitFinalized(uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_finalized/1)}
  end

  @doc """
  Returns challenges of exits from a range of blocks from Ethereum logs.
  """
  def get_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "ExitChallenged(uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_exit_challenged/1)}
  end

  @doc """
    Returns challenges of in flight exits from a range of blocks from Ethereum logs.
  """
  def get_in_flight_exit_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitChallenged(address,bytes32,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do:
           {:ok,
            Enum.map(logs, fn log ->
              decode_in_flight_exit_challenged(log)
              |> Map.put(
                :call_data,
                Eth.get_call_data(
                  from_hex(log["transactionHash"]),
                  "challengeInFlightExitNotCanonical",
                  [
                    :in_flight_tx,
                    :in_flight_input_index,
                    :competing_tx,
                    :competing_tx_input_index,
                    :competing_tx_id,
                    :competing_tx_inclusion_proof,
                    :competing_tx_sig
                  ],
                  [:bytes, :uint8, :bytes, :uint8, :uint256, :bytes, :bytes]
                )
              )
            end)}
  end

  @doc """
    Returns responds to challenges of in flight exits from a range of blocks from Ethereum logs.
  """
  def get_responds_to_in_flight_exit_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitChallengeResponded(address,bytes32,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_in_flight_exit_challenge_responded/1)}
  end

  @doc """
    Returns challenges of piggybacks from a range of block from Ethereum logs.
  """
  def get_piggybacks_challenges(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitOutputBlocked(address,bytes32,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_piggyback_challenged/1)}
  end

  @doc """
    Returns finalizations of in flight exits from a range of blocks from Ethereum logs.
  """
  def get_in_flight_exit_finalizations(block_from, block_to, contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "InFlightExitFinalized(uint192,uint256)"

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, signature, contract),
         do: {:ok, Enum.map(logs, &decode_in_flight_exit_output_finalized/1)}
  end

  defp decode_deposit(log) do
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

  defp decode_exit_started(log) do
    non_indexed_keys = [:utxo_pos, :amount, :currency]
    non_indexed_key_types = [{:uint, 256}, {:uint, 256}, :address]
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

  defp decode_exit_finalized(log) do
    non_indexed_keys = []
    non_indexed_key_types = []
    indexed_keys = [:utxo_pos]
    indexed_keys_types = [{:uint, 256}]

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  def decode_in_flight_exit_output_finalized(log) do
    non_indexed_keys = [:in_flight_exit_id, :output_id]
    non_indexed_key_types = [{:uint, 192}, {:uint, 256}]
    indexed_keys = indexed_keys_types = []

    Eth.parse_events_with_indexed_fields(
      log,
      {non_indexed_keys, non_indexed_key_types},
      {indexed_keys, indexed_keys_types}
    )
  end

  defp decode_exit_challenged(log) do
    # faux-DRY - just leveraging that these events happen to have exactly the same fields/indexings, in current impl.
    decode_exit_finalized(log)
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

  ########################
  # MISC #
  ########################

  @spec contract_ready(optional_addr_t()) ::
          :ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}
  def contract_ready(contract \\ nil) do
    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

    try do
      {:ok, addr} = authority(contract)

      case addr != <<0::256>> do
        true -> :ok
        false -> {:error, :root_chain_authority_is_nil}
      end
    rescue
      _ -> {:error, :root_chain_contract_not_available}
    end
  end

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
        {:error, :wrong_contract_address}

      other ->
        other
    end
  end

  def deposit_blknum_from_receipt(%{"logs" => logs}) do
    topic =
      @deposit_created_event_signature
      |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
      |> to_hex()

    [%{blknum: deposit_blknum}] =
      logs
      |> Enum.filter(&(topic in &1["topics"]))
      |> Enum.map(&decode_deposit/1)

    deposit_blknum
  end
end
