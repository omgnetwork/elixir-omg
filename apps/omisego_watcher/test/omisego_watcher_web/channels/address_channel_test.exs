defmodule OmiseGOWatcherWeb.AddressChannelTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use Phoenix.ChannelTest

  alias OmiseGOWatcherWeb.AddressChannel
  @endpoint OmiseGOWatcherWeb.Endpoint

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "broadcasts are pushed to the client" do
    {:ok, socket} = setup()

    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push("broadcast", %{"some" => "data"})
  end

  defp setup do
    {:ok, _, socket} =
      socket("user_id", %{some: :assign})
      |> subscribe_and_join(AddressChannel, "address:")

    {:ok, socket}
  end
end
