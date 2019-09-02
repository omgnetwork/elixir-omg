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

defmodule OMG.Eth.Librarian do
  @moduledoc """
  Handling of deploying libraries and contract linking with libraries
  """

  alias OMG.Eth
  alias OMG.Eth.Encoding

  @tx_defaults Eth.Defaults.tx_defaults()

  @gas_contract_libs 1_180_000

  @doc """
  Provides linked bytecode for a particular contract. All required libs are hardcoded inside.

  Note that this function deploys new instances of the required libraries and links against these.
  """
  def link_for!(contract, path_project_root, from)

  def link_for!(OMG.Eth.RootChain, path_project_root, from) do
    {:ok, _txhash, lib_addr3_pql} =
      deploy(get_bytecode!(path_project_root, "PriorityQueueLib"), from, @gas_contract_libs)

    {:ok, _txhash, lib_addr3_pqf} =
      bytecode_linked(path_project_root, "PriorityQueueFactory", [{"PriorityQueueLib", lib_addr3_pql}])
      |> deploy(from, @gas_contract_libs)

    bytecode_linked(path_project_root, "RootChain", [{"PriorityQueueFactory", lib_addr3_pqf}])
  end

  defp deploy(bytecode, from, gas) do
    opts = @tx_defaults |> Keyword.put(:gas, gas)

    {:ok, _txhash, _addr} =
      Eth.deploy_contract(from, bytecode, [], [], opts)
      |> Eth.DevHelpers.deploy_sync!()
  end

  # given a name of the contract/lib and a list of `{lib_name, lib_address}` tuples, will provide linked bytecode
  @spec bytecode_linked(binary, binary, list({binary, binary})) :: binary
  defp bytecode_linked(path_project_root, name, libs) do
    contracts_dir = Path.join(path_project_root, "_build/contracts")

    # NOTE: we need to keep the linked versions of contract binaries separate, otherwise `solc --link` overwrites
    File.copy!(Path.join(contracts_dir, "#{name}.bin"), Path.join(contracts_dir, "#{name}Linked.bin"))

    libs_arg =
      libs
      |> Enum.map(fn {lib_name, lib_addr} -> "#{lib_name}.sol:#{lib_name}:#{Encoding.to_hex(lib_addr)}" end)
      |> Enum.join(" ")

    [] =
      ~c(solc #{contracts_dir}/#{name}Linked.bin --libraries #{libs_arg} --link)
      |> :os.cmd()

    bytecode = Eth.get_bytecode!(path_project_root, "#{name}Linked")

    cleanup(contracts_dir, name)

    bytecode
  end

  defp cleanup(dir, name) do
    dir
    |> Path.join("#{name}Linked.*")
    |> Path.wildcard()
    |> Enum.each(&File.rm!/1)
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
