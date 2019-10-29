# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.DependencyConformance.SignatureTest do
  @moduledoc """
  Tests that EIP-712-compliant signatures generated `somehow` (via Elixir code as it happens) are treated the same
  by both Elixir signature code and contract signature code.
  """

  alias OMG.DevCrypto
  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias Support.Deployer
  alias Support.DevNode

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :common

  @alice TestHelper.generate_entity()
  @bob TestHelper.generate_entity()
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @token TestHelper.generate_entity().addr

  setup_all do
    {:ok, exit_fn} = DevNode.start()

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, signtest_addr} = Deployer.create_new("PaymentEip712LibMock", root_path, Eth.Encoding.from_hex(addr), [])

    # impose our testing signature contract wrapper (mock) as the validating contract, which normally would be
    # plasma framework
    :ok = Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: Eth.Encoding.to_hex(signtest_addr)})

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: "0x0000000000000000000000000000000000000001"})
      exit_fn.()
    end)

    [contract: signtest_addr]
  end

  test "signature test empty transaction", context do
    contract = context[:contract]
    tx = TestHelper.create_signed([], [])
    verify(contract, tx)
  end

  test "no inputs test", context do
    contract = context[:contract]
    tx = TestHelper.create_signed([], [{@alice, @eth, 100}])
    verify(contract, tx)
  end

  test "no outputs test", context do
    contract = context[:contract]
    tx = TestHelper.create_signed([{1, 0, 0, @alice}], [])
    verify(contract, tx)
  end

  test "signature test - small tx", context do
    contract = context[:contract]
    tx = TestHelper.create_signed([{1, 0, 0, @alice}], [{@alice, @eth, 100}])
    verify(contract, tx)
  end

  test "signature test - full tx", context do
    contract = context[:contract]

    tx =
      TestHelper.create_signed(
        [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
        [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
      )

    verify(contract, tx)
  end

  test "signature test transaction with metadata", context do
    contract = context[:contract]
    {:ok, <<_::256>> = metadata} = DevCrypto.generate_private_key()

    tx =
      TestHelper.create_signed(
        [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
        @eth,
        [{@alice, 100}, {@alice, 50}, {@bob, 75}, {@bob, 25}],
        metadata
      )

    verify(contract, tx)
  end

  defp verify(contract, %Transaction.Signed{raw_tx: tx}) do
    {:ok, solidity_hash} =
      Eth.call_contract(contract, "hashTx(address,bytes)", [contract, Transaction.raw_txbytes(tx)], [{:bytes, 32}])

    assert solidity_hash == OMG.TypedDataHash.hash_struct(tx)
  end
end
