# Copyright 2019 OmiseGO Pte Ltd
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
  Adapter/port to tokens that implement ERC20 interface
  """

  alias OMG.Eth.Encoding
  alias OMG.Eth.TransactionHelper

  @tx_defaults OMG.Eth.Defaults.tx_defaults()

  @gas_token_ops 80_000

  ##########
  # writes #
  ##########

  def mint(owner, amount, token, opts \\ []) do
    opts = @tx_defaults |> Keyword.put(:gas, @gas_token_ops) |> Keyword.merge(opts)

    {:ok, [from | _]} = Ethereumex.HttpClient.eth_accounts()
    backend = Application.fetch_env!(:omg_eth, :eth_node)

    TransactionHelper.contract_transact(
      backend,
      Encoding.from_hex(from),
      token,
      "mint(address,uint256)",
      [owner, amount],
      opts
    )
  end

  def transfer(from, owner, amount, token, opts \\ []) do
    opts = @tx_defaults |> Keyword.put(:gas, @gas_token_ops) |> Keyword.merge(opts)
    backend = Application.fetch_env!(:omg_eth, :eth_node)
    TransactionHelper.contract_transact(backend, from, token, "transfer(address,uint256)", [owner, amount], opts)
  end

  def approve(from, spender, amount, token, opts \\ []) do
    opts = @tx_defaults |> Keyword.put(:gas, @gas_token_ops) |> Keyword.merge(opts)
    backend = Application.fetch_env!(:omg_eth, :eth_node)
    TransactionHelper.contract_transact(backend, from, token, "approve(address,uint256)", [spender, amount], opts)
  end
end
