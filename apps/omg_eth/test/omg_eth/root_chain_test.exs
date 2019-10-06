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
        authority_addr:
          <<43, 115, 116, 111, 19, 134, 182, 109, 169, 69, 62, 95, 229, 129, 214, 127, 232, 112, 252, 64>>,
        contract_addr: %{
          erc20_vault: <<66, 104, 246, 251, 169, 120, 42, 138, 77, 87, 95, 180, 249, 9, 38, 33, 143, 173, 19, 80>>,
          eth_vault: <<42, 66, 198, 153, 16, 218, 175, 248, 245, 86, 188, 119, 71, 199, 213, 207, 251, 32, 47, 139>>,
          payment_exit_game:
            <<193, 146, 112, 248, 74, 71, 182, 90, 186, 190, 200, 2, 71, 76, 203, 238, 223, 36, 214, 127>>,
          plasma_framework:
            <<162, 44, 52, 215, 242, 121, 110, 74, 248, 212, 8, 47, 116, 124, 144, 215, 95, 228, 179, 167>>
        },
        txhash_contract:
          <<101, 59, 205, 16, 187, 175, 70, 146, 6, 220, 158, 196, 242, 61, 224, 122, 143, 200, 21, 17, 108, 228, 148,
            175, 247, 55, 57, 211, 125, 133, 140, 224>>
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
          authority_addr: <<124, 186, 31, 78, 163, 98, 19, 11, 188, 32, 190, 124, 192, 194, 55, 60, 74, 192, 29, 225>>,
          contract_addr: %{
            erc20_vault: <<105, 30, 198, 198, 233, 57, 52, 41, 224, 79, 246, 113, 62, 95, 85, 201, 190, 33, 2, 204>>,
            eth_vault: <<9, 246, 237, 141, 63, 198, 60, 148, 62, 16, 138, 98, 18, 190, 59, 166, 179, 55, 121, 145>>,
            payment_exit_game:
              <<91, 132, 138, 118, 46, 220, 49, 149, 167, 71, 189, 118, 22, 102, 205, 97, 21, 115, 19, 155>>,
            plasma_framework:
              <<28, 201, 241, 79, 241, 192, 96, 248, 188, 149, 238, 210, 78, 236, 89, 149, 14, 225, 245, 114>>
          },
          txhash_contract:
            <<19, 255, 229, 249, 198, 159, 141, 150, 51, 116, 115, 149, 45, 70, 189, 174, 66, 128, 234, 181, 168, 160,
              89, 117, 245, 239, 156, 243, 231, 61, 140, 166>>
        }

        assert {:ok, true} = RootChainHelper.has_token(@eth, contract.contract_addr)
      end
    end

    test "returns false if no token exists" do
      use_cassette "has_token_false", match_requests_on: [:request_body] do
        contract = %{
          authority_addr: <<224, 163, 124, 151, 37, 126, 191, 248, 81, 214, 42, 187, 145, 76, 9, 179, 47, 233, 51, 20>>,
          contract_addr: %{
            erc20_vault:
              <<217, 159, 111, 59, 33, 98, 167, 158, 227, 188, 192, 172, 199, 246, 122, 138, 134, 194, 32, 240>>,
            eth_vault: <<251, 166, 108, 177, 12, 75, 122, 107, 75, 40, 213, 100, 84, 144, 149, 233, 51, 113, 241, 39>>,
            payment_exit_game:
              <<46, 45, 160, 17, 133, 199, 147, 185, 219, 167, 254, 189, 68, 155, 161, 67, 157, 232, 150, 192>>,
            plasma_framework: <<212, 208, 193, 113, 0, 41, 127, 183, 124, 59, 69, 35, 237, 84, 39, 90, 115, 43, 109, 5>>
          },
          txhash_contract:
            <<119, 85, 222, 162, 75, 187, 39, 212, 112, 128, 137, 97, 210, 124, 44, 128, 216, 242, 111, 255, 81, 205,
              51, 41, 192, 45, 185, 195, 10, 40, 141, 10>>
        }

        assert {:ok, false} = RootChainHelper.has_token(<<1::160>>, contract.contract_addr)
      end
    end
  end

  test "get_child_chain/2 returns the current block hash and timestamp" do
    use_cassette "get_child_chain", match_requests_on: [:request_body] do
      contract = %{
        authority_addr:
          <<104, 176, 171, 146, 138, 75, 137, 196, 64, 238, 106, 158, 249, 147, 207, 41, 202, 201, 228, 65>>,
        contract_addr: %{
          erc20_vault: <<248, 193, 244, 123, 251, 99, 125, 141, 190, 25, 42, 199, 117, 37, 44, 143, 23, 26, 223, 12>>,
          eth_vault: <<133, 74, 216, 137, 104, 91, 60, 72, 178, 38, 22, 215, 45, 114, 193, 238, 228, 6, 137, 107>>,
          payment_exit_game:
            <<82, 69, 194, 204, 203, 232, 133, 169, 222, 189, 4, 159, 52, 87, 159, 217, 32, 166, 6, 199>>,
          plasma_framework:
            <<245, 108, 83, 89, 101, 174, 4, 245, 135, 119, 181, 244, 110, 73, 61, 125, 184, 84, 59, 225>>
        },
        txhash_contract:
          <<191, 228, 169, 228, 54, 210, 6, 191, 252, 75, 192, 52, 186, 24, 226, 80, 43, 72, 142, 168, 105, 205, 53, 91,
            69, 162, 158, 75, 63, 226, 225, 255>>
      }

      {:ok, {child_chain_hash, child_chain_time}} = RootChain.get_child_chain(0, contract.contract_addr)

      assert is_binary(child_chain_hash)
      assert byte_size(child_chain_hash) == 32
      assert is_integer(child_chain_time)
    end
  end

  test "submit_block/1 submits a block to the contract" do
    use_cassette "submit_block", match_requests_on: [:request_body] do
      contract = %{
        authority_addr: <<27, 61, 218, 82, 247, 223, 227, 240, 175, 166, 246, 188, 235, 74, 124, 80, 55, 58, 129, 127>>,
        contract_addr: %{
          erc20_vault: <<196, 114, 137, 0, 212, 213, 236, 142, 82, 103, 118, 125, 73, 58, 98, 198, 77, 174, 90, 104>>,
          eth_vault: <<58, 152, 153, 115, 93, 254, 19, 38, 250, 48, 148, 34, 16, 16, 138, 2, 187, 197, 98, 0>>,
          payment_exit_game:
            <<233, 193, 142, 59, 94, 214, 14, 104, 244, 108, 107, 102, 117, 225, 203, 67, 9, 182, 11, 252>>,
          plasma_framework:
            <<90, 152, 182, 145, 160, 37, 175, 112, 214, 237, 50, 209, 171, 12, 161, 7, 137, 42, 119, 181>>
        },
        txhash_contract:
          <<35, 97, 84, 167, 35, 220, 168, 208, 255, 156, 188, 162, 194, 18, 103, 57, 167, 238, 162, 12, 70, 117, 137,
            155, 122, 185, 18, 121, 215, 124, 163, 38>>
      }

      block =
        RootChain.submit_block(
          <<234::256>>,
          1,
          20_000_000_000,
          contract.authority_addr,
          contract.contract_addr
        )

      assert {:ok, _} = DevHelpers.transact_sync!(block)
    end
  end

  test "get_deposits/3 returns deposit events" do
    use_cassette "get_deposits" do
      contract = %{
        authority_addr: <<130, 88, 71, 242, 32, 229, 170, 158, 99, 187, 9, 191, 20, 222, 216, 78, 57, 12, 84, 166>>,
        contract_addr: %{
          erc20_vault: <<35, 58, 149, 47, 210, 251, 104, 228, 147, 225, 246, 114, 230, 57, 5, 15, 11, 97, 38, 25>>,
          eth_vault: <<11, 116, 178, 235, 168, 218, 198, 67, 69, 147, 244, 183, 178, 23, 6, 85, 124, 28, 253, 115>>,
          payment_exit_game: <<151, 188, 110, 247, 38, 78, 67, 79, 53, 154, 169, 25, 26, 251, 196, 70, 48, 40, 8, 238>>,
          plasma_framework:
            <<37, 228, 22, 32, 103, 146, 170, 159, 95, 57, 101, 150, 31, 182, 143, 90, 137, 204, 134, 103>>
        },
        txhash_contract:
          <<175, 145, 234, 243, 233, 208, 195, 206, 165, 45, 144, 90, 174, 138, 135, 179, 98, 249, 136, 181, 109, 130,
            222, 10, 66, 121, 206, 36, 67, 23, 96, 34>>
      }

      # not using OMG.ChildChain.Transaction to not depend on that in omg_eth tests
      # payment marker, no inputs, one output, metadata
      tx =
        [<<1>>, [], [[contract.authority_addr, @eth, 1]], <<0::256>>]
        |> ExRLP.encode()

      {:ok, tx_hash} =
        RootChainHelper.deposit(tx, 1, contract.authority_addr, contract.contract_addr)
        |> DevHelpers.transact_sync!()

      {:ok, height} = Eth.get_ethereum_height()

      authority_addr = contract.authority_addr
      root_chain_txhash = Encoding.from_hex(tx_hash["transactionHash"])

      deposits = RootChain.get_deposits(1, height, contract.contract_addr)

      assert {:ok,
              [
                %{
                  amount: 1,
                  blknum: 1,
                  owner: ^authority_addr,
                  currency: @eth,
                  eth_height: height,
                  log_index: 0,
                  root_chain_txhash: ^root_chain_txhash
                }
              ]} = deposits
    end
  end
end
