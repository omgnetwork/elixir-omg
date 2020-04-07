# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule Support.Conformance.SignaturesHashesCase do
  @moduledoc """
  `ExUnit` test case for the setup required by a test of Elixir and Solidity implementation conformance
  """
  alias Support.SnapshotContracts

  use ExUnit.CaseTemplate

  using do
    quote do
      @alice <<215, 32, 17, 47, 111, 72, 20, 47, 149, 226, 138, 242, 35, 254, 141, 212, 16, 22, 155, 182>>
      @bob <<141, 246, 138, 77, 76, 3, 78, 54, 173, 40, 234, 195, 29, 170, 154, 64, 99, 14, 118, 139>>
      @eth OMG.Eth.zero_address()
      @token <<235, 169, 32, 193, 242, 237, 159, 137, 184, 46, 124, 13, 178, 171, 61, 87, 179, 179, 135, 146>>
      @zero_address OMG.Eth.zero_address()
    end
  end

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()
    contracts = SnapshotContracts.parse_contracts()
    signtest_addr_hex = contracts["CONTRACT_ADDRESS_PAYMENT_EIP_712_LIB_MOCK"]
    old_config = Application.get_all_env(:omg_eth)
    :ok = Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: signtest_addr_hex})

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      :ok = Application.put_all_env(omg_eth: old_config)

      exit_fn.()
    end)

    [contract: OMG.Eth.Encoding.from_hex(signtest_addr_hex)]
  end
end
