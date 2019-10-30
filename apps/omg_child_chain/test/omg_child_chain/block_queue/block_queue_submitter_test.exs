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

defmodule OMG.ChildChain.BlockQueue.BlockQueueSubmitterTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import OMG.ChildChain.BlockTestHelper

  alias OMG.ChildChain.BlockQueue.BlockQueueCore
  alias OMG.ChildChain.BlockQueue.BlockQueueSubmitter
  alias OMG.ChildChain.BlockQueue.BlockSubmission

  alias OMG.ChildChain.FakeRootChain

  @child_block_interval 1000
  @known_transaction_response %{"code" => -32_000, "message" => "known transaction tx"}
  @already_imported_transaction_response %{
    "code" => -32_010,
    "message" => "Transaction with the same hash was already imported."
  }
  @replacement_transaction_response %{"code" => -32_000, "message" => "replacement transaction underpriced"}
  @gas_price_too_low_response %{"code" => -32_010, "message" => "Transaction gas price is too low. There is another"}
  @nonce_too_low_response %{"code" => -32_000, "message" => "nonce too low"}
  @account_locked_response %{"code" => -32_000, "message" => "authentication needed: password or unlock"}
  @nonce_too_low_response %{"code" => -32_000, "message" => "nonce too low"}
  @transaction_nonce_too_low %{"code" => -32_010, "message" => "Transaction nonce is too low."}

  doctest OMG.ChildChain.BlockQueue.BlockQueueSubmitter

  describe "pending_mining_filter_func/1" do
    test "returns a function that can be used to gets blocks between mined_child_block_num + interval and formed_child_block_num " do
      func =
        BlockQueueSubmitter.pending_mining_filter_func(%{
          formed_child_block_num: 5,
          mined_child_block_num: 2,
          child_block_interval: 1
        })

      res = Enum.filter([{1, nil}, {2, nil}, {3, nil}, {4, nil}, {5, nil}], func)
      assert res == [{3, nil}, {4, nil}, {5, nil}]
    end

    test "returns a function that can be used to find the first block following mined_child_block_num" do
      func =
        BlockQueueSubmitter.pending_mining_filter_func(%{
          formed_child_block_num: 5,
          mined_child_block_num: 2,
          child_block_interval: 1
        })

      res = Enum.find([{1, nil}, {2, nil}, {3, nil}, {4, nil}, {5, nil}], func)
      assert res == {3, nil}
    end
  end

  describe "get_blocks_to_submit/1" do
    test "returns the list of blocks between the last mined child block num (exclusive)
          to the last formed block (inclusive)" do
      assert BlockQueueSubmitter.get_blocks_to_submit(%{
               blocks: get_blocks(10),
               formed_child_block_num: 10_000,
               gas_price_to_use: 1,
               mined_child_block_num: 6_000,
               child_block_interval: @child_block_interval
             }) == get_blocks_list(10, 7)
    end

    test "recovers after restart to proper mined height" do
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] =
               [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}]
               |> recover_state(7000)
               |> elem(1)
               |> BlockQueueSubmitter.get_blocks_to_submit()
    end

    test "recovers after restart even when only empty blocks were mined" do
      assert [%{hash: "0", nonce: 8}, %{hash: "0", nonce: 9}] =
               [{5000, "0"}, {6000, "0"}, {7000, "0"}, {8000, "0"}, {9000, "0"}]
               |> recover_state(7000, "0")
               |> elem(1)
               |> BlockQueueSubmitter.get_blocks_to_submit()
    end
  end

  describe "submit/1" do
    test "submits successfully" do
      assert BlockQueueSubmitter.submit(get_submission("success"), FakeRootChain) == :ok
    end

    # TODO: not sure if this should be the actual behavior we want
    test "fails to submit because nonce is too low" do
      assert capture_log(fn ->
               assert_raise(RuntimeError, fn ->
                 assert BlockQueueSubmitter.submit(get_submission("nonce_too_low", 15), FakeRootChain)
               end)
             end) =~ "Ethereum operation failed"
    end
  end

  describe "process_submit_result/3" do
    test "returns :ok when valid result" do
      # TODO: We'd have to change the logger level globally to capture the [info] logs
      assert BlockQueueSubmitter.process_submit_result({:ok, "hash"}, get_submission(), 11) == :ok
    end

    test "returns :ok when the transaction is already known" do
      res = {:error, @known_transaction_response}
      assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 11) == :ok
    end

    test "returns :ok when a transaction with the same hash was already imported" do
      res = {:error, @already_imported_transaction_response}
      assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 11) == :ok
    end

    test "returns :ok and logs error when the transaction is underpriced" do
      res = {:error, @replacement_transaction_response}
      assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 11) == :ok
    end

    test "returns :ok and logs error when the gas price is too low" do
      res = {:error, @gas_price_too_low_response}
      assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 11) == :ok
    end

    test "returns {:error, :account_locked} and logs the error when the authority account is locked" do
      res = {:error, @account_locked_response}

      assert capture_log(fn ->
               assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 11) == {:error, :account_locked}
             end) =~ "It seems that authority account is locked"
    end

    test "returns :ok when the nonce is too low and the submission has already been mined" do
      res = {:error, @nonce_too_low_response}
      assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 11) == :ok
    end

    test "returns {:error, :nonce_too_low} when the nonce is too low and the submission hasn't been mined" do
      res = {:error, @transaction_nonce_too_low}

      assert capture_log(fn ->
               assert BlockQueueSubmitter.process_submit_result(res, get_submission(), 9) == {:error, :nonce_too_low}
             end) =~ "Submission unexpectedly failed with nonce too low"
    end
  end
end
