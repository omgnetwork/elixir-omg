# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.WatcherInfo.BlockApplicationConsumerTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Watcher.BlockGetter.BlockApplication
  alias OMG.WatcherInfo.BlockApplicationConsumer
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.PendingBlock

  setup tags do
    {:ok, pid} =
      BlockApplicationConsumer.start_link(
        bus_module: __MODULE__.FakeBus,
        name: BlockApplicationConsumerTest
      )

    Map.put(tags, :pid, pid)
  end

  describe "handle_info/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "inserts the given block application into pending block", %{pid: pid} do
      block_application = %BlockApplication{
        number: 1_000,
        eth_height: 1,
        eth_height_done: true,
        hash: "0x1000",
        transactions: [],
        timestamp: 1_576_500_000
      }

      send_events_and_wait_until_processed(block_application, pid)

      expected_data =
        :erlang.term_to_binary(%{
          eth_height: block_application.eth_height,
          blknum: block_application.number,
          blkhash: block_application.hash,
          timestamp: block_application.timestamp,
          transactions: block_application.transactions
        })

      assert [%PendingBlock{blknum: 1000, data: ^expected_data}] = DB.Repo.all(PendingBlock)
    end
  end

  defp send_events_and_wait_until_processed(block, pid) do
    Process.send(pid, {:internal_event_bus, :block_received, block}, [:noconnect])

    # this waits for all messages in process inbox is processed
    _ = :sys.get_state(pid)
  end

  defmodule FakeBus do
    def subscribe(_topic, _args), do: :ok
  end
end
