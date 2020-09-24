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

defmodule LoadTest.Runner.DepositsTest do
  use ExUnit.Case

  @moduletag :deposits

  alias ExPlasma.Encoding
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet

  test "deposits test" do
    token = Encoding.to_binary("0x0000000000000000000000000000000000000000")
    amount = 1_000_000_000_000_000_000

    config = %{
      chain_config: %{
        token: token,
        amount: amount
      },
      run_config: %{
        tps: 1,
        period_in_seconds: 5
      },
      timeout: 60_000
    }

    Chaperon.run_load_test(LoadTest.Runner.Deposits, print_results: true, config: config)
  end
end
