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
defmodule OMG.Eth.Config do
  @moduledoc """
  The point where we retrieve omg_eth contract application configuration.
  """
  alias OMG.Eth
  alias OMG.Eth.Encoding

  @doc """
  Gets a particular contract's address (by name) from somewhere
  `maybe_fetch_addr!(%{}, name)` will `Application.fetch_env!`, get the correct entry and decode
  Otherwise it just returns the entry from whatever the map provided, assuming it's decoded already
  """
  @spec maybe_fetch_addr!(%{atom => Eth.address()}, atom) :: Eth.address()
  def maybe_fetch_addr!(contract, name) do
    contract[name] || Encoding.from_hex(Application.fetch_env!(:omg_eth, :contract_addr)[name])
  end
end
