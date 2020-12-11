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

defmodule LoadTest.Scenario.WatcherStatus do
  @moduledoc """
  Calls Watcher status.get
  """
  use Chaperon.Scenario

  alias Chaperon.Session

  def run(session) do
    {:ok, response} = WatcherSecurityCriticalAPI.Api.Status.status_get(LoadTest.Connection.WatcherSecurity.client())
    watcher_status = Jason.decode!(response.body)
    Session.assign(session, watcher_status: watcher_status)
  end
end
