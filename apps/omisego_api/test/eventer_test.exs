defmodule OmiseGO.API.Eventer.CoreTest do

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Eventer.Core

  describe "listener subscribes on events," do

    test "listener is registered and OmiseGO address is subscribed on given topics" do

    end

    test "multiple listeners are subscribed with the same OmiseGO address" do

    end

    test "listener subscribes for new topics and previously subscribed topics are preserved" do

    end
  end

  describe "listener unsubscribes from a topic," do

    test "address is no longer subscribed for the topic" do

    end

    test "it is possible to unsubscribe from a non-existent optic" do

    end

    test "when user unsubscribes from all topics, state is garbage collected" do

    end
  end

  describe "listener is notificated," do

    test "events trigger notifications" do

    end
  end
end
