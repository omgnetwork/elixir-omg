defmodule OmiseGOWatcherWeb.ErrorViewTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  @tag fixtures: [:watcher_repo]
  test "renders 404.json" do
    assert render(OmiseGOWatcherWeb.ErrorView, "404.json", []) == %{errors: %{detail: "Not Found"}}
  end

  @tag fixtures: [:watcher_repo]
  test "renders 500.json" do
    assert render(OmiseGOWatcherWeb.ErrorView, "500.json", []) == %{errors: %{detail: "Internal Server Error"}}
  end
end
