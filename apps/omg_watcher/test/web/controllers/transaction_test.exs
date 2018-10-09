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

defmodule OMG.Watcher.Web.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API.Crypto
  alias OMG.Watcher.TestHelper

  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  deffixture inputs do
    [
      %{
        "amount" => 150,
        "currency" => @eth_hex,
        "blknum" => 2000,
        "txindex" => 111,
        "oindex" => 0,
        "txbytes" => String.duplicate("00", 120)
      },
      %{
        "amount" => 50,
        "currency" => @eth_hex,
        "blknum" => 5000,
        "txindex" => 17,
        "oindex" => 1,
        "txbytes" => nil
      }
    ]
  end

  deffixture outputs(alice, bob) do
    [
      %{
        "amount" => 97,
        "owner" => alice.addr |> Crypto.encode_address!()
      },
      %{
        "amount" => 100,
        "owner" => bob.addr |> Crypto.encode_address!()
      }
    ]
  end

  describe "Controller.TransactionTest - transaction/:id" do
    @tag fixtures: [:initial_blocks, :alice, :bob]
    test "endpoint returns expected transaction format", %{
      initial_blocks: initial_blocks,
      alice: alice,
      bob: bob
    } do
      {blknum, txindex, txhash, _recovered_tx} = initial_blocks |> hd()

      bob_addr = bob.addr |> TestHelper.to_response_address()
      alice_addr = alice.addr |> TestHelper.to_response_address()
      txhash = Base.encode16(txhash)
      zero_addr = String.duplicate("0", 2 * 20)
      zero_sign = String.duplicate("0", 2 * 65)

      assert %{
               "data" => %{
                 "txid" => ^txhash,
                 "txblknum" => ^blknum,
                 "txindex" => ^txindex,
                 "blknum1" => 1,
                 "txindex1" => 0,
                 "oindex1" => 0,
                 "blknum2" => 0,
                 "txindex2" => 0,
                 "oindex2" => 0,
                 "cur12" => ^zero_addr,
                 "newowner1" => ^bob_addr,
                 "amount1" => 300,
                 "newowner2" => ^zero_addr,
                 "amount2" => 0,
                 "sig1" => <<_sig1::binary-size(130)>>,
                 "sig2" => ^zero_sign,
                 "spender1" => ^alice_addr,
                 "spender2" => nil
               },
               "result" => "success"
             } = TestHelper.rest_call(:get, "/transaction/#{txhash}")
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "endpoint returns error for non exsiting transaction" do
      txhash = "055673FF58D85BFBF6844BAD62361967C7D19B6A4768CE4B54C687B65728D721"

      assert %{
               "data" => %{
                 "code" => "transaction:not_found",
                 "description" => "Transaction doesn't exist for provided search criteria"
               },
               "result" => "error"
             } == TestHelper.rest_call(:get, "/transaction/#{txhash}", nil, 404)
    end
  end

  describe "Controller.TransactionTest - POST transaction/" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob, :inputs, :outputs]
    test "returns properly formatted transaction bytes", %{alice: alice, bob: bob, inputs: inputs, outputs: outputs} do
      alias OMG.API.State.Transaction

      body = %{
        "inputs" => inputs,
        "outputs" => outputs
      }

      assert %{
               "result" => "success",
               "data" => txbytes
             } = TestHelper.rest_call(:post, "/transaction", body, 200)

      expected_txbytes =
        %Transaction{
          blknum1: 2000,
          txindex1: 111,
          oindex1: 0,
          blknum2: 5000,
          txindex2: 17,
          oindex2: 1,
          cur12: @eth,
          newowner1: alice.addr,
          amount1: 97,
          newowner2: bob.addr,
          amount2: 100
        }
        |> Transaction.encode()
        |> Base.encode16()

      assert expected_txbytes == txbytes
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :inputs, :outputs]
    test "validates number of provided inputs and outputs", %{inputs: inputs, outputs: outputs} do
      # Too many inputs
      body = %{
        "inputs" => inputs ++ inputs,
        "outputs" => outputs
      }

      assert %{
               "result" => "error",
               "data" => %{
                 "description" => "More inputs provided than currently supported by plasma chain transaction.",
                 "code" => "transaction_encode:too_many_inputs"
               }
             } == TestHelper.rest_call(:post, "/transaction", body, 400)

      # At least one input required
      body = %{
        "inputs" => [],
        "outputs" => outputs
      }

      assert %{
               "result" => "error",
               "data" => %{
                 "description" => "At least one input has to be provided to create plasma chain transaction.",
                 "code" => "transaction_encode:at_least_one_input_required"
               }
             } == TestHelper.rest_call(:post, "/transaction", body, 400)

      # Too many outputs
      body = %{
        "inputs" => inputs,
        "outputs" => outputs ++ outputs
      }

      assert %{
               "result" => "error",
               "data" => %{
                 "description" => "More outputs provided than currently supported by plasma chain transaction.",
                 "code" => "transaction_encode:too_many_outputs"
               }
             } == TestHelper.rest_call(:post, "/transaction", body, 400)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :inputs, :bob]
    test "validates that amounts add up", %{inputs: inputs, bob: bob} do
      body = %{
        "inputs" => inputs,
        "outputs" => [%{"amount" => 500, "owner" => bob.addr |> Crypto.encode_address!()}]
      }

      assert %{
               "result" => "error",
               "data" => %{
                 "description" => "The value of outputs exceeds what is spent in inputs.",
                 "code" => "transaction_encode:not_enough_funds_to_cover_spend"
               }
             } == TestHelper.rest_call(:post, "/transaction", body, 400)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :inputs, :outputs]
    test "validates that amounts in inputs and outputs are positive integers", %{
      inputs: [input1 | _],
      outputs: [output1 | _]
    } do
      expected_error_data = %{
        "description" => "The amount in both inputs and outputs has to be non-negative integer.",
        "code" => "transaction_encode:amount_noninteger_or_negative"
      }

      # Negative amount in inputs
      body = %{
        "inputs" => [%{input1 | "amount" => -1}],
        "outputs" => [output1]
      }

      assert %{
               "result" => "error",
               "data" => expected_error_data
             } == TestHelper.rest_call(:post, "/transaction", body, 400)

      # Negative amount in outputs
      body = %{
        "inputs" => [input1],
        "outputs" => [%{output1 | "amount" => -1}]
      }

      assert %{
               "result" => "error",
               "data" => expected_error_data
             } == TestHelper.rest_call(:post, "/transaction", body, 400)

      # Non-integer amount in outputs
      body = %{
        "inputs" => [input1],
        "outputs" => [%{output1 | "amount" => "NaN"}]
      }

      assert %{
               "result" => "error",
               "data" => expected_error_data
             } == TestHelper.rest_call(:post, "/transaction", body, 400)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :inputs, :outputs]
    test "validates that the same currency is used in inputs", %{inputs: [input1, input2], outputs: outputs} do
      body = %{
        "inputs" => [input1, %{input2 | "currency" => String.duplicate("1F", 20)}],
        "outputs" => outputs
      }

      assert %{
               "result" => "error",
               "data" => %{
                 "description" =>
                   "Inputs contain more than one currency. Mixing currencies is not possible in plasma chain transaction.",
                 "code" => "transaction_encode:currency_mixing_not_possible"
               }
             } == TestHelper.rest_call(:post, "/transaction", body, 400)
    end
  end
end
