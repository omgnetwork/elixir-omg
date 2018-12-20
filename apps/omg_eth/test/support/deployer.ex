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

defmodule OMG.Eth.Deployer do
  @moduledoc """
  Handling of contract deployments - intended only for testing and `:dev` environment
  """

  alias OMG.Eth

  @tx_defaults Eth.Defaults.tx_defaults()

  @gas_contract_rootchain 6_180_000
  @gas_contract_token 1_590_893

  def create_new(contract, path_project_root, from, opts \\ [])

  def create_new(OMG.Eth.RootChain, path_project_root, from, opts) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_contract_rootchain)
    opts = defaults |> Keyword.merge(opts)

    rootchain_bytecode = Eth.Librarian.link_for!(OMG.Eth.RootChain, path_project_root, from)

    Eth.deploy_contract(from, rootchain_bytecode, [], [], opts)
    |> Eth.DevHelpers.deploy_sync!()
  end

  def create_new(OMG.Eth.Token, path_project_root, from, opts) do
    defaults = @tx_defaults |> Keyword.put(:gas, @gas_contract_token)
    opts = defaults |> Keyword.merge(opts)

    bytecode = Eth.get_bytecode!(path_project_root, "MintableToken")

    Eth.deploy_contract(from, bytecode, [], [], opts)
    |> Eth.DevHelpers.deploy_sync!()
  end
end
