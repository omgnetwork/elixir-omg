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

  alias OMG.Eth.Encoding
  alias OMG.Eth.Transaction

  @tx_defaults OMG.Eth.Defaults.tx_defaults()
  @gas_contract_default 2_500_000
  @gas_contracts %{"SignatureTest" => 1_590_893, "ERC20Mintable" => 1_590_893}

  def create_new(contract, path_project_root, from, args, opts \\ [])

  # common case for no-argument deployments
  def create_new(contract_module_name, path_project_root, from, [], opts) when is_binary(contract_module_name) do
    contract_name = contract_module_name |> to_string() |> String.split(".") |> List.last()

    gas = Map.get(@gas_contracts, contract_name, @gas_contract_default)

    deploy_contract(get_bytecode!(path_project_root, contract_name), from, gas, opts)
  end

  defp deploy_contract(bytecode, from, gas_value, types_args \\ [], opts)

  defp deploy_contract("0x", _, _, _, _) do
    {:error, :empty_bytecode_supplied}
  end

  defp deploy_contract("0x" <> _ = bytecode, from, gas_value, types_args, opts) do
    # runtime sanity-check which will fail if the bytecode isn't fully linked
    true = !String.contains?(bytecode, "$") || {:error, :unlinked_bytecode_supplied}

    defaults = Keyword.put(@tx_defaults, :gas, gas_value)
    opts = Keyword.merge(defaults, opts)
    Support.DevHelper.deploy_sync!(do_deploy_contract(from, bytecode, types_args, opts))
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
          "Can't read #{path} because #{inspect(reason)}"
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
