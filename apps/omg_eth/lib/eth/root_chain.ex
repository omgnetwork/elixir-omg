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

  @deposit_created_signature "DepositCreated(address,uint256,address,uint256)"

  @type optional_addr_t() :: <<_::160>> | nil

  @gas_start_exit 1_000_000
  @gas_deposit 180_000
  @gas_deposit_from 250_000
  @gas_init 1_000_000
  @standard_exit_bond 31_415_926_535

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

  def start_exit(outputId, txbytes, proof, from, contract \\ nil, opts \\ []) do
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
      [outputId, txbytes, proof],
      opts
    )
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

  def challenge_exit(outputId, challengeTx, inputIndex, challengeTxSig, from, contract \\ nil, opts \\ []) do
    opts = @tx_defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    signature = "challengeStandardExit(uint192,bytes,uint256,bytes)"
    args = [outputId, challengeTx, inputIndex, challengeTxSig]
    Eth.contract_transact(from, contract, signature, args, opts)
  end

  def init(from \\ nil, contract \\ nil, opts \\ []) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_init)
    opts = defaults |> Keyword.merge(opts)

    contract = contract || from_hex(Application.fetch_env!(:omg_eth, :contract_addr))
    from = from || from_hex(Application.fetch_env!(:omg_eth, :authority_addr))

    Eth.contract_transact(from, contract, "init()", [], opts)
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
    Eth.call_contract(contract, "getStandardExitId(uint256)", [utxo_pos], [{:uint, 256}])
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

    with {:ok, logs} <- Eth.get_ethereum_events(block_from, block_to, @deposit_created_signature, contract),
         do: {:ok, Enum.map(logs, &decode_deposit/1)}
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

  defp decode_exit_challenged(log) do
    # faux-DRY - just leveraging that these events happen to have exactly the same fields/indexings, in current impl.
    decode_exit_finalized(log)
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
      @deposit_created_signature
      |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
      |> to_hex()

    [%{blknum: deposit_blknum}] =
      logs
      |> Enum.filter(&(topic in &1["topics"]))
      |> Enum.map(&decode_deposit/1)

    deposit_blknum
  end
end
