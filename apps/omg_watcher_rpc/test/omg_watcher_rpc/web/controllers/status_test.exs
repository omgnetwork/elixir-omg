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

defmodule OMG.WatcherRPC.Web.Controller.StatusTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :watcher
  # a test in OMG.WatcherInfo.Integration.StatusTest fully tests the controller,
  # but it needs whole system setup so it's declared as integration test
end
