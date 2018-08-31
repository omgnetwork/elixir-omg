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

defmodule OMG.Eth.Token do
  @moduledoc """
  Adapter/port to tokens that implement ERC20 interface.
  """

  alias OMG.Eth

  ##########
  # writes #
  ##########

  def mint(owner, amount, token) do
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    Eth.contract_transact_sync!(from, nil, nil, token, "mint(address,uint256)", [Eth.cleanup(owner), amount])
  end

  def transfer(from, owner, amount, token) do
    Eth.contract_transact_sync!(from, nil, nil, token, "transfer(address,uint256)", [Eth.cleanup(owner), amount])
  end

  def approve(from, spender, amount, token) do
    Eth.contract_transact_sync!(from, nil, nil, token, "approve(address,uint256)", [Eth.cleanup(spender), amount])
  end

  def create_new(path_project_root, addr) do
    bytecode = Eth.get_bytecode!(path_project_root, "MintableToken")
    Eth.deploy_contract(addr, bytecode, [], [], "0x18466d")
  end

  #########
  # reads #
  #########

  def balance_of(owner, token) do
    {:ok, {balance}} = Eth.call_contract(token, "balanceOf(address)", [Eth.cleanup(owner)], [{:uint, 256}])
    {:ok, balance}
  end
end
