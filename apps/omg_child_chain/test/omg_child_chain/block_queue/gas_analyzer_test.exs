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

defmodule OMG.ChildChain.BlockQueue.GasAnalyzerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias OMG.ChildChain.BlockQueue.GasAnalyzer

  setup do
    {:ok, gas_analyzer} = GasAnalyzer.start_link(name: String.to_atom("test-#{:rand.uniform(1000)}"))
    handler_id = {:gas_subbmission_handler, :rand.uniform(100)}

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    {:ok, %{gas_analyzer: gas_analyzer, handler_id: handler_id}}
  end

  describe "handle_info/2" do
    test "queue gets emptied when gas gets calculated", %{
      gas_analyzer: gas_analyzer,
      handler_id: handler_id
    } do
      # we're mocking ethereumex with our module
      :sys.replace_state(gas_analyzer, fn state -> Map.put(state, :rpc, __MODULE__.EthExSuccessMock) end)
      # creating a telemetry handler in this process so that when event gets executed, a message gets sent
      # to this process... hence the self() and parent
      attach(handler_id, [:gas, GasAnalyzer], self())
      # mimick a blockqueue wanting to submit a block to ethereum which would cause the hash to get to the gas analyzer
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo")
      # manually invoking the info message which normally gets triggered by a 3second timeout
      send(gas_analyzer, :get_gas_used)
      # we're just waiting for the message to get processed
      assert_receive({:event, [:gas, OMG.ChildChain.BlockQueue.GasAnalyzer], %{gas: 84_681}, %{}}, 100)
      state = :sys.get_state(gas_analyzer)
      # the gas analyzer queue needs to be empty now
      assert :queue.to_list(state.txhash_queue) == []
    end
  end

  describe "enqueue/1, telemetry subscription" do
    test "telemetry event gets executed when gas is retrieved and calculated", %{
      gas_analyzer: gas_analyzer,
      handler_id: handler_id
    } do
      # we're mocking ethereumex with our module
      :sys.replace_state(gas_analyzer, fn state -> Map.put(state, :rpc, __MODULE__.EthExSuccessMock) end)
      # creating a telemetry handler in this process so that when event gets executed, a message gets sent
      # to this process... hence the self() and parent
      attach(handler_id, [:gas, GasAnalyzer], self())
      # mimick a blockqueue wanting to submit a block to ethereum which would cause the hash to get to the gas analyzer
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo")
      # manually invoking the info message which normally gets triggered by a 3second timeout
      send(gas_analyzer, :get_gas_used)
      # we're just waiting for the message to get processed
      assert_receive({:event, [:gas, OMG.ChildChain.BlockQueue.GasAnalyzer], %{gas: 84_681}, %{}}, 100)
    end

    test "that telemetry event is not executed when we cant calculate gas", %{
      gas_analyzer: gas_analyzer,
      handler_id: handler_id
    } do
      # we're mocking ethereumex with our module
      :sys.replace_state(gas_analyzer, fn state -> Map.put(state, :rpc, __MODULE__.EthExErrorMock) end)
      # creating a telemetry handler in this process so that when event gets executed, a message gets sent
      # to this process... hence the self() and parent
      attach(handler_id, [:gas, GasAnalyzer], self())
      # mimick a blockqueue wanting to submit a block to ethereum which would cause the hash to get to the gas analyzer
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo")
      # manually invoking the info message which normally gets triggered by a 3second timeout
      # because of the faulty ethereumex mock, we should not receive any telemetry events!
      assert capture_log(fn ->
               send(gas_analyzer, :get_gas_used)

               refute_receive(
                 {:event, [:gas, OMG.ChildChain.BlockQueue.GasAnalyzer], %{gas: 84_681}, %{}},
                 100
               )
             end)
    end
  end

  describe "enqueue/1, handle_info queue behaviour" do
    test "that the order of txhashes is preserved when they can't get processed", %{
      gas_analyzer: gas_analyzer,
      handler_id: handler_id
    } do
      # we're mocking ethereumex with our module
      :sys.replace_state(gas_analyzer, fn state -> Map.put(state, :rpc, __MODULE__.EthExErrorMock) end)
      # creating a telemetry handler in this process so that when event gets executed, a message gets sent
      # to this process... hence the self() and parent
      attach(handler_id, [:gas, GasAnalyzer], self())
      # mimick a blockqueue wanting to submit a block to ethereum which would cause the hash to get to the gas analyzer
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo")
      # now the hash has ben enqueued hopefully, lets check
      assert capture_log(fn ->
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               assert :queue.member({"0xyolo", 1}, state.txhash_queue) == true
               assert :queue.len(state.txhash_queue) == 1
             end)

      # we're adding two more hashes into the queue and verifing the order in the queue
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo2")
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo3")

      assert capture_log(fn ->
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               assert :queue.to_list(state.txhash_queue) == [{"0xyolo", 2}, {"0xyolo2", 0}, {"0xyolo3", 0}]
               # all three are in the queue, lets try to get gas and put 0xyolo back in
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               assert :queue.to_list(state.txhash_queue) == [{"0xyolo", 3}, {"0xyolo2", 0}, {"0xyolo3", 0}]
             end)
    end

    test "that the order of txhashes is preserved when they can't get processed and that when threshold is met the tx hash gets removed",
         %{
           gas_analyzer: gas_analyzer,
           handler_id: handler_id
         } do
      # we're mocking ethereumex with our module
      :sys.replace_state(gas_analyzer, fn state -> Map.put(state, :rpc, __MODULE__.EthExErrorMock) end)
      # creating a telemetry handler in this process so that when event gets executed, a message gets sent
      # to this process... hence the self() and parent
      attach(handler_id, [:gas, GasAnalyzer], self())
      # tx hash was added in the queue, the starting retry_index is 0
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo")

      assert capture_log(fn ->
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               # the first time we check for gas we increment the retry_index to 1
               assert :queue.member({"0xyolo", 1}, state.txhash_queue) == true
             end)

      # we're adding two more hashes into the queue and verifing the order in the queue
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo2")
      GasAnalyzer.enqueue(gas_analyzer, "0xyolo3")

      assert capture_log(fn ->
               # we now have two more hashes in the queue, their retry index should remain 0
               # we try and get gas again
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               assert :queue.to_list(state.txhash_queue) == [{"0xyolo", 2}, {"0xyolo2", 0}, {"0xyolo3", 0}]
               send(gas_analyzer, :get_gas_used)
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               # at this point, the retry index is above the treshold 3, which means it was removed and the next
               # tx hash would be processed
               assert :queue.to_list(state.txhash_queue) == [{"0xyolo2", 0}, {"0xyolo3", 0}]
               send(gas_analyzer, :get_gas_used)
               state = :sys.get_state(gas_analyzer)
               assert :queue.to_list(state.txhash_queue) == [{"0xyolo2", 1}, {"0xyolo3", 0}]
             end)
    end
  end

  defp attach(handler_id, event, parent) do
    :telemetry.attach(
      handler_id,
      event,
      fn event, measurements, metadata, _ ->
        send(parent, {:event, event, measurements, metadata})
      end,
      nil
    )
  end

  # this module serves as a mock of the ethereumex
  defmodule EthExErrorMock do
    def eth_get_transaction_receipt(_), do: {:error, %{"bruv" => "0x123"}}
    def eth_get_transaction_by_hash(_), do: {:error, %{"bruv" => "0x123"}}
  end

  # this module serves as a success mock of the ethereumex
  defmodule EthExSuccessMock do
    def eth_get_transaction_receipt(_), do: {:ok, %{"gasUsed" => "0x123"}}
    def eth_get_transaction_by_hash(_), do: {:ok, %{"gasPrice" => "0x123"}}
  end
end
