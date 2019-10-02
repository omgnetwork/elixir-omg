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

  @gas_contract_libs 3_000_000

  @doc """
  Provides linked bytecode for a particular contract. All required libs are hardcoded inside.

  Note that this function deploys new instances of the required libraries and links against these.
  """
  def link_for!(contract, path_project_root, from)

  def link_for!("PaymentExitGame" = name, path_project_root, from) do
    paths = [
      "plasma_contracts/plasma_framework/contracts/src/exits/payment/controllers/PaymentStartStandardExit.sol",
      "plasma_contracts/plasma_framework/contracts/src/exits/payment/controllers/PaymentChallengeStandardExit.sol",
      "plasma_contracts/plasma_framework/contracts/src/exits/payment/controllers/PaymentProcessStandardExit.sol"
    ]

    names = get_lib_names(paths)

    libs = deploy_libs!(names, path_project_root, from, @gas_contract_libs)

    paths_names_and_libs = Enum.zip([paths, names, libs])
    bytecode_linked(path_project_root, name, paths_names_and_libs)
  end

  defp get_lib_names(paths),
    do: paths |> Enum.map(&Path.basename/1) |> Enum.map(&Path.rootname/1)

  defp deploy_libs!(names, path_project_root, from, gas) do
    names
    |> Enum.map(&get_bytecode!(path_project_root, &1))
    |> Enum.map(&deploy!(&1, from, gas))
  end

  defp deploy(bytecode, from, gas) do
    opts = @tx_defaults |> Keyword.put(:gas, gas)

    {:ok, _txhash, _addr} =
      Eth.deploy_contract(from, bytecode, [], [], opts)
      |> Eth.DevHelpers.deploy_sync!()
  end

  defp deploy!(bytecode, from, gas) do
    {:ok, _txhash, lib} = deploy(bytecode, from, gas)
    lib
  end

  # given a name of the contract/lib and a list of `{lib_name, lib_address}` tuples, will provide linked bytecode
  @spec bytecode_linked(binary, binary, list({binary, binary})) :: binary
  defp bytecode_linked(path_project_root, name, paths_names_and_libs) do
    contracts_dir = Path.join(path_project_root, "_build/contracts")

    # NOTE: we need to keep the linked versions of contract binaries separate, otherwise `solc --link` overwrites
    File.copy!(Path.join(contracts_dir, "#{name}.bin"), Path.join(contracts_dir, "#{name}Linked.bin"))

    libs_arg =
      paths_names_and_libs
      |> Enum.map(fn {lib_path, lib_name, lib_addr} -> "#{lib_path}:#{lib_name}:#{Encoding.to_hex(lib_addr)}" end)
      |> Enum.join(" ")

    # For some reason, solc returns this weird woes + a success message. The file is indeed resolved.
    # Let's just check the success thing here, instead of pattern matching against an empty stdout
    true =
      ~c(solc #{contracts_dir}/#{name}Linked.bin --libraries \"#{libs_arg}\" --link)
      |> :os.cmd()
      |> to_string()
      |> String.contains?("Linking completed")

    bytecode = get_bytecode!(path_project_root, "#{name}Linked")

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
