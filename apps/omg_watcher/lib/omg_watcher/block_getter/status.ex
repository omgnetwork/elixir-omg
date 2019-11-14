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

defmodule OMG.Watcher.BlockGetter.Status do
  @moduledoc """
  Keeps track and exposes the current status of `OMG.Watcher.BlockGetter`.

  The reason to have this is that the parent `OMG.Watcher.BlockGetter` is doing a lot of synchronous heavy lifting and
  can easily become unresponsive when syncing (especially when catching up a lot of blocks).

  Expects current status to be eagerly pushed to it.
  """

  alias OMG.Watcher.BlockGetter.Core

  def start_link do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  @doc """
  Overwrites the currently stored status with the provided one
  """
  @spec update(Core.chain_ok_response_t()) :: :ok
  def update(status), do: Agent.update(__MODULE__, fn _old_status -> status end)

  @doc """
  Retrieves the freshest information about `OMG.Watcher.BlockGetter`'s status.
  Prefer `OMG.Watcher.BlockGetter.get_events/0` to this
  """
  @spec get_events() :: {:ok, Core.chain_ok_response_t()}
  def get_events, do: Agent.get(__MODULE__, fn status -> {:ok, status} end)
end
