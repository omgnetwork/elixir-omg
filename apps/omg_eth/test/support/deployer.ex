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

defmodule Support.Deployer do
  @moduledoc """
  Handling of contract deployments - intended only for testing and `:dev` environment
  """

  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias OMG.Eth.Transaction

  @tx_defaults Eth.Defaults.tx_defaults()

  @gas_contract_rootchain 5_000_000
  @gas_contract_default 2_000_000
  @gas_contract_payment_exit_game 6_000_000
  @gas_contracts %{"SignatureTest" => 1_590_893, "ERC20Mintable" => 1_590_893}

  def create_new(contract, path_project_root, from, args, opts \\ [])

  # common case for no-argument deployments
  def create_new(contract_module_name, path_project_root, from, [], opts) when is_binary(contract_module_name) do
    contract_name = contract_module_name |> to_string() |> String.split(".") |> List.last()

    gas = Map.get(@gas_contracts, contract_name, @gas_contract_default)

    get_bytecode!(path_project_root, contract_name)
    |> deploy_contract(from, gas, opts)
  end

  def create_new(
        "PlasmaFramework" = name,
        path_project_root,
        from,
        [min_exit_period_seconds: min_exit_period_seconds, authority: authority, maintainer: maintainer],
        opts
      ) do
    args = [
      {{:uint, 256}, min_exit_period_seconds},
      {{:uint, 256}, 2},
      {{:uint, 256}, 1},
      {:address, authority},
      {:address, maintainer}
    ]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_rootchain, args, opts)
  end

  def create_new(
        "EthDepositVerifier" = name,
        path_project_root,
        from,
        [transaction_type: transaction_type, output_type: output_type],
        opts
      ) do
    args = [
      {{:uint, 256}, transaction_type},
      {{:uint, 256}, output_type}
    ]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, args, opts)
  end

  def create_new(
        "Erc20DepositVerifier" = name,
        path_project_root,
        from,
        [transaction_type: transaction_type, output_type: output_type],
        opts
      ) do
    args = [
      {{:uint, 256}, transaction_type},
      {{:uint, 256}, output_type}
    ]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, args, opts)
  end

  def create_new(
        "EthVault" = name,
        path_project_root,
        from,
        [plasma_framework: plasma_framework, safe_gas_stipend: safe_gas_stipend],
        opts
      ) do
    args = [
      {:address, plasma_framework},
      {{:uint, 256}, safe_gas_stipend}
    ]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, args, opts)
  end

  def create_new(
        "Erc20Vault" = name,
        path_project_root,
        from,
        [plasma_framework: plasma_framework, safe_gas_stipend: safe_gas_stipend],
        opts
      ) do
    args = [
      {:address, plasma_framework},
      {{:uint, 256}, safe_gas_stipend}
    ]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, args, opts)
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
          eth_vault_id: eth_vault_id,
          erc20_vault_id: erc20_vault_id,
          output_guard_handler: output_guard_handler,
          spending_condition: spending_condition,
          payment_transaction_state_transition_verifier: payment_transaction_state_transition_verifier,
          tx_finalization_verifier: tx_finalization_verifier,
          tx_type: tx_type,
          safe_gas_stipend: safe_gas_stipend,
        ],
        opts
      ) do
    args = [
      # This 2-element tuple represents the `PaymentExitGame.PaymentExitGameArgs` solidity struct.
      {:tuple, [
        {:address, plasma_framework},
        {{:uint, 256}, eth_vault_id},
        {{:uint, 256}, erc20_vault_id},
        {:address, output_guard_handler},
        {:address, spending_condition},
        {:address, payment_transaction_state_transition_verifier},
        {:address, tx_finalization_verifier},
        {{:uint, 256}, tx_type},
        {{:uint, 256}, safe_gas_stipend}
      ]}
    ]

    Eth.Librarian.link_for!(name, path_project_root, from)
    |> deploy_contract(from, @gas_contract_payment_exit_game, args, opts)
  end

  def create_new(
        "PaymentOutputToPaymentTxCondition" = name,
        path_project_root,
        from,
        [plasma_framework: plasma_framework, input_tx_type: input_tx_type, spending_tx_type: spending_tx_type],
        opts
      ) do
    args = [{:address, plasma_framework}, {{:uint, 256}, input_tx_type}, {{:uint, 256}, spending_tx_type}]

    get_bytecode!(path_project_root, name)
    |> deploy_contract(from, @gas_contract_default, args, opts)
  end

  defp deploy_contract(bytecode, from, gas_value, types_args \\ [], opts)

  defp deploy_contract("0x", _, _, _, _) do
    {:error, :empty_bytecode_supplied}
  end

  defp deploy_contract(bytecode, from, gas_value, types_args, opts) do
    defaults = @tx_defaults |> Keyword.put(:gas, gas_value)
    opts = Keyword.merge(defaults, opts)

    do_deploy_contract(from, bytecode, types_args, opts)
    |> Support.DevHelper.deploy_sync!()
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

  def do_deploy_contract(addr, bytecode, types_args, opts) do
    enc_args = Encoding.encode_constructor_params(types_args)

    txmap =
      %{from: Encoding.to_hex(addr), data: bytecode <> enc_args}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    backend = Application.fetch_env!(:omg_eth, :eth_node)
    {:ok, _txhash} = Transaction.send(backend, txmap)
  end

  defp encode_all_integer_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> is_integer(v) end)
    |> Enum.into(opts, fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end
end
