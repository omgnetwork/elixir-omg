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

defmodule OMG.Eth.Tenderly.CallDataTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias ExVCR.Config
  alias OMG.Eth.Tenderly.CallData
  alias OMG.Eth.Tenderly.Client

  @tx_hash "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"

  setup do
    Application.ensure_all_started(:ssl)
    Config.cassette_library_dir("test/fixtures/vcr_cassettes/tenderly")
    :ok
  end

  defmodule EthClientMock do
    def get_transaction_by_hash("0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b") do
      {:ok,
       %{
         "blockHash" => "0x1d59ff54b1eb26b013ce3cb5fc9dab3705b415a67127a003c3e61eb445bb8df2",
         "blockNumber" => "0x7def32",
         "from" => "0x6878616891f0e320f0b52906d4cba11677acd772",
         "gas" => "0xa0a32",
         "gasPrice" => "0x4a817c800",
         "hash" => "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b",
         "input" =>
           "0xbf1f316d000000000000000000000000000000000000000000000000000647fc93f6800000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000064713bf517001000000000000000000000000000000000000000000000000000000000000007ef87c01e1a000000000000000000000000000000000000000000000000000064713bf517001f6f501f394584128cad14df97a6eb38c83293a23bd3297d3429400000000000000000000000000000000000000008801632a2f7232200080a0000000000000000000000000000000000000466173742045786974205465737400000000000000000000000000000000000000000000000000000000000000000200c79632b66c36683bee7872870431dbe49ddd78158135be7929f0897aabf6fdf74ed5c02d6d48c8932486c99d3ad999e5d8949dc3be3b3058cc2979690c3e3a621c792b14bf66f82af36f00f5fba7014fa0c1e2ff3c7c273bfe523c1acf67dc3f5fa080a686a5a0d05c3d4822fd54d632dc9cc04b1616046eba2ce499eb9af79f5eb949690a0404abf4cebafc7cfffa382191b7dd9e7df778581e6fb78efab35fd364c9d5dadad4569b6dd47f7feabafa3571f842434425548335ac6e690dd07168d8bc5b77979c1a6702334f529f5783f79e942fd2cd03f6e55ac2cf496e849fde9c446fab46a8d27db1e3100f275a777d385b44e3cbc045cabac9da36cae040ad516082324c96127cf29f4535eb5b7ebacfe2a1d6d3aab8ec0483d32079a859ff70f9215970a8beebb1c164c474e82438174c8eeb6fbc8cb4594b88c9448f1d40b09beaecac5b45db6e41434a122b695c5a85862d8eae40b3268f6f37e414337be38eba7ab5bbf303d01f4b7ae07fd73edc2f3be05e43948a34418a3272509c43c2811a821e5c982ba51874ac7dc9dd79a80cc2f05f6f664c9dbb2e454435137da06ce44de45532a56a3a7007a2d0c6b435f726f95104bfa6e707046fc154bae91898d03a1a0ac6f9b45e471646e2555ac79e3fe87eb1781e26f20500240c379274fe91096e60d1545a8045571fdab9b530d0d6e7e8746e78bf9f20f4e86f0600000000000000000000000000000000000000000000000000000000000000b5f8b301e1a00000000000000000000000000000000000000000000000000006445941624000f86cf501f3944a6848f78cefad797d025241cc8557d71a2e294394000000000000000000000000000000000000000088042963456b4006a0f501f3946878616891f0e320f0b52906d4cba11677acd77294000000000000000000000000000000000000000088016345785d8a000080a00000000000000000000000000000000000004661737420457869742054657374000000000000000000000000000000000000000000000000000000000000000000000000000000000002000bfbbf0e382245c5cf76853509353a24f83cefca7eefc6109173e873950b46224ed5c02d6d48c8932486c99d3ad999e5d8949dc3be3b3058cc2979690c3e3a621c792b14bf66f82af36f00f5fba7014fa0c1e2ff3c7c273bfe523c1acf67dc3f5fa080a686a5a0d05c3d4822fd54d632dc9cc04b1616046eba2ce499eb9af79f5eb949690a0404abf4cebafc7cfffa382191b7dd9e7df778581e6fb78efab35fd364c9d5dadad4569b6dd47f7feabafa3571f842434425548335ac6e690dd07168d8bc5b77979c1a6702334f529f5783f79e942fd2cd03f6e55ac2cf496e849fde9c446fab46a8d27db1e3100f275a777d385b44e3cbc045cabac9da36cae040ad516082324c96127cf29f4535eb5b7ebacfe2a1d6d3aab8ec0483d32079a859ff70f9215970a8beebb1c164c474e82438174c8eeb6fbc8cb4594b88c9448f1d40b09beaecac5b45db6e41434a122b695c5a85862d8eae40b3268f6f37e414337be38eba7ab5bbf303d01f4b7ae07fd73edc2f3be05e43948a34418a3272509c43c2811a821e5c982ba51874ac7dc9dd79a80cc2f05f6f664c9dbb2e454435137da06ce44de45532a56a3a7007a2d0c6b435f726f95104bfa6e707046fc154bae91898d03a1a0ac6f9b45e471646e2555ac79e3fe87eb1781e26f20500240c379274fe91096e60d1545a8045571fdab9b530d0d6e7e8746e78bf9f20f4e86f06",
         "nonce" => "0x15",
         "to" => "0x584128cad14df97a6eb38c83293a23bd3297d342",
         "transactionIndex" => "0xc",
         "value" => "0x31bced02db0000",
         "v" => "0x25",
         "r" => "0x1b5e176d927f8e9ab405058b2d2457392da3e20f328b16ddabcebc33eaac5fea",
         "s" => "0x4ba69724e8f69de52f0125ad8b3c5c2cef33019bac3249e2c0a2192766d1721c"
       }}
    end
  end

  test "gets call_data from tenderly" do
    use_cassette "simulation_success" do
      assert {:ok,
              "0x70e014620000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000647fc93f6800000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000007ef87c01e1a000000000000000000000000000000000000000000000000000064713bf517001f6f501f394584128cad14df97a6eb38c83293a23bd3297d3429400000000000000000000000000000000000000008801632a2f7232200080a0000000000000000000000000000000000000466173742045786974205465737400000000000000000000000000000000000000000000000000000000000000000200c79632b66c36683bee7872870431dbe49ddd78158135be7929f0897aabf6fdf74ed5c02d6d48c8932486c99d3ad999e5d8949dc3be3b3058cc2979690c3e3a621c792b14bf66f82af36f00f5fba7014fa0c1e2ff3c7c273bfe523c1acf67dc3f5fa080a686a5a0d05c3d4822fd54d632dc9cc04b1616046eba2ce499eb9af79f5eb949690a0404abf4cebafc7cfffa382191b7dd9e7df778581e6fb78efab35fd364c9d5dadad4569b6dd47f7feabafa3571f842434425548335ac6e690dd07168d8bc5b77979c1a6702334f529f5783f79e942fd2cd03f6e55ac2cf496e849fde9c446fab46a8d27db1e3100f275a777d385b44e3cbc045cabac9da36cae040ad516082324c96127cf29f4535eb5b7ebacfe2a1d6d3aab8ec0483d32079a859ff70f9215970a8beebb1c164c474e82438174c8eeb6fbc8cb4594b88c9448f1d40b09beaecac5b45db6e41434a122b695c5a85862d8eae40b3268f6f37e414337be38eba7ab5bbf303d01f4b7ae07fd73edc2f3be05e43948a34418a3272509c43c2811a821e5c982ba51874ac7dc9dd79a80cc2f05f6f664c9dbb2e454435137da06ce44de45532a56a3a7007a2d0c6b435f726f95104bfa6e707046fc154bae91898d03a1a0ac6f9b45e471646e2555ac79e3fe87eb1781e26f20500240c379274fe91096e60d1545a8045571fdab9b530d0d6e7e8746e78bf9f20f4e86f06"} ==
               CallData.get_call_data(
                 @tx_hash,
                 Client,
                 EthClientMock
               )
    end
  end

  test "gets call data for startStandardExit", %{test: test_name} do
    defmodule test_name do
      def simulate_transaction(_) do
        {:ok,
         %{
           "transaction" => %{
             "transaction_info" => %{
               "call_trace" => %{"calls" => [%{"function_name" => "startStandardExit", "input" => "0x1"}]}
             }
           }
         }}
      end
    end

    assert {:ok, "0x1"} == CallData.get_call_data(@tx_hash, test_name, EthClientMock)
  end

  test "gets call data for startInFlightExit", %{test: test_name} do
    defmodule test_name do
      def simulate_transaction(_) do
        {:ok,
         %{
           "transaction" => %{
             "transaction_info" => %{
               "call_trace" => %{"calls" => [%{"function_name" => "startInFlightExit", "input" => "0x1"}]}
             }
           }
         }}
      end
    end

    assert {:ok, "0x1"} == CallData.get_call_data(@tx_hash, test_name, EthClientMock)
  end

  test "gets call data for challengeInFlightExitNotCanonical", %{test: test_name} do
    defmodule test_name do
      def simulate_transaction(_) do
        {:ok,
         %{
           "transaction" => %{
             "transaction_info" => %{
               "call_trace" => %{
                 "calls" => [%{"function_name" => "challengeInFlightExitNotCanonical", "input" => "0x1"}]
               }
             }
           }
         }}
      end
    end
  end

  test "returns error when transaction does not match any of startStandardExit, startInFlightExit, challengeInFlightExitNotCanonical",
       %{test: test_name} do
    defmodule test_name do
      def simulate_transaction(_) do
        {:ok, %{"transaction" => %{"transaction_info" => %{"call_trace" => %{"calls" => []}}}}}
      end
    end

    assert {:error, :no_matching_function} == CallData.get_call_data(@tx_hash, test_name, EthClientMock)
  end

  test "returns error when simulation fails", %{test: test_name} do
    defmodule test_name do
      def simulate_transaction(_), do: {:error, :reason}
    end

    assert {:error, :reason} == CallData.get_call_data(@tx_hash, test_name, EthClientMock)
  end
end
