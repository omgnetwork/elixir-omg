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

defmodule OMG.Watcher.Web.View.ErrorTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.Watcher.Web.View

  import Phoenix.View

  test "renders 500.json with correct structure given a custom description" do
    assigns = %{
      reason: %{
        message: "Custom assigned error description"
      }
    }

    expected = %{
      result: :error,
      data: %{
        code: "server:internal_server_error",
        description: "Custom assigned error description"
      }
    }

    assert render(View.ErrorView, "500.json", assigns) == expected
  end

  test "renders 400.json with correct structure given a custom description" do
    assigns = %{
      reason: %{
        message: "Custom assigned error description"
      }
    }

    expected = %{
      result: :error,
      data: %{
        code: "client:invalid_parameter",
        description: "Custom assigned error description"
      }
    }

    assert render(View.ErrorView, "400.json", assigns) == expected
  end

  test "renders invalid template as server error" do
    expected = %{
      result: :error,
      data: %{
        code: "server:internal_server_error",
        description: "Something went wrong on the server or template cannot be found."
      }
    }

    assert render(View.ErrorView, "invalid_template.json", []) == expected
  end
end
