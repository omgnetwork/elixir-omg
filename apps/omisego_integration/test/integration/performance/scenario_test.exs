defmodule HonteD.Integration.Performance.ScenarioTest do
  @moduledoc """
  Unit test for performance scenario generation.
  Check is done on abci.state level - no IO is involved.
  """

  alias HonteD.ABCI.State
  alias HonteD.Integration.Performance.Scenario

  use ExUnit.Case, async: true

  def run(scenario, n) do
    state =
      scenario
      |> Scenario.get_setup()
      |> List.flatten()
      |> Enum.reduce(State.initial(:test_db), &apply_tx/2)

    scenario
    |> Scenario.get_send_txs()
    |> hd()
    |> Enum.take(n)
    |> Enum.reduce(state, &apply_tx/2)
  end

  def apply_tx({success_expected, tx}, state) do
    {:ok, decoded} = tx |> Base.decode16!() |> HonteD.TxCodec.decode()
    # Signature check is needed to properly simulate abci/state behavior.
    :ok = HonteD.Transaction.Validation.valid_signed?(decoded)
    case State.exec(state, decoded) do
      {:ok, state} when success_expected -> state
      {:error, :insufficient_funds} when not success_expected -> state
    end
  end

  describe "Test scenario generation correctness." do
    test "Scenario executes: setup and load from one of the senders" do
      run(Scenario.new(2, 10), 10)
    end

    test "Scenario.new/2 crashes for strange values." do
      catch_error(Scenario.new(10, 0))
    end

    test "Can generate empty scenarios with Scenario.new/2" do
      empty = Scenario.new(0, 10)

      assert Scenario.get_setup(empty) == []
      assert Scenario.get_senders(empty) == []
      assert Scenario.get_send_txs(empty) == []
    end

    test "Scenarios are deterministic." do
      scenario1 = Scenario.new(2, 10)
      run1 = Enum.take(hd(Scenario.get_send_txs(scenario1)), 10)
      scenario2 = Scenario.new(2, 10)
      run2 = Enum.take(hd(Scenario.get_send_txs(scenario2)), 10)
      assert run1 == run2
    end

    test "Scenarios are not identical." do
      scenario1 = Scenario.new(2, 10)
      run1 = Enum.take(hd(Scenario.get_send_txs(scenario1)), 10)
      scenario3 = Scenario.new(3, 10)
      run3 = Enum.take(hd(Scenario.get_send_txs(scenario3)), 10)
      assert run1 != run3
    end

    test "Scenario can skip transactions and remain correct" do
      scenario = Scenario.new(2, 10)
      to_skip = 100
      state = run(scenario, to_skip)

      scenario
      |> Scenario.get_send_txs(skip_per_stream: to_skip)
      |> hd()
      |> Enum.take(200)
      |> Enum.reduce(state, &apply_tx/2)
    end
  end

end
