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

defmodule OMG.WatcherInfo.PendingBlockProcessorTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]
  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.DB.Block
  alias OMG.WatcherInfo.DB.PendingBlock
  alias OMG.WatcherInfo.PendingBlockProcessor

  @interval 200

  describe "handle_info/2" do
    setup tags do
      {:ok, pid} =
        PendingBlockProcessor.start_link(
          processing_interval: @interval,
          name: PendingBlockProcessorTest
        )

      Map.put(tags, :pid, pid)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "processes the next pending block in queue", %{pid: pid} do
      :erlang.trace(pid, true, [:receive])

      assert get_all_pending_blocks() == []
      assert get_all_blocks() == []

      %{blknum: blknum_1} = insert(:pending_block)
      %{blknum: blknum_2} = insert(:pending_block)
      %{blknum: blknum_3} = insert(:pending_block)

      assert_receive {:trace, ^pid, :receive, :timeout}, @interval + 50
      get_state(pid)

      assert [%{blknum: ^blknum_1}] = get_all_blocks()
      assert [%{blknum: ^blknum_2}, %{blknum: ^blknum_3}] = get_all_pending_blocks()

      assert_receive {:trace, ^pid, :receive, :timeout}
      get_state(pid)

      assert [%{blknum: ^blknum_3}] = get_all_pending_blocks()
      assert [%{blknum: ^blknum_1}, %{blknum: ^blknum_2}] = get_all_blocks()

      assert_receive {:trace, ^pid, :receive, :timeout}
      get_state(pid)

      assert get_all_pending_blocks() == []
      assert [%{blknum: ^blknum_1}, %{blknum: ^blknum_2}, %{blknum: ^blknum_3}] = get_all_blocks()
    end
  end

  defp get_all_pending_blocks() do
    PendingBlock |> from(order_by: :blknum) |> DB.Repo.all()
  end

  defp get_all_blocks() do
    Block |> from(order_by: :blknum) |> DB.Repo.all()
  end

  defp get_state(pid) do
    :sys.get_state(pid)
  end
end
