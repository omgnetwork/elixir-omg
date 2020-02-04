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

defmodule OMG.Eth.RootChain do
  @moduledoc """
  Adapter/port to RootChain contract

  Handles sending transactions and fetching events.

  Should remain simple and not contain any business logic, except being aware of the RootChain contract(s) APIs.
  """

  alias OMG.Eth
  alias OMG.Eth.Config
  alias OMG.Eth.RootChain.Decode
  alias OMG.Eth.RootChain.Rpc
  require Logger
  import OMG.Eth.Encoding, only: [to_hex: 1, from_hex: 1, int_from_hex: 1]

  @type optional_address_t() :: %{atom => Eth.address()} | %{atom => nil}
  @type in_flight_exit_piggybacked_event() :: %{
          owner: <<_::160>>,
          tx_hash: <<_::256>>,
          output_index: non_neg_integer
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
  Returns standard exits data from the contract for a list of `exit_id`s. Calls contract method.
  """
  def get_standard_exit_structs(exit_ids, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)

    return_types = [
      {:array, {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}}
    ]

    # TODO: hack around an issue with `ex_abi` https://github.com/poanetwork/ex_abi/issues/22
    #       We procure a hacky version of `OMG.Eth.call_contract` which strips the offending offsets from
    #       the ABI-encoded binary and proceeds to decode the array without the offset
    #       Revert to `call_contract` when that issue is resolved
    call_contract_manual_exits(
      contract,
      "standardExits(uint160[])",
      [exit_ids],
      return_types
    )
  end

  @doc """
  Returns in flight exits of the specified ids. Calls a contract method.
  """
  def get_in_flight_exit_structs(in_flight_exit_ids, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    {:array, {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}}

    # solidity does not return arrays of structs
    return_types = [
      {:array, {:tuple, [:bool, {:uint, 64}, {:uint, 256}, {:uint, 256}, :address, {:uint, 256}, {:uint, 256}]}}
    ]

    call_contract_manual_exits(
      contract,
      "inFlightExits(uint160[])",
      [in_flight_exit_ids],
      return_types
    )
  end

  # TODO: we're storing exit_ids for SEs, we should do the same for IFEs and remove this (requires exit_id to be
  #       emitted from the start IFE event
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

    contract_eth = Config.maybe_fetch_addr!(contract, :eth_vault)
    contract_erc20 = Config.maybe_fetch_addr!(contract, :erc20_vault)
    event_signature = "DepositCreated(address,uint256,address,uint256)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, event_signature, [contract_eth, contract_erc20])

    {:ok, Enum.map(logs, &Decode.deposit/1)}
  end

  @spec get_piggybacks(non_neg_integer, non_neg_integer, optional_address_t) ::
          {:ok, [in_flight_exit_piggybacked_event]}
  def get_piggybacks(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    input_signature = "InFlightExitInputPiggybacked(address,bytes32,uint16)"
    output_signature = "InFlightExitOutputPiggybacked(address,bytes32,uint16)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, [input_signature, output_signature], contract)

    {:ok, Enum.map(logs, &Decode.piggybacked/1)}
  end

  @doc """
  Returns lists of block submissions from Ethereum logs
  """
  def get_block_submitted_events({block_from, block_to}, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    signature = "BlockSubmitted(uint256)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)

    {:ok, Enum.map(logs, &Decode.block_submitted/1)}
  end

  @doc """
  Returns finalizations of exits from a range of blocks from Ethereum logs.
  """
  def get_finalizations(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "ExitFinalized(uint160)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)

    {:ok, Enum.map(logs, &Decode.exit_finalized/1)}
  end

  @doc """
  Returns challenges of exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "ExitChallenged(uint256)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)

    {:ok, Enum.map(logs, &Decode.exit_challenged/1)}
  end

  @doc """
  Returns challenges of in flight exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_in_flight_exit_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitChallenged(address,bytes32,uint256)"

    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)

    # we got the logs that were emitted, but now we need to enrich them with call data
    enriched_logs =
      Enum.map(logs, fn log ->
        decoded_log = Decode.in_flight_exit_challenged(log)
        {:ok, enriched_log} = Rpc.get_call_data(decoded_log.root_chain_txhash)
        enriched_decoded_log = Decode.challenge_in_flight_exit_not_canonical(from_hex(enriched_log))
        Map.put(decoded_log, :call_data, enriched_decoded_log)
      end)

    {:ok, enriched_logs}
  end

  @doc """
  Returns responds to challenges of in flight exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_responds_to_in_flight_exit_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitChallengeResponded(address,bytes32,uint256)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)

    {:ok, Enum.map(logs, &Decode.in_flight_exit_challenge_responded/1)}
  end

  @doc """
  Returns challenges of piggybacks from a range of block from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_piggybacks_challenges(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    input_signature = "InFlightExitInputBlocked(address,bytes32,uint16)"
    output_signature = "InFlightExitOutputBlocked(address,bytes32,uint16)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, [input_signature, output_signature], contract)

    {:ok, Enum.map(logs, &Decode.in_flight_exit_blocked/1)}
  end

  @doc """
  Returns finalizations of in flight exits from a range of blocks from Ethereum logs.
  Used as a callback function in EthereumEventListener.
  """
  def get_in_flight_exit_finalizations(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    input_signature = "InFlightExitInputWithdrawn(uint160,uint16)"
    output_signature = "InFlightExitOutputWithdrawn(uint160,uint16)"
    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, [input_signature, output_signature], contract)

    {:ok, Enum.map(logs, &Decode.in_flight_exit_finalized/1)}
  end

  @doc """
  Returns standard exits starting events from a range of blocks
  """
  def get_standard_exits_started(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "ExitStarted(address,uint160)"

    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)
    # we got the logs that were emitted, but now we need to enrich them with call data
    enriched_logs =
      Enum.map(logs, fn log ->
        decoded_log = Decode.exit_started(log)
        {:ok, enriched_log} = Rpc.get_call_data(decoded_log.root_chain_txhash)
        enriched_decoded_log = Decode.start_standard_exit(from_hex(enriched_log))
        Map.put(decoded_log, :call_data, enriched_decoded_log)
      end)

    {:ok, enriched_logs}
  end

  @doc """
  Returns in-flight exits starting events from a range of blocks
  """
  def get_in_flight_exits_started(block_from, block_to, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :payment_exit_game)
    signature = "InFlightExitStarted(address,bytes32)"

    {:ok, logs} = Rpc.get_ethereum_events(block_from, block_to, signature, contract)

    # we got the logs that were emitted, but now we need to enrich them with call data
    enriched_logs =
      Enum.map(logs, fn log ->
        decoded_log = Decode.in_flight_exit_started(log)
        {:ok, enriched_log} = Rpc.get_call_data(decoded_log.root_chain_txhash)
        enriched_decoded_log = Decode.start_in_flight_exit(from_hex(enriched_log))
        Map.put(decoded_log, :call_data, enriched_decoded_log)
      end)

    {:ok, enriched_logs}
  end

  ########################
  # /EVENTS #
  ########################

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

  defp authority(contract) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    Eth.call_contract(contract, "authority()", [], [:address])
  end
end
