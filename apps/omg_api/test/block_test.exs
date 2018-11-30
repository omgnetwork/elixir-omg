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

defmodule OMG.API.BlockTest do
  @moduledoc """
  Simple unit test of part of `OMG.API.Block`.
  """

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.TestHelper, as: Test

  defp eth, do: Crypto.zero_address()

  @tag fixtures: [:stable_alice, :stable_bob]
  test "Block merkle proof smoke test", %{
    stable_alice: alice
  } do
    # this checks merkle proof normally tested via speaking to the contract (integration tests) against
    # a fixed binary. The motivation for having such test is a quick test of whether the merkle proving didn't change

    # odd number of transactions, just in case
    tx_1 = Test.create_signed([{1, 0, 0, alice}], eth(), [{alice, 7}])
    tx_2 = Test.create_signed([{1, 1, 0, alice}], eth(), [{alice, 2}])
    tx_3 = Test.create_signed([{1, 0, 1, alice}], eth(), [{alice, 2}])

    assert [tx_1, tx_2, tx_3]
           |> Enum.map(&Transaction.Signed.signed_hash/1)
           |> Block.create_tx_proof(2)
           |> Base.encode16(case: :lower) ==
             "0000000000000000000000000000000000000000000000000000000000000000641ce416d7e7b257686f209169718a378657bcd1140857cdafa2b7d569124609b4c11951957c6f8f642c4af61cd6b24640fec6dc7fc607ee8206a99e92410d3021ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85e58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a193440eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968ffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f839867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756afcefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0f9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5f8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf8923490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99cc1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8beccda7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2"
  end
end
