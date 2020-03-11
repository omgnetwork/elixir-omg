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

defmodule LoadTesting.LoadTest.ChildChain do
  @moduledoc """
  Load test for child chain
  """
  use Chaperon.LoadTest

  @concurrent_session 100
  @transactions_per_session 100

  def scenarios(),
    do: [
      {{@concurrent_session, LoadTesting.Scenario.DoChildChainTransactions},
       %{
         ntx_to_send: @transactions_per_session
       }}
    ]
end
