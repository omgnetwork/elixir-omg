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

defmodule OMG.Watcher.BlockGetter.Supervisor do
  @moduledoc """
  This supervisor takes care of BlockGetter and State processes.
  In case one process fails, this supervisor's role is to restore consistent state
  """
  use Supervisor
  use OMG.Utils.LoggerExt

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # State and Block Getter are linked, because they must restore their state to the last stored state
    # If Block Getter fails, it starts from the last checkpoint while State might have had executed some transactions
    # such a situation will cause error when trying to execute already executed transaction
    children = [
      # NOTE: Watcher doesn't need the actual fee claimer address
      {OMG.State, [fee_claimer_address: Base.decode16!("DEAD000000000000000000000000000000000000")]},
      %{
        id: OMG.Watcher.BlockGetter,
        start: {OMG.Watcher.BlockGetter, :start_link, [[]]},
        restart: :transient
      }
    ]

    opts = [strategy: :one_for_all]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
