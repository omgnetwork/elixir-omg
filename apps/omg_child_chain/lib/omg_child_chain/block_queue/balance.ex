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

defmodule OMG.ChildChain.BlockQueue.Balance do
  @moduledoc """
    Takes the transaction hash and puts it in the  FIFO queue
  for each transaction hash we're trying to get the gas we've used to submit the block and send it of as a telemetry event
  to datadog
  """
  require Logger
  defstruct authority_address: nil, rpc: Ethereumex.HttpClient

  def check(server \\ __MODULE__) do
    GenServer.cast(server, :check)
  end

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      type: :worker
    }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) do
    authority_address = Keyword.fetch!(args, :authority_address)
    {:ok, %__MODULE__{authority_address: authority_address}}
  end

  def handle_cast(:check, state) do
    {:ok, hex_authority_balance} = state.rpc.eth_get_balance(state.authority_address)
    authority_balance = parse_balance(hex_authority_balance)
    _ = Logger.info("Authority address #{state.authority_address} balance #{authority_balance} Wei.")
    _ = :telemetry.execute([:authority_balance, __MODULE__], %{authority_balance: authority_balance}, %{})
    {:noreply, state}
  end

  defp parse_balance(data) do
    {value, ""} = data |> String.replace_prefix("0x", "") |> Integer.parse(16)
    value
  end
end
