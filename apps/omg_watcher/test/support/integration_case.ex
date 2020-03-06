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

defmodule OMG.Watcher.IntegrationCase do
  @moduledoc """
  This module defines the setup for watcher integration tests.

  Since some tests also require access to WatcherInfo, this is one area
  where the app boundary is violated. This test case template does not try
  to resolve that, but it can give a quick overview of what components
  are violating the boundary from the setup.

  You may define functions here to be used as helpers in
  your tests.
  """
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import OMG.WatcherInfo.DataCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(OMG.WatcherInfo.DB.Repo)

    unless tags[:async] do
      Sandbox.mode(OMG.WatcherInfo.DB.Repo, {:shared, self()})
    end

    :ok
  end
end
