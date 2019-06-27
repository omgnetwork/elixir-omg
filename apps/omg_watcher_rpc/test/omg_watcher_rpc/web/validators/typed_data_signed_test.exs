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

defmodule OMG.WatcherRPC.Web.Validators.TypedDataSignedTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.WatcherRPC.Web.Validator.TypedDataSigned
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @other_token <<127::160>>
  @alice TestHelper.generate_entity()
  @bob TestHelper.generate_entity()
  @ari_network_address "44DE0EC539B8C4A4B530C78620FE8320167F2F74" |> Base.decode16!()
  @eip_domain %{
    name: "OMG Network",
    version: "1",
    salt: <<0::256>>,
    verifying_contract: @ari_network_address
  }

  defp get_message() do
    alice_addr = Encoding.to_hex(@alice.addr)
    bob_addr = Encoding.to_hex(@bob.addr)
    eth_hex = Encoding.to_hex(@eth)
    token_hex = Encoding.to_hex(@other_token)

    %{
      "input0" => %{"blknum" => 1000, "txindex" => 0, "oindex" => 1},
      "input1" => %{"blknum" => 3001, "txindex" => 0, "oindex" => 0},
      "input2" => %{"blknum" => 0, "txindex" => 0, "oindex" => 0},
      "input3" => %{"blknum" => 0, "txindex" => 0, "oindex" => 0},
      "output0" => %{"owner" => alice_addr, "currency" => eth_hex, "amount" => 10},
      "output1" => %{"owner" => alice_addr, "currency" => token_hex, "amount" => 300},
      "output2" => %{"owner" => bob_addr, "currency" => token_hex, "amount" => 100},
      "output3" => %{"owner" => eth_hex, "currency" => eth_hex, "amount" => 0},
      "metadata" => Encoding.to_hex(<<0::256>>)
    }
  end

  defp get_domain(network) do
    %{
      "name" => network,
      "version" => "1",
      "salt" => Encoding.to_hex(<<0::256>>),
      "verifying_contract" => @ari_network_address |> Encoding.to_hex()
    }
  end

  test "parses transaction from message data" do
    message = get_message()

    tx = TypedDataSigned.parse_transaction(message)

    assert [Utxo.position(1000, 0, 1), Utxo.position(3001, 0, 0)] == Transaction.get_inputs(tx)

    assert [
             %{owner: @alice.addr, currency: @eth, amount: 10},
             %{owner: @alice.addr, currency: @other_token, amount: 300},
             %{owner: @bob.addr, currency: @other_token, amount: 100}
           ] == Transaction.get_outputs(tx)

    assert nil == tx.metadata
  end

  test "parses transaction with metadata from message data" do
    metadata = (@alice.addr <> @bob.addr) |> OMG.Crypto.hash()
    message = %{get_message() | "metadata" => Encoding.to_hex(metadata)}

    tx = TypedDataSigned.parse_transaction(message)

    assert tx.metadata == metadata
  end

  test "parses signatures" do
    sigs = [<<0::520>>, <<127::520>>]
    too_short_hex = "0x0123456789"

    assert {:ok, sigs} == sigs |> Enum.map(&Encoding.to_hex/1) |> TypedDataSigned.parse_signatures()

    invalid_sigs = [too_short_hex | sigs |> Enum.map(&Encoding.to_hex/1)]
    assert {:error, {:validation_error, "signature", {:length, 65}}} == TypedDataSigned.parse_signatures(invalid_sigs)
  end

  test "parses eip712 domain" do
    assert @eip_domain == "OMG Network" |> get_domain() |> TypedDataSigned.parse_domain()
  end

  test "ensures network domain match" do
    correct_domain = @eip_domain
    incorrect_domain = %{@eip_domain | name: "Z0nk"}

    assert :ok == TypedDataSigned.ensure_network_match(correct_domain, @eip_domain)

    assert {:error, {:validation_error, "domain", :domain_separator_mismatch}} ==
             TypedDataSigned.ensure_network_match(incorrect_domain, @eip_domain)
  end

  test "parses request body" do
    require Transaction

    sigs = [<<0::520>>, <<127::520>>]

    body = %{
      "domain" => get_domain("OMG Network"),
      "message" => get_message(),
      "signatures" => sigs |> Enum.map(&Encoding.to_hex/1)
    }

    assert {:ok,
            %Transaction.Signed{
              raw_tx: %Transaction{
                inputs: inputs,
                outputs: outputs,
                metadata: nil
              },
              sigs: ^sigs
            }} = TypedDataSigned.parse(body)

    assert Enum.count(inputs) == Transaction.max_inputs()
    assert Enum.count(outputs) == Transaction.max_outputs()
  end
end
