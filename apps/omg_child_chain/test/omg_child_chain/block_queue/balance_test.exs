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

defmodule OMG.ChildChain.BlockQueue.BalanceTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias OMG.ChildChain.BlockQueue.Balance

  setup do
    {:ok, balance_process} =
      Balance.start_link(authority_address: "", name: String.to_atom("test-#{:rand.uniform(1000)}"))

    handler_id = {:authority_balance_handler, :rand.uniform(100)}

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    {:ok, %{balance_process: balance_process, handler_id: handler_id}}
  end

  describe "handle_cast/2" do
    test "balance gets checked after API call and telemetry handler executed", %{
      balance_process: balance_process,
      handler_id: handler_id
    } do
      # we're mocking ethereumex with our module
      :sys.replace_state(balance_process, fn state -> Map.put(state, :rpc, __MODULE__.EthExSuccessMock) end)
      # creating a telemetry handler in this process so that when event gets executed, a message gets sent
      # to this process... hence the self() and parent
      attach(handler_id, [:authority_balance, Balance], self())
      # mimick a blockqueue wanting to submit a block to ethereum which would cause us to check the balance
      assert capture_log(fn ->
               Balance.check(balance_process)
               assert_receive({:event, [:authority_balance, Balance], %{authority_balance: 291}, %{}}, 100)
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

  # this module serves as a success mock of the ethereumex
  defmodule EthExSuccessMock do
    def eth_get_balance(_), do: {:ok, "0x123"}
  end
end
