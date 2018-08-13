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

defmodule OmiseGOWatcherWeb.ErrorViewTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "renders 404.json" do
    assert render(OmiseGOWatcherWeb.ErrorView, "404.json", []) == %{errors: %{detail: "Not Found"}}
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "renders 500.json" do
    assert render(OmiseGOWatcherWeb.ErrorView, "500.json", []) == %{errors: %{detail: "Internal Server Error"}}
  end
end
