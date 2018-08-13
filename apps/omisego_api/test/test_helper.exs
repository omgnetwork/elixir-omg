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

ExUnit.configure(exclude: [integration: true, property: true])
Code.require_file("../omisego_eth/test/fixtures.exs")
Code.require_file("../omisego_db/test/fixtures.exs")
Application.ensure_all_started(:propcheck)
ExUnitFixtures.start()
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()
