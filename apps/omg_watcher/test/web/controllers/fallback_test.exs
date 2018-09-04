defmodule OMG.Watcher.Web.Controller.FallbackTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.Watcher.TestHelper

  @moduletag :integration

  describe "Controller.FallbackTest" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fallback returns error for non exsisting endpoint" do
      %{
        "data" => %{
          "code" => "internal_server_error",
          "description" => "endpoint_not_found"
        },
        "result" => "error"
      } = TestHelper.rest_call(:get, "/non_exsisting_endpoint")
    end
  end
end
