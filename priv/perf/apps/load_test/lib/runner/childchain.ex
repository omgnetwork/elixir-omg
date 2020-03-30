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

defmodule LoadTest.Runner.ChildChainTransactions do
  @moduledoc """
  Creates load on the child chain by submitting transactions as fast as possible.
  """
  use Chaperon.LoadTest

  @default_config %{
    concurrent_sessions: 1,
    transactions_per_session: 1
  }

  def default_config() do
    Application.get_env(:load_test, :childchain_transactions_test_config, @default_config)
  end

  def scenarios() do
    %{concurrent_sessions: concurrent_sessions} = default_config()

    [
      {{concurrent_sessions, LoadTest.Scenario.ChildChainSubmitTransactions}, %{}}
    ]
  end
end
