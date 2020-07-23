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

defmodule OMG.DB.Monitor do
  @moduledoc """
  Periodically collects and emits DB stats as telemetry events.
  """
  use GenServer
  require Logger

  alias OMG.DB
  alias OMG.DB.Monitor.MeasurementCalculation

  @type t() :: %__MODULE__{
          check_interval_ms: pos_integer(),
          db_module: module(),
          tref: reference() | nil
        }

  defstruct check_interval_ms: 5 * 60 * 1000,
            db_module: nil,
            tref: nil

  #
  # GenServer APIs
  #

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  #
  # GenServer behaviors
  #

  def init(opts) do
    _ = Logger.info("Starting #{__MODULE__}.")

    state = %__MODULE__{
      check_interval_ms: Keyword.fetch!(opts, :check_interval_ms),
      db_module: Keyword.get(opts, :db_module, DB),
      tref: nil
    }

    {:ok, state, {:continue, :start_check}}
  end

  def handle_continue(:start_check, state) do
    _ = send(self(), :check)

    {:ok, tref} = :timer.send_interval(state.check_interval_ms, self(), :check)
    {:noreply, %{state | tref: tref}}
  end

  def handle_info(:check, state) do
    stats = collect_stats(state.db_module)
    _ = :telemetry.execute([:balances, __MODULE__], %{balances: stats.balances}, %{})

    _ =
      :telemetry.execute(
        [:total_unspent_addresses, __MODULE__],
        %{total_unspent_addresses: stats.total_unspent_addresses},
        %{}
      )

    _ =
      :telemetry.execute(
        [:total_unspent_outputs, __MODULE__],
        %{total_unspent_outputs: stats.total_unspent_outputs},
        %{}
      )

    _ = Logger.info("#{__MODULE__} observed #{stats.total_unspent_outputs} unspent outputs.")
    {:noreply, state}
  end

  defp collect_stats(db) do
    {:ok, utxos} = db.utxos()

    %{
      balances: MeasurementCalculation.balances_by_currency(utxos),
      total_unspent_addresses: MeasurementCalculation.total_unspent_addresses(utxos),
      total_unspent_outputs: MeasurementCalculation.total_unspent_outputs(utxos)
    }
  end
end
