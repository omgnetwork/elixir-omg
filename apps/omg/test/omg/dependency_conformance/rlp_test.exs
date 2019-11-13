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

defmodule OMG.DependencyConformance.RLPTest do
  @moduledoc """
  Test if RLPReader decoder is one to one function.
  """

  alias OMG.Eth
  alias Support.Deployer
  alias Support.DevNode

  use PropCheck
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :common
  @moduletag :fuzz

  def safe_decode(t) do
    try do
      ExRLP.decode(t)
    rescue
      _ -> false
    end
  end

  setup_all do
    {:ok, exit_fn} = DevNode.start()

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, decoder_addr} = Deployer.create_new("RLPReaderChecksum", root_path, Eth.Encoding.from_hex(addr), [])

    on_exit(fn ->
      exit_fn.()
    end)

    [contract: decoder_addr]
  end

  property "decoding is one to one", [1000, :verbose, max_size: 100, constraint_tries: 100_000], %{contract: contract} do
    gen = such_that(bin <- binary(), when: false != safe_decode(bin))

    forall l <- list(gen) do
      mapsto = for item <- :lists.usort(l) do
        contract_decode(contract, item)
      end
      :lists.sort(mapsto) == :lists.usort(mapsto)
    end
  end

  defp contract_decode(contract, binary) do
    {:ok, solidity_hash} =
      Eth.call_contract(contract, "decodeAndChecksum(bytes)", [binary], [{:bytes, 32}])
    solidity_hash
  end
end
