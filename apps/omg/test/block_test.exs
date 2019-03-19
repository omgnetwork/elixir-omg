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

defmodule OMG.BlockTest do
  @moduledoc """
  Simple unit test of part of `OMG.Block`.
  """

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Block
  alias OMG.State.Transaction
  alias OMG.TestHelper, as: Test

  defp eth, do: OMG.Eth.RootChain.eth_pseudo_address()

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

    assert %Block{transactions: [tx_1, tx_2, tx_3] |> Enum.map(&Transaction.Signed.encode/1)}
           |> Block.inclusion_proof(2)
           |> Base.encode16(case: :lower) ==
             "290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563c62f5e8b8c8303e7845c0e8ea800fc1bae9ccb7782b6f3c870c2d48fdddf5bb4890740a8eb06ce9be422cb8da5cdafc2b58c0a5e24036c578de2a433c828ff7d3b8ec09e026fdc305365dfc94e189a81b38c7597b3d941c279f042e8206e0bd8ecd50eee38e386bd62be9bedb990706951b65fe053bd9d8a521af753d139e2dadefff6d330bb5403f63b14f33b578274160de3a50df4efecf0e0db73bcdd3da5617bdd11f7c0a11f49db22f629387a12da7596f9d1704d7465177c63d88ec7d7292c23a9aa1d8bea7e2435e555a4a60e379a5a35f3f452bae60121073fb6eeade1cea92ed99acdcb045a6726b2f87107e8a61620a232cf4d7d5b5766b3952e107ad66c0a68c72cb89e4fb4303841966e4062a76ab97451e3b9fb526a5ceb7f82e026cc5a4aed3c22a58cbd3d2ac754c9352c5436f638042dca99034e836365163d04cffd8b46a874edf5cfae63077de85f849a660426697b06a829c70dd1409cad676aa337a485e4728a0b240d92b3ef7b3c372d06d189322bfd5f61f1e7203ea2fca4a49658f9fab7aa63289c91b7c7b6c832a6d0e69334ff5b0a3483d09dab4ebfd9cd7bca2505f7bef59cc1c12ecc708fff26ae4af19abe852afe9e20c8622def10d13dd169f550f578bda343d9717a138562e0093b380a1120789d53cf10"
  end
end
