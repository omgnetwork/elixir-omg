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
defmodule OMG.Eth.RootChain.Rpc do
  @moduledoc """
   Does RPC calls for enriching event functions or bare events polling to plasma contracts.
  """
  require Logger
  alias OMG.Eth.Encoding

  def call_contract(client \\ Ethereumex.HttpClient, contract, signature, args, from) do
    data = signature |> ABI.encode(args) |> Encoding.to_hex()
    client.eth_call(%{from: from, to: contract, data: data})
  end

  def get_ethereum_events(block_from, block_to, [_ | _] = signatures, [_ | _] = contracts) do
    topics = Enum.map(signatures, fn signature -> event_topic_for_signature(signature) end)

    topics_and_signatures =
      Enum.reduce(Enum.zip(topics, signatures), %{}, fn {topic, signature}, acc -> Map.put(acc, topic, signature) end)

    contracts = Enum.map(contracts, &Encoding.to_hex(&1))
    block_from = Encoding.to_hex(block_from)
    block_to = Encoding.to_hex(block_to)

    params = %{
      fromBlock: block_from,
      toBlock: block_to,
      address: contracts,
      topics: [topics]
    }

    {:ok, logs} = Ethereumex.HttpClient.eth_get_logs(params)
    filtered_and_enriched_logs = handle_result(logs, topics, topics_and_signatures)
    {:ok, filtered_and_enriched_logs}
  end

  def get_ethereum_events(block_from, block_to, [_ | _] = signatures, contract) do
    get_ethereum_events(block_from, block_to, signatures, [contract])
  end

  def get_ethereum_events(block_from, block_to, signature, [_ | _] = contracts) do
    get_ethereum_events(block_from, block_to, [signature], contracts)
  end

  def get_ethereum_events(block_from, block_to, signature, contract) do
    get_ethereum_events(block_from, block_to, [signature], [contract])
  end

  def get_call_data(root_chain_txhash) do
    {:ok, %{"input" => input}} =
      root_chain_txhash
      |> Encoding.to_hex()
      |> Ethereumex.HttpClient.eth_get_transaction_by_hash()

    {:ok, input}
  end

  defp event_topic_for_signature(signature) do
    signature
    |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
    |> Encoding.to_hex()
  end

  defp handle_result(logs, topics, topics_and_signatures) do
    acc = []
    handle_result(logs, topics, topics_and_signatures, acc)
  end

  defp handle_result([], _topics, _topics_and_signatures, acc), do: acc

  defp handle_result([%{"removed" => true} | _logs], _topics, _topics_and_signatures, acc) do
    acc
  end

  defp handle_result([log | logs], topics, topics_and_signatures, acc) do
    topic = Enum.find(topics, fn topic -> Enum.at(log["topics"], 0) == topic end)
    enriched_log = put_signature(log, Map.get(topics_and_signatures, topic))
    handle_result(logs, topics, topics_and_signatures, [enriched_log | acc])
  end

  defp put_signature(log, signature), do: Map.put(log, :event_signature, signature)
end
