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

defmodule OMG.WatcherRPC.Web.Validator.BlockConstraintsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures
  use OMG.Watcher.Fixtures

  alias OMG.State.Transaction
  alias OMG.TestHelper, as: Test
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper

  alias OMG.WatcherRPC.Web.Validator.BlockConstraints

  describe "parse/1" do
    test "returns block constraints when given page and limit" do
      request_data = %{"page" => 1, "limit" => 100}

      {:ok, constraints} = BlockConstraints.parse(request_data)
      assert constraints == [page: 1, limit: 100]
    end

    test "returns an error when page == 0" do
      request_data = %{"page" => 0}
      {:error, error_data} = BlockConstraints.parse(request_data)

      assert error_data == {:validation_error, "page", {:greater, 0}}
    end
  end
end
