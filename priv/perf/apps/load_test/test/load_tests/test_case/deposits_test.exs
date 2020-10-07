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

defmodule LoadTest.TestCase.DepositsTest do
  use ExUnit.Case

  @moduletag :deposits

  alias ExPlasma.Encoding
  alias LoadTest.TestCase.Deposits

  @timeout :infinity
  test "deposits test" do
    token = Encoding.to_binary("0x0000000000000000000000000000000000000000")
    amount = 1_000_000_000_000_000_000

    params = [
      rate: 10,
      token: token,
      amount: amount,
      id: :deposits_test,
      test_period: 100_000,
      start_period: 40_000,
      adjust_period: 200_000,
      rate_period: 30_000
    ]

    Deposits.run(params)
  end
end
