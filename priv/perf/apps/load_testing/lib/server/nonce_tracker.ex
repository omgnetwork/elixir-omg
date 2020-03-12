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

defmodule LoadTesting.Server.NonceTracker do
  @moduledoc """
  Nonce tracker for sending Ethereum transactions
  """
  use GenServer

  alias ExPlasma.Encoding

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def update_nonce(addr) do
    GenServer.call(__MODULE__, {:update_nonce, addr}, :infinity)
  end

  def init(_) do
    {:ok, Map.new()}
  end

  def handle_call({:update_nonce, addr}, _from, state) do
    current_nonce =
      case Map.fetch(state, addr) do
        :error ->
          addr
          |> Encoding.to_hex()
          |> Ethereumex.HttpClient.eth_get_transaction_count("pending")
          |> elem(1)
          |> Encoding.to_int()

        {:ok, nonce} ->
          nonce
      end

    {:reply, {:ok, current_nonce}, Map.put(state, addr, current_nonce + 1)}
  end
end
