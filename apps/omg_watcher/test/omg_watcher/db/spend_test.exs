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

defmodule OMG.Watcher.DB.SpendTest do
  @moduledoc """
  Currently, this test focuses on testing behaviors not testable via Controllers.TransactionTest.

  The reason is that we are treating the DB schema etc. as implementation detail. In case testing through controllers
  becomes hard/slow or otherwise unreasonable, refactor these two kinds of tests appropriately
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use Plug.Test

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @tag fixtures: [:initial_blocks]
  test "check all spends was inserted", %{initial_blocks: initial_blocks} do
    spends = DB.Repo.all(DB.Spend)
    assert 4 == Enum.count(spends)

    [{_, _, txhash, tx} | _] = initial_blocks
    [Utxo.position(blknum, txindex, oindex)] = Transaction.get_inputs(tx)

    assert %DB.Spend{
             spending_txhash: ^txhash,
             spending_tx_oindex: 0
           } = Enum.find(spends, &match?(%{blknum: ^blknum, txindex: ^txindex, oindex: ^oindex}, &1))
  end
end
