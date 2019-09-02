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

defmodule OMG.Eth.Deployer do
  @moduledoc """
  Handling of contract deployments - intended only for testing and `:dev` environment
  """

  alias OMG.Eth

  @tx_defaults Eth.Defaults.tx_defaults()

  @gas_contract_rootchain 6_180_000
  @gas_contract_token 1_590_893
  @gas_contract_sigtest 1_590_893

  def create_new(contract, path_project_root, from, opts \\ [])

  def create_new(OMG.Eth.RootChain, path_project_root, from, opts) do
    Eth.Librarian.link_for!(OMG.Eth.RootChain, path_project_root, from)
    |> deploy_contract(from, @gas_contract_rootchain, opts)
  end

  def create_new(OMG.Eth.Token, path_project_root, from, opts) do
    get_bytecode!(path_project_root, "MintableToken")
    |> deploy_contract(from, @gas_contract_token, opts)
  end

  def create_new(OMG.Eth.Eip712, path_project_root, from, opts) do
    get_bytecode!(path_project_root, "SignatureTest")
    |> deploy_contract(from, @gas_contract_sigtest, opts)
  end

  defp deploy_contract(bytecode, from, gas_value, opts) do
    defaults = @tx_defaults |> Keyword.put(:gas, gas_value)
    opts = defaults |> Keyword.merge(opts)

    Eth.deploy_contract(from, bytecode, [], [], opts)
    |> Eth.DevHelpers.deploy_sync!()
  end

  defp get_bytecode!(path_project_root, contract_name) do
    "0x" <> read_contracts_bin!(path_project_root, contract_name)
  end

  defp read_contracts_bin!(path_project_root, contract_name) do
    path = "_build/contracts/#{contract_name}.bin"

    case File.read(Path.join(path_project_root, path)) do
      {:ok, contract_json} ->
        contract_json

      {:error, reason} ->
        raise(
          RuntimeError,
          "Can't read #{path} because #{inspect(reason)}, try running mix deps.compile plasma_contracts"
        )
    end
  end
end
