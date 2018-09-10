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
  Adapter/port to RootChain.sol

  All sending of transactions and listening to events goes here
  """

  alias OMG.API.Crypto
  alias OMG.Eth

  @type contract_t() :: binary | nil

  @spec submit_block(binary, pos_integer, pos_integer, Crypto.address_t() | nil, contract_t()) ::
          {:error, binary() | atom() | map()}
          | {:ok, binary()}
  def submit_block(hash, nonce, gas_price, from \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    from = from || Application.get_env(:omg_eth, :authority_addr)

    Eth.contract_transact(
      from,
      contract,
      "submitBlock(bytes32)",
      [hash],
      nonce: nonce,
      gasPrice: gas_price,
      gas: 100_000
    )
  end

  def start_deposit_exit(deposit_positon, value, gas_price, from, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)

    Eth.contract_transact(
      from,
      contract,
      "startDepositExit(uint256,uint256)",
      [deposit_positon, value],
      gasPrice: gas_price,
      gas: 1_000_000
    )
  end

  def start_exit(utxo_position, txbytes, proof, sigs, gas_price, from, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)

    Eth.contract_transact(
      from,
      contract,
      "startExit(uint256,bytes,bytes,bytes)",
      [utxo_position, txbytes, proof, sigs],
      gasPrice: gas_price,
      gas: 1_000_000
    )
  end

  def deposit(value, from, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    Eth.contract_transact(from, contract, "deposit()", [], value: value)
  end

  def deposit_token(from, token, amount, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    signature = "depositFrom(address,address,uint256)"
    Eth.contract_transact_sync!(from, contract, signature, [Eth.cleanup(from), Eth.cleanup(token), amount])
  end

  def add_token(token, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    Eth.contract_transact_sync!(from, contract, "addToken(address)", [token])
  end

  def challenge_exit(cutxopo, eutxoindex, txbytes, proof, sigs, from, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    signature = "challengeExit(uint256,uint256,bytes,bytes,bytes)"
    args = [cutxopo, eutxoindex, txbytes, proof, sigs]
    Eth.contract_transact(from, contract, signature, args)
  end

  def create_new(path_project_root, addr) do
    bytecode = Eth.get_bytecode!(path_project_root, "RootChain")
    Eth.deploy_contract(addr, bytecode, [], [], "0x3ff2d9")
  end

  ########################
  # READING THE CONTRACT #
  ########################

  @spec get_child_block_interval :: {:ok, pos_integer} | :error
  def get_child_block_interval, do: Application.fetch_env(:omg_eth, :child_block_interval)

  @doc """
  Returns next blknum that is supposed to be mined by operator
  """
  def get_current_child_block(contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    Eth.call_contract_value(contract, "currentChildBlock()")
  end

  @doc """
  Returns blknum that was already mined by operator (with exception for 0)
  """
  def get_mined_child_block(contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    with {:ok, next} <- Eth.call_contract_value(contract, "currentChildBlock()"), do: {:ok, next - 1000}
  end

  def authority(contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    {:ok, {operator_address}} = Eth.call_contract(contract, "operator()", [], [:address])
    {:ok, operator_address}
  end

  @doc """
  Returns lists of deposits sorted by child chain block number
  """
  def get_deposits(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    signature = "Deposit(address,uint256,address,uint256)"

    with {:ok, logs} <- get_ethereum_events(block_from, block_to, signature, contract),
         deposits <- Enum.map(logs, &decode_deposit/1),
         do: {:ok, Enum.sort(deposits, &(&1.blknum > &2.blknum))}
  end

  @doc """
  Returns lists of block submissions sorted by timestamp
  """
  def get_block_submitted_events(block_range, contract \\ nil)

  def get_block_submitted_events({block_from, block_to}, contract) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    signature = "BlockSubmitted(uint256)"
    keys = [:blknum]

    parse_block_submissions = fn %{"blockNumber" => "0x" <> hex_block_number} = log ->
      {eth_height, ""} = Integer.parse(hex_block_number, 16)

      log
      |> parse_event({signature, keys})
      |> Map.put(:eth_height, eth_height)
    end

    with {:ok, logs} <- get_ethereum_events(block_from, block_to, signature, contract),
         block_submissions <- logs |> Enum.map(parse_block_submissions),
         do: {:ok, Enum.sort(block_submissions, &(&1.blknum > &2.blknum))}
  end

  def get_block_submitted_events(:empty_range, _contract) do
    {:ok, []}
  end

  @doc """
  Returns exits from a range of blocks. Collects exits from Ethereum logs.
  """
  def get_exits(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    signature = "ExitStarted(address,uint256,address,uint256)"

    with {:ok, logs} <- get_ethereum_events(block_from, block_to, signature, contract),
         exits <- Enum.map(logs, &decode_exit/1),
         do: {:ok, Enum.sort(exits, &(&1.block_height > &2.block_height))}
  end

  @doc """
  Returns exit for a specific utxo. Calls contract method.
  """
  def get_exit(utxo_pos, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)

    Eth.call_contract(contract, "getExit(uint256)", [utxo_pos], [:address, :address, {:uint, 256}])
  end

  def get_child_chain(blknum, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)

    Eth.call_contract(contract, "getChildChain(uint256)", [blknum], [{:bytes, 32}, {:uint, 256}])
  end

  def has_token(token, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    {:ok, {has_token}} = Eth.call_contract(contract, "hasToken(address)", [Eth.cleanup(token)], [:bool])
    {:ok, has_token}
  end

  @spec contract_ready(contract_t()) ::
          :ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}
  def contract_ready(contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)

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

  @spec get_root_deployment_height(binary() | nil, contract_t()) :: {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omg_eth, :contract_addr)
    txhash = txhash || Application.get_env(:omg_eth, :txhash_contract)

    case Ethereumex.HttpClient.eth_get_transaction_receipt(txhash) do
      {:ok, %{"contractAddress" => ^contract, "blockNumber" => "0x" <> height_hex}} ->
        {height, ""} = Integer.parse(height_hex, 16)
        {:ok, height}

      {:ok, _} ->
        {:error, :wrong_contract_address}

      other ->
        other
    end
  end

  def deposit_blknum_from_receipt(receipt) do
    [%{blknum: deposit_blknum}] =
      filter_receipt_events(receipt["logs"], "Deposit(address,uint256,address,uint256)", &decode_deposit/1)

    deposit_blknum
  end

  defp decode_deposit(log) do
    non_indexed_keys = [:currency, :amount]
    non_indexed_key_types = [:address, {:uint, 256}]
    indexed_keys = [:owner, :blknum]
    indexed_keys_types = [:address, {:uint, 256}]

    parse_events_with_indexed_fields(log, {non_indexed_keys, non_indexed_key_types}, {indexed_keys, indexed_keys_types})
  end

  defp decode_exit(log) do
    non_indexed_keys = [:currency, :amount]
    non_indexed_key_types = [:address, {:uint, 256}]
    indexed_keys = [:owner, :utxo_pos]
    indexed_keys_types = [:address, {:uint, 256}]

    parse_events_with_indexed_fields(log, {non_indexed_keys, non_indexed_key_types}, {indexed_keys, indexed_keys_types})
  end

  @spec filter_receipt_events([%{topics: [binary], data: binary()}], binary, (map() -> map())) :: [map()]
  def filter_receipt_events(receipt_logs, signature, decode_log) do
    topic = signature |> OMG.API.Crypto.hash() |> Base.encode16(case: :lower)
    topic = "0x" <> topic

    receipt_logs
    |> Enum.filter(&(topic in &1["topics"]))
    |> Enum.map(decode_log)
  end

  ###########
  # PRIVATE #
  ###########

  defp event_topic_for_signature(signature) do
    body = signature |> :keccakf1600.sha3_256() |> Base.encode16(case: :lower)
    "0x" <> body
  end

  defp int_to_hex(int), do: "0x" <> Integer.to_string(int, 16)

  defp filter_not_removed(logs) do
    logs |> Enum.filter(&(not Map.get(&1, "removed", true)))
  end

  defp get_ethereum_events(block_from, block_to, signature, contract) do
    topic = event_topic_for_signature(signature)

    try do
      {:ok, logs} =
        Ethereumex.HttpClient.eth_get_logs(%{
          fromBlock: int_to_hex(block_from),
          toBlock: int_to_hex(block_to),
          address: contract,
          topics: ["#{topic}"]
        })

      {:ok, filter_not_removed(logs)}
    catch
      _ -> {:error, :failed_to_get_ethereum_events}
    end
  end

  defp parse_event(%{"data" => "0x" <> data}, {signature, keys}) do
    decoded_values =
      data
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode(ABI.FunctionSelector.decode(signature))

    Enum.zip(keys, decoded_values)
    |> Map.new()
  end

  defp parse_events_with_indexed_fields(
         %{"data" => "0x" <> data, "topics" => [_event_sig | indexed_data]},
         {non_indexed_keys, non_indexed_key_types},
         {indexed_keys, indexed_keys_types}
       ) do
    decoded_non_indexed_fields =
      data
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw(non_indexed_key_types)

    non_indexed_fields =
      Enum.zip(non_indexed_keys, decoded_non_indexed_fields)
      |> Map.new()

    decoded_indexed_fields =
      for {"0x" <> encoded, type_sig} <- Enum.zip(indexed_data, indexed_keys_types) do
        [decoded] =
          encoded
          |> Base.decode16!(case: :lower)
          |> ABI.TypeDecoder.decode_raw([type_sig])

        decoded
      end

    indexed_fields =
      Enum.zip(indexed_keys, decoded_indexed_fields)
      |> Map.new()

    Map.merge(non_indexed_fields, indexed_fields)
  end
end
