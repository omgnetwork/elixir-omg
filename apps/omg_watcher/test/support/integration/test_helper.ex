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

defmodule OMG.Watcher.Integration.TestHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the watcher
  """

  alias OMG.API.State
  alias OMG.Eth
  alias OMG.Watcher.Web.Serializer

  import OMG.Watcher.TestHelper

  def compose_utxo_exit(blknum, txindex, oindex) do
    %{"result" => "success", "data" => decoded_data} =
      rest_call(:get, "account/utxo/compose_exit?blknum=#{blknum}&txindex=#{txindex}&oindex=#{oindex}")

    Serializer.Response.decode16(decoded_data, ["txbytes", "proof", "sigs"])
  end

  def wait_until_block_getter_fetches_block(block_nr, timeout) do
    fn ->
      Eth.WaitFor.repeat_until_ok(wait_for_block(block_nr))
    end
    |> Task.async()
    |> Task.await(timeout)

    # write to db seems to be async and wait_until_block_getter_fetches_block would return too early, so sleep
    # leverage `block` events if they get implemented
    Process.sleep(100)
  end

  defp wait_for_block(block_nr) do
    # TODO query to State used in tests instead of an event system, remove when event system is here
    fn ->
      case State.get_current_child_block_height() <= block_nr do
        true -> :repeat
        false -> {:ok, block_nr}
      end
    end
  end
end
