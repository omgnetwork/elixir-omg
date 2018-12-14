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

defmodule OMG.RPC.Fixtures do
  use ExUnitFixtures.FixtureModule

  @doc "run only endpoint to make request"
  deffixture phoenix_sandbox do
    {:ok, _} = Application.ensure_all_started(:cowboy)
    Supervisor.start_link([OMG.RPC.Web.Endpoint], strategy: :one_for_one, name: OMG.RPC.Supervisor)
  end
end
