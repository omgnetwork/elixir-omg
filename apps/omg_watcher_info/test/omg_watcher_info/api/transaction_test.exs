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

  describe "merge/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "merge with address and currency" do
      owner = <<1::160>>

      deposit_1 = with_deposit(build(:txoutput, %{owner: owner}))
      output_1 = build(:txoutput, %{owner: owner})
      output_2 = build(:txoutput, %{owner: owner})

      IO.inspect(output_1)
      IO.inspect(output_2)

      transaction =
        insert(:transaction)
        |> with_inputs([deposit_1])
        |> with_outputs([output_1])

      # result = Transaction.merge(%{address: , currency: })

      assert 1 == 1
    end
  end
end
