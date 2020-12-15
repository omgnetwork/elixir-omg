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

defmodule LoadTest.Runner.StandardExitTest do
  @moduledoc """
  Runs a smoke test for utxos load test
  """
  use ExUnit.Case

  @tag timeout: 6_000_000
  test "should run standard exit load test" do
    Chaperon.run_load_test(LoadTest.Runner.StandardExits, print_results: true)
  end
end
