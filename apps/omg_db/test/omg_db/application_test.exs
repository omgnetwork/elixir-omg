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

defmodule OMG.DB.ApplicationTest do
  @moduledoc """
  Only tests if the application can start and stop and the db can init at some location
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  @moduletag :wrappers
  @moduletag :common

  @tag fixtures: [:db_initialized]
  test "starts and stops app, inits", %{db_initialized: db_result} do
    assert :ok = db_result
  end
end
