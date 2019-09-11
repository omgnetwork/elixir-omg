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

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :common

  @alice TestHelper.generate_entity()
  @bob TestHelper.generate_entity()
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @token TestHelper.generate_entity().addr

  setup_all do
    {:ok, exit_fn} = Eth.DevNode.start()

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, _, signtest_addr} = Eth.Deployer.create_new(OMG.Eth.Eip712, root_path, Eth.Encoding.from_hex(addr))

    :ok = Application.put_env(:omg_eth, :contract_addr, Eth.Encoding.to_hex(signtest_addr))

    on_exit(exit_fn)
    [contract: signtest_addr]
  end

  test "signature test empty transaction", context do
    contract = context[:contract]
    tx = Transaction.Payment.new([], []) |> DevCrypto.sign([@alice.priv])
    sig = tx.sigs |> Enum.at(0)

    verify(contract, tx, sig)
  end

  test "signature test", context do
    contract = context[:contract]

    tx =
      TestHelper.create_signed(
        [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
        [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
      )

    [alice_sig, bob_sig | _] = tx.sigs

    verify(contract, tx, alice_sig)
    verify(contract, tx, bob_sig)
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

    verify(contract, tx, alice_sig)
    verify(contract, tx, bob_sig)
  end

  defp verify(contract, %Transaction.Signed{raw_tx: tx}, signature) do
    {:ok, solidity_signer} =
      Eth.call_contract(contract, "getSigner(bytes,bytes)", [Transaction.raw_txbytes(tx), signature], [:address])

    {:ok, elixir_signer} =
      tx
      |> OMG.TypedDataHash.hash_struct()
      |> OMG.Crypto.recover_address(signature)

    assert solidity_signer == elixir_signer
  end
end
