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

defmodule OMG.Watcher.API do
  @moduledoc """
  An Elixir-API for all the Watcher calls.

  Intended to be called either from within an BEAM app or from some transport layer (e.g. HTTP-RPC)
  """
  alias OMG.Watcher.API.InFlights

  @doc """
  Get's all of the locally known in-flight transactions, along with the `RootChain.sol` friendly data to start an
  in-flight exit

  NOTE: this endpoint might be superceded by `get_in_flight_extis/1` which gets IFEs for all in-flight transactions
  """
  def get_in_flight_exit(tx) do
    InFlights.get_in_flight_exit(tx)
  end
end
