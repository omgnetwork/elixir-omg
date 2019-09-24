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

  @gas_contract_rootchain 5_000_000
  @gas_contract_default 2_000_000
  @gas_contracts %{"SignatureTest" => 1_590_893, "ERC20Mintable" => 1_590_893}

  def create_new(contract, path_project_root, from, args, opts \\ [])

  # special case so that we have a civil name for the Token contract
  def create_new(OMG.Eth.Token, path_project_root, from, [], opts) do
    gas = Map.get(@gas_contracts, "ERC20Mintable", @gas_contract_rootchain)

    get_bytecode!(path_project_root, "ERC20Mintable")
    |> deploy_contract(from, gas, opts)
  end

  def create_new(OMG.Eth.PaymentEip712LibMock, path_project_root, from, [], opts) do
    gas = Map.get(@gas_contracts, "PaymentEip712LibMock", @gas_contract_rootchain)

    get_bytecode!(path_project_root, "PaymentEip712LibMock")
    |> deploy_contract(from, gas, opts)
  end

  # common case for no-argument deployments
  def create_new(contract_module_name, path_project_root, from, [], opts) when is_binary(contract_module_name) do
    contract_name = contract_module_name |> to_string() |> String.split(".") |> List.last()

    gas = Map.get(@gas_contracts, contract_name, @gas_contract_default)

    get_bytecode!(path_project_root, contract_name)
    |> deploy_contract(from, gas, opts)
  end

  def create_new("PlasmaFramework" = name, path_project_root, from, [exit_period_seconds: exit_period_seconds], opts) do
    args = [{{:uint, 256}, exit_period_seconds}, {{:uint, 256}, 2}, {{:uint, 256}, 1}]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_rootchain, args, opts)
  end

  def create_new("EthVault" = name, path_project_root, from, [plasma_framework: plasma_framework], opts) do
    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, [{:address, plasma_framework}], opts)
  end

  def create_new("Erc20Vault" = name, path_project_root, from, [plasma_framework: plasma_framework], opts) do
    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, [{:address, plasma_framework}], opts)
  end

  def create_new(
        "PaymentOutputGuardHandler" = name,
        path_project_root,
        from,
        [payment_output_type_marker: payment_output_type_marker],
        opts
      ) do
    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, [{{:uint, 256}, payment_output_type_marker}], opts)
  end

  def create_new(
        "PaymentExitGame" = name,
        path_project_root,
        from,
        [
          plasma_framework: plasma_framework,
          eth_vault: eth_vault,
          erc20_vault: erc20_vault,
          output_guard_handler: output_guard_handler,
          spending_condition: spending_condition
        ],
        opts
      ) do
    args = [
      {:address, plasma_framework},
      {:address, eth_vault},
      {:address, erc20_vault},
      {:address, output_guard_handler},
      {:address, spending_condition}
    ]

    Eth.Librarian.link_for!(name, path_project_root, from)
    |> deploy_contract(from, @gas_contract_default, args, opts)
  end

  defp deploy_contract(bytecode, from, gas_value, types_args \\ [], opts)

  defp deploy_contract("0x", _, _, _, _) do
    {:error, :empty_bytecode_supplied}
  end

  defp deploy_contract(bytecode, from, gas_value, types_args, opts) do
    defaults = @tx_defaults |> Keyword.put(:gas, gas_value)
    opts = defaults |> Keyword.merge(opts)

    {types, args} = Enum.unzip(types_args)

    Eth.deploy_contract(from, bytecode, types, args, opts)
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
