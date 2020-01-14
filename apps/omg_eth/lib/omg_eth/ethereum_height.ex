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

defmodule OMG.Eth.EthereumHeight do
  @moduledoc """
  A GenServer that subscribes to `newHeads` events coming from the internal event bus, decodes and saves only the height to be consumed
  by other services.
  """

  use GenServer
  require Logger
  alias OMG.Eth
  alias OMG.Eth.Encoding

  @spec get() :: {:ok, non_neg_integer()} | {:error, :error_ethereum_height}
  def get do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(opts) do
    event_bus = Keyword.get(opts, :event_bus)
    :ok = event_bus.subscribe("newHeads", link: true)
    {:ok, get_ethereum_height()}
  end

  def handle_call(:get, _from, ethereum_height) when is_atom(ethereum_height) do
    {:reply, {:error, ethereum_height}, ethereum_height}
  end

  def handle_call(:get, _from, ethereum_height) do
    {:reply, {:ok, ethereum_height}, ethereum_height}
  end

  def handle_info({:internal_event_bus, :newHeads, new_heads}, state) do
    value = new_heads["params"]["result"]["number"]

    case is_binary(value) do
      true ->
        ethereum_height = Encoding.int_from_hex(value)
        _ = Logger.debug("#{__MODULE__} got a newHeads event for new Ethereum height #{ethereum_height}.")
        {:noreply, ethereum_height}

      false ->
        {:noreply, state}
    end
  end

  @spec get_ethereum_height :: non_neg_integer() | :error_ethereum_height
  defp get_ethereum_height do
    {:ok, rootchain_height} = eth().get_ethereum_height()
    rootchain_height
  rescue
    _check_error -> :error_ethereum_height
  end

  defp eth, do: Application.get_env(:omg_eth, :eth_integration_module, Eth)
end
