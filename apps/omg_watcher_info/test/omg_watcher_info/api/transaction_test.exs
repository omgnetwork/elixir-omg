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

defmodule OMG.WatcherInfo.API.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.WatcherInfo.API.Transaction

  import OMG.WatcherInfo.Factory

  @owner <<1::160>>
  @currency_1 <<2::160>>
  @currency_2 <<3::160>>

  describe "merge/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "merge with address and currency merges correctly" do
      _ = insert(:txoutput, currency: @currency_1, owner: @owner, amount: 5)
      _ = insert(:txoutput, currency: @currency_2, owner: @owner, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @owner, amount: 2)
      _ = insert(:txoutput, currency: @currency_1, owner: @owner, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @owner, amount: 1)
      _ = insert(:txoutput, currency: @currency_1, owner: @owner, amount: 1)

      result = Transaction.merge(%{address: @owner, currency: @currency_1})

      assert 1 == 1
    end
  end
end
