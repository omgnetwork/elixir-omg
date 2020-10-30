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

defmodule LoadTest.Runner.UtxosTest do
  use ExUnit.Case

  @moduletag :utxos

  test "deposits test" do
    token = "0x0000000000000000000000000000000000000000"
    initial_amount = 760
    fee = 75

    config = %{
      chain_config: %{
        token: token,
        initial_amount: initial_amount,
        fee: fee
      },
      run_config: %{
        tps: 1,
        period_in_seconds: 20
      },
      timeout: :infinity
    }

    result = Chaperon.run_load_test(LoadTest.Runner.Utxos, config: config)

    assert result.metrics["error_rate"][:mean] == 0.0
  end
end
