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

defmodule OMG.API.EthereumClientMonitor do
  @moduledoc """
  This module periodically checks Geth (every second or less) and raises an alarm
  when it can't reach the client and clears the alarm when the client connection is established again.
  """
  use GenServer
  require Logger
  alias OMG.API.Alert.Alarm
  alias OMG.Eth

  @default_interval 1_000
  @type t :: %__MODULE__{
          interval: pos_integer(),
          tref: reference() | nil
        }
  defstruct interval: @default_interval, tref: nil

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    state = %__MODULE__{}
    {:ok, tref} = :timer.send_interval(state.interval, self(), :health_check)
    _ = Logger.info("Starting Ethereum client monitor.")
    {:ok, %{state | tref: tref}}
  end

  def handle_info(:health_check, state) do
    _ = raise_clear(check())
    {:noreply, state}
  end

  def terminate(_, _), do: :ok

  @spec raise_clear(:error | non_neg_integer()) :: :ok | :duplicate
  defp raise_clear(:error), do: Alarm.raise({:ethereum_client_connection_issue, :erlang.node(), __MODULE__})
  defp raise_clear(_), do: Alarm.clear({:ethereum_client_connection_issue, :erlang.node(), __MODULE__})

  @spec check :: non_neg_integer() | :error
  defp check do
    {:ok, rootchain_height} = Eth.get_ethereum_height()
    rootchain_height
  rescue
    _ -> :error
  end
end
