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

ExUnit.configure(exclude: [integration: true, property: true, wrappers: true])
ExUnitFixtures.start()
capture_log = if(System.get_env("CAPTURE_LOG"), do: false, else: true)
ExUnit.start(capture_log: capture_log)

{:ok, _} = Application.ensure_all_started(:httpoison)
{:ok, _} = Application.ensure_all_started(:fake_server)

# TODO: even though watcher does not have postgres, this needs to be here
# because tests breach scope
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))

{:ok, _} = Application.ensure_all_started(:briefly)
{:ok, _} = Application.ensure_all_started(:erlexec)
