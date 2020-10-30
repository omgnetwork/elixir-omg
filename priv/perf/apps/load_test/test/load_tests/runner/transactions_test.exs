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

defmodule LoadTest.Runner.TransactionsTest do
  use ExUnit.Case, async: false

  alias LoadTest.Service.Metrics

  @moduletag :utxos

  setup do
    value = Application.get_env(:load_test, :record_metrics)

    Application.put_env(:load_test, :record_metrics, true)
    {:ok, _pid} = Metrics.start_link()

    on_exit(fn ->
      Application.put_env(:load_test, :record_metrics, value)
    end)
  end

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

    Chaperon.run_load_test(LoadTest.Runner.Transactions, config: config)

    metrics = Metrics.metrics()

    assert metrics["test_success"][:total_count] == 20
  end
end
