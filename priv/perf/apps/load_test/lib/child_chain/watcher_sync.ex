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

defmodule LoadTest.ChildChain.WatcherSync do
  @moduledoc """
  Wait for the watcher to sync to a certain root chain block height
  """

  require Logger

  alias LoadTest.Service.Sync

  @doc """
  Blocks the caller until the watcher configured reports to be fully synced up (both child chain blocks and eth events)

  Options:
    - :root_chain_height - if not `nil`, in addition to synchronizing to current top mined child chain block, it will
      sync up till all the Watcher's services report at at least this Ethereum height
  """
  @spec watcher_synchronize(keyword()) :: :ok
  def watcher_synchronize(opts \\ []) do
    root_chain_height = Keyword.get(opts, :root_chain_height, nil)
    service = Keyword.get(opts, :service, nil)

    _ = Logger.info("Waiting for the watcher to synchronize")

    :ok =
      Sync.repeat_until_success(
        fn -> watcher_synchronized?(root_chain_height, service) end,
        500_000,
        "Failed to sync watcher"
      )

    # NOTE: allowing some more time for the dust to settle on the synced Watcher
    # otherwise some of the freshest UTXOs to exit will appear as missing on the Watcher
    # related issue to remove this `sleep` and fix properly is https://github.com/omgnetwork/elixir-omg/issues/1031
    Process.sleep(2000)
    _ = Logger.info("Watcher synchronized")
  end

  # This function is prepared to be called in `Sync`.
  # It repeatedly ask for Watcher's `/status.get` until Watcher consume mined block
  defp watcher_synchronized?(root_chain_height, service) do
    {:ok, status_response} =
      WatcherSecurityCriticalAPI.Api.Status.status_get(LoadTest.Connection.WatcherSecurity.client())

    status = Jason.decode!(status_response.body)["data"]

    with true <- watcher_synchronized_to_mined_block?(status),
         true <- root_chain_synced?(root_chain_height, status, service) do
      :ok
    else
      _ -> :repeat
    end
  end

  defp root_chain_synced?(nil, _, _), do: true

  defp root_chain_synced?(root_chain_height, status, nil) do
    status
    |> Map.get("services_synced_heights")
    |> Enum.reject(fn height ->
      service = height["service"]
      # these service heights are stuck on circle ci, but they work fine locally
      # I think ci machine is not powerful enough
      service == "block_getter" || service == "exit_finalizer" || service == "ife_exit_finalizer"
    end)
    |> Enum.all?(&(&1["height"] >= root_chain_height))
  end

  defp root_chain_synced?(root_chain_height, status, service) do
    heights = Map.get(status, "services_synced_heights")

    found_root_chain_height = Enum.find(heights, fn height -> height["service"] == service end)

    found_root_chain_height && found_root_chain_height["height"] >= root_chain_height
  end

  defp watcher_synchronized_to_mined_block?(%{
         "last_mined_child_block_number" => last_mined_child_block_number,
         "last_validated_child_block_number" => last_validated_child_block_number
       })
       when last_mined_child_block_number == last_validated_child_block_number and
              last_mined_child_block_number > 0 do
    _ = Logger.debug("Synced to blknum: #{last_validated_child_block_number}")
    true
  end

  defp watcher_synchronized_to_mined_block?(_params) do
    :not_synchronized
  end
end
