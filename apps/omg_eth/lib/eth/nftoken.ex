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

defmodule OMG.Eth.NFToken do
  @moduledoc """
  Adapter/port to tokens that implement ERC721 interface
  """

  alias OMG.Eth

  import Eth.Encoding

  @tx_defaults Eth.Defaults.tx_defaults()

  ##########
  # writes #
  ##########

  def mint(owner, tokenid, token, opts \\ @tx_defaults) do
    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    Eth.contract_transact(from_hex(from), token, "mint(address,uint256)", [owner, tokenid], opts)
  end

  def transfer(from, owner, tokenid, token, opts \\ @tx_defaults) do
    Eth.contract_transact(from, token, "transfer(address,uint256)", [owner, tokenid], opts)
  end

  def approve(from, spender, tokenid, token, opts \\ @tx_defaults) do
    Eth.contract_transact(from, token, "approve(address,uint256)", [spender, tokenid], opts)
  end

  #########
  # reads #
  #########

  def balance_of(owner, token) do
    Eth.call_contract(token, "balanceOf(address)", [owner], [{:uint, 256}])
  end
end
