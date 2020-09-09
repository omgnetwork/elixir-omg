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

defmodule LoadTest.Runner.StandardExits do
  @moduledoc """
  """
  use Chaperon.LoadTest

  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Exit
  alias LoadTest.Service.Faucet
  alias LoadTest.Ethereum.Account

  @eth <<0::160>>

  @default_config %{
    concurrent_sessions: 1,
    exits_per_session: 1
  }

  def default_config() do
    Application.get_env(:load_test, :standard_exit_test_config, @default_config)
  end

  def scenarios() do
    test_currency = Application.fetch_env!(:load_test, :test_currency)
    gas_price = Application.fetch_env!(:load_test, :gas_price)
    config = default_config()

    # Use the faucet account to add the token's exit queue if necessary
    {:ok, faucet} = Faucet.get_faucet()
    _ = Exit.add_exit_queue(1, Encoding.to_binary(test_currency), faucet, gas_price)

    [
      {{config.concurrent_sessions, LoadTest.Scenario.ManyStandardExits},
       %{
         gas_price: gas_price,
         test_currency: test_currency
       }}
    ]
  end
end
