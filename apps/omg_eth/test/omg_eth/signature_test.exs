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

defmodule OMG.Eth.SignatureTest do
  @moduledoc """
  Tests that elixir-generated signatures can be successfully verified by contract code.
  NOTE: These are integration tests as they require Ethereum node running and contract deployment,
  however it deployed contract once for all tests and then calls a function on it which should be
  quick enough so we can afford it runs with unit tests.
  """

  alias OMG.DevCrypto
  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.TestHelper

  use ExUnitFixtures
  use ExUnit.Case, async: false

  @alice TestHelper.generate_entity()
  @bob TestHelper.generate_entity()
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @token TestHelper.generate_entity().addr

  setup_all do
    DeferredConfig.populate(:omg_eth)
    {:ok, exit_fn} = Eth.DevNode.start()

    root_path = "../../"
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, _, signtest_addr} = Eth.Deployer.create_new(OMG.Eth.Eip712, root_path, Eth.Encoding.from_hex(addr))

    on_exit(exit_fn)
    [contract: signtest_addr]
  end

  test "signature test empty transaction", context do
    contract = context[:contract]
    tx = Transaction.new([], []) |> DevCrypto.sign([@alice.priv])
    sig = tx.sigs |> Enum.at(0)

    assert true == verify(contract, tx, sig, @alice.addr)
    assert false == verify(contract, tx, sig, @bob.addr)
  end

  test "signature test", context do
    contract = context[:contract]

    tx =
      TestHelper.create_signed(
        [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
        [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
      )

    [alice_sig, bob_sig | _] = tx.sigs

    assert true == verify(contract, tx, alice_sig, @alice.addr)
    assert true == verify(contract, tx, bob_sig, @bob.addr)
    assert false == verify(contract, tx, bob_sig, @alice.addr)
    assert false == verify(contract, tx, alice_sig, @bob.addr)
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

    [alice_sig, bob_sig | _] = tx.sigs

    assert true == verify(contract, tx, alice_sig, @alice.addr)
    assert true == verify(contract, tx, bob_sig, @bob.addr)
    assert false == verify(contract, tx, bob_sig, @alice.addr)
    assert false == verify(contract, tx, alice_sig, @bob.addr)
  end

  defp verify(contract, tx, signature, signer) do
    {:ok, result} =
      Eth.call_contract(
        contract,
        "verify(bytes,bytes,address)",
        [Transaction.raw_txbytes(tx), signature, signer],
        [:bool]
      )

    result
  end
end
