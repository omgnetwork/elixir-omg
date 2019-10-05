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

defmodule OMG.RootChainTest do
  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias OMG.Eth.DevHelpers
  alias OMG.Eth.RootChain
  alias OMG.Eth.RootChainHelper

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @moduletag :common

  setup do
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes/root_chain")
    # NOTE achiurizo
    #
    # this is a hack to ensure we reset the counter to 0 despite
    # the fixtures now resetting the counter.
    :ets.insert(:rpc_requests_counter, {:rpc_counter, 0})
    :ok
  end

  test "get_root_deployment_height/2 returns current block number" do
    use_cassette "get_root_deployment_height", match_requests_on: [:request_body] do
      # TODO achiurizo
      #
      # Clean this up so that we can have one deterministic contract details to use
      # for all the tests cases.
      contract = %{
        authority_addr: <<204, 154, 45, 114, 241, 226, 6, 126, 218, 109, 233, 154, 255, 131, 82, 75, 114, 216, 26, 30>>,
        contract_addr: %{
          erc20_vault:
            <<204, 227, 180, 82, 93, 66, 95, 207, 206, 89, 143, 112, 122, 195, 151, 194, 158, 125, 226, 166>>,
          eth_vault: <<118, 176, 88, 4, 51, 58, 170, 215, 9, 205, 145, 35, 131, 51, 222, 96, 121, 15, 250, 112>>,
          payment_exit_game:
            <<173, 164, 192, 171, 235, 108, 94, 37, 108, 174, 114, 213, 255, 148, 121, 181, 70, 75, 101, 197>>,
          plasma_framework:
            <<90, 35, 43, 73, 233, 236, 101, 119, 181, 26, 205, 176, 83, 205, 10, 45, 202, 136, 77, 148>>
        },
        txhash_contract:
          <<28, 25, 199, 207, 128, 97, 217, 196, 200, 122, 113, 110, 158, 79, 222, 128, 72, 209, 21, 97, 234, 244, 9,
            151, 48, 171, 154, 22, 137, 177, 180, 28>>
      }

      {:ok, number} = RootChain.get_root_deployment_height(contract.txhash_contract, contract.contract_addr)
      assert is_integer(number)
    end
  end

  test "get_next_child_block/1 returns next blknum to be mined by operator" do
    use_cassette "get_next_child_block", match_requests_on: [:request_body] do
      # TODO achiurizo
      #
      # Clean this up so that we can have one deterministic contract details to use
      # for all the tests cases.
      contract = %{
          authority_addr: <<101, 169, 2, 97, 40, 186, 104, 213, 223, 253, 20, 83, 122,
            74, 211, 235, 132, 117, 175, 69>>,
          contract_addr: %{
                erc20_vault: <<160, 221, 143, 187, 23, 33, 129, 20, 198, 253, 29, 165, 230,
                  37, 204, 235, 111, 87, 181, 126>>,
                eth_vault: <<253, 228, 102, 188, 30, 46, 78, 163, 59, 120, 168, 75, 63, 194,
                  251, 31, 45, 222, 162, 216>>,
                payment_exit_game: <<73, 69, 211, 244, 191, 248, 188, 177, 103, 8, 212, 120,
                  236, 136, 83, 36, 69, 65, 193, 27>>,
                plasma_framework: <<132, 124, 7, 220, 91, 185, 40, 13, 183, 246, 116, 245,
                  106, 86, 160, 30, 90, 33, 212, 241>>
              },
          txhash_contract: <<85, 124, 61, 202, 150, 92, 110, 225, 2, 88, 22, 22, 75,
            138, 205, 223, 72, 194, 40, 33, 181, 205, 199, 17, 162, 128, 185, 113, 196,
            176, 69, 181>>
      }

      assert {:ok, 1000} = RootChain.get_next_child_block(contract.contract_addr)
    end
  end

   describe "has_token/2" do

     # TODO achiurizo
     #
     # Figure out why I can't use the same cassettes even though request_body is unique
     test "returns true  if token exists" do
       use_cassette "has_token_true", match_requests_on: [:request_body] do
          contract = %{
            authority_addr: <<124, 186, 31, 78, 163, 98, 19, 11, 188, 32, 190, 124, 192,
              194, 55, 60, 74, 192, 29, 225>>,
            contract_addr: %{
              erc20_vault: <<105, 30, 198, 198, 233, 57, 52, 41, 224, 79, 246, 113, 62,
                95, 85, 201, 190, 33, 2, 204>>,
              eth_vault: <<9, 246, 237, 141, 63, 198, 60, 148, 62, 16, 138, 98, 18, 190,
                59, 166, 179, 55, 121, 145>>,
              payment_exit_game: <<91, 132, 138, 118, 46, 220, 49, 149, 167, 71, 189, 118,
                22, 102, 205, 97, 21, 115, 19, 155>>,
              plasma_framework: <<28, 201, 241, 79, 241, 192, 96, 248, 188, 149, 238, 210,
                78, 236, 89, 149, 14, 225, 245, 114>>
            },
            txhash_contract: <<19, 255, 229, 249, 198, 159, 141, 150, 51, 116, 115, 149,
              45, 70, 189, 174, 66, 128, 234, 181, 168, 160, 89, 117, 245, 239, 156, 243,
              231, 61, 140, 166>>
          }
         assert {:ok, true} = RootChainHelper.has_token(@eth, contract.contract_addr)
       end
     end

     test "returns false if no token exists" do
       use_cassette "has_token_false", match_requests_on: [:request_body] do
          contract = %{
            authority_addr: <<224, 163, 124, 151, 37, 126, 191, 248, 81, 214, 42, 187,
              145, 76, 9, 179, 47, 233, 51, 20>>,
            contract_addr: %{
              erc20_vault: <<217, 159, 111, 59, 33, 98, 167, 158, 227, 188, 192, 172, 199,
                246, 122, 138, 134, 194, 32, 240>>,
              eth_vault: <<251, 166, 108, 177, 12, 75, 122, 107, 75, 40, 213, 100, 84,
                144, 149, 233, 51, 113, 241, 39>>,
              payment_exit_game: <<46, 45, 160, 17, 133, 199, 147, 185, 219, 167, 254,
                189, 68, 155, 161, 67, 157, 232, 150, 192>>,
              plasma_framework: <<212, 208, 193, 113, 0, 41, 127, 183, 124, 59, 69, 35,
                237, 84, 39, 90, 115, 43, 109, 5>>
            },
            txhash_contract: <<119, 85, 222, 162, 75, 187, 39, 212, 112, 128, 137, 97,
              210, 124, 44, 128, 216, 242, 111, 255, 81, 205, 51, 41, 192, 45, 185, 195,
              10, 40, 141, 10>>
          }
         assert {:ok, false} = RootChainHelper.has_token(<<1::160>>, contract.contract_addr)
       end
     end
   end

   #@tag fixtures: [:contract]
   #test "get_child_chain/2 returns the current block hash and timestamp", %{contract: contract} do
     #use_cassette "get_child_chain" do
       #IO.inspect(contract)
       #block = RootChain.submit_block(
       #<<234::256>>,
       #1,
       #20_000_000_000,
       #contract.authority_addr,
       #contract.contract_addr
       #)

       #assert {:ok, _} = 
       #DevHelpers.transact_sync!(block)

       #assert {:ok, {child_chain_hash, child_chain_time}} = 
       #RootChain.get_child_chain(1000, contract.contract_addr)

       #assert is_binary(child_chain_hash)
       #assert byte_size(child_chain_hash) == 32
       #assert is_integer(child_chain_time)
     #end
   #end

   #@tag fixtures: [:contract]
   #test "get_deposits/3 returns deposit events", %{contract: contract} do
  ## not using OMG.ChildChain.Transaction to not depend on that in omg_eth tests
  ## payment marker, no inputs, one output, metadata
   #tx =
   #[<<1>>, [], [[contract.authority_addr, @eth, 1]], <<0::256>>]
   #|> ExRLP.encode()

   #{:ok, tx_hash} =
   #RootChainHelper.deposit(tx, 1, contract.authority_addr, contract.contract_addr)
   #|> DevHelpers.transact_sync!()

   #{:ok, height} = Eth.get_ethereum_height()

   #authority_addr = contract.authority_addr
   #root_chain_txhash = Encoding.from_hex(tx_hash["transactionHash"])

   #deposits = RootChain.get_deposits(1, height, contract.contract_addr)

   #assert {:ok,
   #[
   #%{
   #amount: 1,
   #blknum: 1,
   #owner: ^authority_addr,
   #currency: @eth,
   #eth_height: height,
   #log_index: 0,
   #root_chain_txhash: ^root_chain_txhash
   #}
   #]} = deposits
   #end
end
