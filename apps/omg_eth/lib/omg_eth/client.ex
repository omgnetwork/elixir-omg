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
defmodule OMG.Eth.Client do
  @moduledoc """
    Interface to Ethereum Client (not plasma contracts)
  """
  alias OMG.Eth.Encoding

  @spec get_ethereum_height() :: {:ok, non_neg_integer()} | Ethereumex.Client.Behaviour.error()
  @spec get_ethereum_height(module()) :: {:ok, non_neg_integer()} | Ethereumex.Client.Behaviour.error()
  def get_ethereum_height(client \\ Ethereumex.HttpClient) do
    case client.eth_block_number() do
      {:ok, height_hex} ->
        {:ok, Encoding.int_from_hex(height_hex)}

      other ->
        other
    end
  end

  @spec node_ready() :: :ok | {:error, :geth_still_syncing | :geth_not_listening}
  @spec node_ready(module()) :: :ok | {:error, :geth_still_syncing | :geth_not_listening}
  def node_ready(client \\ Ethereumex.HttpClient) do
    case client.eth_syncing() do
      {:ok, false} -> :ok
      {:ok, _} -> {:error, :geth_still_syncing}
      {:error, :econnrefused} -> {:error, :geth_not_listening}
    end
  end

  def get_transaction_by_hash(tx_hash, client \\ Ethereumex.HttpClient) do
    tx_hash_hex = Encoding.to_hex(tx_hash)
    client.eth_get_transaction_by_hash(tx_hash_hex)
  end
end
