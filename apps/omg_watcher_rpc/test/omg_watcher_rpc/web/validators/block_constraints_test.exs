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
  use ExUnit.Case, async: true

  alias OMG.WatcherRPC.Web.Validator.BlockConstraints

  describe "parse/1" do
    test "returns page and limit constraints when given page and limit params" do
      request_data = %{"page" => 1, "limit" => 100}

      {:ok, constraints} = BlockConstraints.parse(request_data)
      assert constraints == [page: 1, limit: 100]
    end

    test "returns empty constraints when given no params" do
      request_data = %{}

      {:ok, constraints} = BlockConstraints.parse(request_data)
      assert constraints == []
    end

    test "returns a :validation_error when the given page == 0" do
      assert BlockConstraints.parse(%{"page" => 0}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given page < 0" do
      assert BlockConstraints.parse(%{"page" => -1}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given page is not an integer" do
      assert BlockConstraints.parse(%{"page" => 3.14}) == {:error, {:validation_error, "page", :integer}}
      assert BlockConstraints.parse(%{"page" => "abcd"}) == {:error, {:validation_error, "page", :integer}}
    end

    test "returns a :validation_error when the given limit == 0" do
      assert BlockConstraints.parse(%{"page" => 0}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given limit < 0" do
      assert BlockConstraints.parse(%{"page" => -1}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given limit is not an integer" do
      assert BlockConstraints.parse(%{"page" => 3.14}) == {:error, {:validation_error, "page", :integer}}
      assert BlockConstraints.parse(%{"page" => "abcd"}) == {:error, {:validation_error, "page", :integer}}
    end
  end
end
