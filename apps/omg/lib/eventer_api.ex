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

defmodule OMG.EventerAPI do
  @moduledoc """
  Interface to cast event triggers to the `OMG.Watcher.Eventer`
  """

  @doc """
  Casts (only when `OMG.Watcher.Eventer` is started) or ignores the triggers
  """
  def emit_events(event_triggers) do
    GenServer.cast(OMG.Watcher.Eventer, {:emit_events, event_triggers})
  end
end
