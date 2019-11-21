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

ExUnitFixtures.start()
ExUnit.configure(exclude: [integration: true, property: true, wrappers: true])
umbrella_root_dir = Application.fetch_env!(:omg, :umbrella_root_dir)
ExUnitFixtures.load_fixture_files(Path.join(umbrella_root_dir, "apps/*/test/**/fixtures.exs"))
ExUnit.start()

{:ok, _} = Application.ensure_all_started(:propcheck)
{:ok, _} = Application.ensure_all_started(:briefly)
{:ok, _} = Application.ensure_all_started(:erlexec)
