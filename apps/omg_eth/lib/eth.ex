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

defmodule OMG.Eth do
  @moduledoc """
  Library for common code of the adapter/port to contracts deployed on Ethereum.

  NOTE: The library code is not intended to be used outside of `OMG.Eth`: use `OMG.Eth.RootChain` and `OMG.Eth.Token` as main
  entrypoints to the contract-interaction functionality.

  NOTE: This wrapper is intended to be as thin as possible, only offering a consistent API to the Ethereum JSONRPC client and contracts.

  Handles other non-contract queries to the Ethereum client.

  Notes on encoding: All APIs of `OMG.Eth` and the submodules with contract APIs always use raw, decoded binaries
  for binaries - never use hex encoded binaries. Such binaries may be passed as is onto `ABI` related functions,
  however they must be encoded/decoded when entering/leaving the `Ethereumex` realm
  """

  alias OMG.Eth.Config
  alias OMG.Eth.RootChain
  alias OMG.Eth.RootChain.SubmitBlock

  require Logger
  import OMG.Eth.Encoding, only: [from_hex: 1, to_hex: 1, int_from_hex: 1]

  @type address :: <<_::160>>
  @type hash :: <<_::256>>
  @type send_transaction_opts() :: [send_transaction_option()]
  @type send_transaction_option() :: {:passphrase, binary()}

  @spec node_ready() :: :ok | {:error, :geth_still_syncing | :geth_not_listening}
  def node_ready() do
    case Ethereumex.HttpClient.eth_syncing() do
      {:ok, false} -> :ok
      {:ok, _} -> {:error, :geth_still_syncing}
      {:error, :econnrefused} -> {:error, :geth_not_listening}
    end
  end

  @doc """
  Checks geth syncing status, errors are treated as not synced.
  Returns:
  * false - geth is synced
  * true  - geth is still syncing.
  """
  @spec syncing?() :: boolean
  def syncing?(), do: node_ready() != :ok

  def get_ethereum_height() do
    case Ethereumex.HttpClient.eth_block_number() do
      {:ok, height_hex} ->
        {:ok, int_from_hex(height_hex)}

      other ->
        other
    end
  end

  def get_block_timestamp_by_number(height) do
    case Ethereumex.HttpClient.eth_get_block_by_number(to_hex(height), false) do
      {:ok, %{"timestamp" => timestamp_hex}} ->
        {:ok, int_from_hex(timestamp_hex)}

      other ->
        other
    end
  end

  @doc """
  Returns placeholder for non-existent Ethereum address
  """
  @spec zero_address() :: address()
  def zero_address(), do: <<0::160>>

  def call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args)

    with {:ok, return} <- Ethereumex.HttpClient.eth_call(%{to: to_hex(contract), data: to_hex(data)}),
         do: decode_answer(return, return_types)
  end

  defp decode_answer(enc_return, return_types) do
    enc_return
    |> from_hex()
    |> ABI.TypeDecoder.decode(return_types)
    |> case do
      [single_return] -> {:ok, single_return}
      other when is_list(other) -> {:ok, List.to_tuple(other)}
    end
  end

  @spec submit_block(
          binary(),
          pos_integer(),
          pos_integer(),
          RootChain.optional_address_t(),
          RootChain.optional_address_t()
        ) ::
          {:error, binary() | atom() | map()} | {:ok, binary()}
  def submit_block(hash, nonce, gas_price, from \\ nil, contract \\ %{}) do
    contract = Config.maybe_fetch_addr!(contract, :plasma_framework)
    from = from || from_hex(Application.fetch_env!(:omg_eth, :authority_addr))
    backend = Application.fetch_env!(:omg_eth, :eth_node)
    SubmitBlock.submit(backend, hash, nonce, gas_price, from, contract)
  end

  defp event_topic_for_signature(signature) do
    signature
    |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
    |> to_hex()
  end

  defp filter_not_removed(logs) do
    Enum.filter(logs, &(not Map.get(&1, "removed", false)))
  end

  def get_ethereum_events(block_from, block_to, signature, contract) do
    topic = event_topic_for_signature(signature)

    try do
      {:ok, logs} =
        Ethereumex.HttpClient.eth_get_logs(%{
          fromBlock: to_hex(block_from),
          toBlock: to_hex(block_to),
          address: to_hex(contract),
          topics: ["#{topic}"]
        })

      {:ok, logs |> filter_not_removed() |> put_signature(signature)}
    catch
      _ -> {:error, :failed_to_get_ethereum_events}
    end
  end

  def parse_event(%{"data" => data} = log, {signature, keys}) do
    decoded_values =
      data
      |> from_hex()
      |> ABI.TypeDecoder.decode(ABI.FunctionSelector.decode(signature))

    Enum.zip(keys, decoded_values)
    |> Map.new()
    |> common_parse_event(log)
  end

  def parse_events_with_indexed_fields(
        %{"data" => data, "topics" => [_event_sig | indexed_data]} = log,
        {non_indexed_keys, non_indexed_key_types},
        {indexed_keys, indexed_keys_types}
      ) do
    decoded_non_indexed_fields =
      data
      |> from_hex()
      |> ABI.TypeDecoder.decode(non_indexed_key_types)

    non_indexed_fields =
      Enum.zip(non_indexed_keys, decoded_non_indexed_fields)
      |> Map.new()

    decoded_indexed_fields =
      for {encoded, type_sig} <- Enum.zip(indexed_data, indexed_keys_types) do
        [decoded] =
          encoded
          |> from_hex()
          |> ABI.TypeDecoder.decode([type_sig])

        decoded
      end

    indexed_fields =
      Enum.zip(indexed_keys, decoded_indexed_fields)
      |> Map.new()

    Map.merge(non_indexed_fields, indexed_fields)
    |> common_parse_event(log)
  end

  @doc """
  Gets the decoded call data of a contract call, based on a particular Ethereum-tx hash and some info on the contract
  function.

  `eth_tx_hash` is expected encoded in raw binary format, as usual

  If `unpack_tuple_args` named argument is provided it is interpreted as a list of atoms representing names of arguments
  which are packed into a tuple named `args` in the contract functions signature.

  NOTE: function name and rich information about argument names and types is used, rather than its compact signature
  (like elsewhere) because `ABI.decode` has some issues with parsing signatures in this context.
  """
  @spec get_call_data(binary(), binary(), list(atom), list(binary), keyword()) :: map()
  def get_call_data(eth_tx_hash, name, arg_names, arg_types, opts \\ [])

  def get_call_data(eth_tx_hash, name, arg_names, arg_types, opts) do
    {:ok, %{"input" => eth_tx_input}} = Ethereumex.HttpClient.eth_get_transaction_by_hash(to_hex(eth_tx_hash))
    encoded_input = from_hex(eth_tx_input)

    function_inputs =
      ABI.decode(
        ABI.FunctionSelector.parse_specification_item(%{
          "type" => "function",
          "name" => name,
          "inputs" => Enum.map(arg_types, &%{"type" => to_string(&1)}),
          "outputs" => []
        }),
        encoded_input
      )

    call_data_raw = Map.new(Enum.zip(arg_names, function_inputs))

    unpack_tuple_args = Keyword.get(opts, :unpack_tuple_args, false)
    if unpack_tuple_args, do: parse_tuple_args(call_data_raw, unpack_tuple_args), else: call_data_raw
  end

  @doc """
  Enrichs the decoded log data from the Eth node, by getting the respective transaction's function call to the contract
  and dissecting it using the name, args and argument types as specified. The call data is put under `:call_data`.

  Passes on the optional arguments into `Eth.get_call_data`
  """
  @spec log_with_call_data(
          %{required(:root_chain_txhash) => binary, optional(atom) => any},
          binary,
          list(atom),
          list(binary),
          keyword()
        ) :: map()
  def log_with_call_data(log, function_name, args, types, opts \\ []) do
    call_data = get_call_data(log.root_chain_txhash, function_name, args, types, opts)
    Map.put(log, :call_data, call_data)
  end

  # interprets an argument called `args` in the call_data (arguments) and reinterprets the arguments according to names
  # given
  defp parse_tuple_args(call_data, tuple_arg_names) do
    tuple_args = call_data |> Map.fetch!(:args) |> Tuple.to_list()
    tuple_arg_names |> Enum.zip(tuple_args) |> Map.new()
  end

  # here we merge the result of event parsing so far (holding the fields)
  defp common_parse_event(
         result,
         %{"blockNumber" => eth_height, "transactionHash" => root_chain_txhash, "logIndex" => log_index} = event
       ) do
    # NOTE: we're using `put_new` here, because `merge` would allow us to overwrite data fields in case of conflict
    result
    |> Map.put_new(:eth_height, int_from_hex(eth_height))
    |> Map.put_new(:root_chain_txhash, from_hex(root_chain_txhash))
    |> Map.put_new(:log_index, int_from_hex(log_index))
    # just copy `event_signature` over, if it's present (could use tidying up)
    |> Map.put_new(:event_signature, event[:event_signature])
  end

  defp put_signature(events, signature), do: Enum.map(events, &Map.put(&1, :event_signature, signature))
end
