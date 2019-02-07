# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.State.FeeTest do
  @moduledoc """
  Test for fee collection
  """

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction.Fee

  import OMG.API.TestHelper

  @eth Crypto.zero_address()
  @not_eth <<1::size(160)>>

  @fees %{
    @eth => 1,
    @not_eth => 3
  }

  @tag fixtures: [:alice, :bob]
  test "Fee map is reduced to the currencies spend by transaction", %{alice: alice, bob: bob} do
    fees =
      create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      |> Fee.apply_fees(@fees)

    assert Fee.covered?(%{@eth => 10}, %{@eth => 9}, fees)

    fees =
      create_recovered([{1, 0, 0, alice}], @not_eth, [{bob, 4}, {alice, 3}])
      |> Fee.apply_fees(@fees)

    assert Fee.covered?(%{@not_eth => 10}, %{@not_eth => 7}, fees)

    fees =
      create_recovered(
        [{1, 0, 0, alice}, {2, 0, 0, alice}],
        [{bob, @eth, 4}, {alice, @eth, 1}, {bob, @not_eth, 5}, {alice, @not_eth, 5}]
      )
      |> Fee.apply_fees(@fees)

    assert Fee.covered?(
             %{@eth => 5, @not_eth => 13},
             %{@eth => 5, @not_eth => 10},
             fees
           )
  end

  @tag fixtures: [:alice, :bob]
  test "Transaction which does not transfer any fee currency is object to fees", %{alice: alice, bob: bob} do
    other_token = <<2::160>>

    fees =
      create_recovered([{1, 0, 0, alice}], other_token, [{bob, 5}, {alice, 3}])
      |> Fee.apply_fees(@fees)

    assert false == Fee.covered?(%{other_token => 10}, %{other_token => 7}, fees)
  end
end
