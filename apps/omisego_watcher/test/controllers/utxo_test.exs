defmodule OmiseGOWatcherWeb.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures

  alias OmiseGO.API.Block
  alias OmiseGO.API.TestHelper, as: API_Helper
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.UtxoDB
  alias OmiseGOWatcher.TestHelper

  describe "UTXO database." do
    @tag fixtures: [:watcher_sandbox, :alice]
    test "No utxo are returned for non-existing addresses.", %{alice: alice} do
      assert get_utxo(alice.addr) == %{"utxos" => [], "address" => Client.encode(alice.addr)}
    end

    @tag fixtures: [:watcher_sandbox, :alice]
    test "Consumed block contents are available.", %{alice: alice} do
      UtxoDB.consume_block(%Block{
        transactions: [
          API_Helper.create_recovered([], [{alice, 1947}], 0),
          API_Helper.create_recovered([], [{alice, 1952}], 0)
        ],
        number: 2
      })

      %{"utxos" => [%{"amount" => amount1}, %{"amount" => amount2}]} = get_utxo(alice.addr)

      assert Enum.sort([amount1, amount2]) == [1947, 1952]
    end

    @tag fixtures: [:watcher_sandbox, :alice, :bob, :carol]
    test "Spent utxos are moved to new owner.", %{alice: alice, bob: bob, carol: carol} do
      UtxoDB.consume_block(%Block{
        transactions: [API_Helper.create_recovered([], [{alice, 1843}]), API_Helper.create_recovered([], [{bob, 1871}])],
        number: 1
      })

      %{"utxos" => [%{"amount" => 1871}]} = get_utxo(bob.addr)

      UtxoDB.consume_block(%Block{
        transactions: [API_Helper.create_recovered([{1, 1, 0, bob}], [{carol, 1000}])],
        number: 2
      })

      %{"utxos" => [%{"amount" => 1000}]} = get_utxo(carol.addr)
      %{"utxos" => []} = get_utxo(bob.addr)
    end

    @tag fixtures: [:watcher_sandbox, :alice]
    test "Deposits are a part of utxo set.", %{alice: alice} do
      assert %{"utxos" => []} = get_utxo(alice.addr)
      UtxoDB.insert_deposits([%{owner: alice.addr, amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo(alice.addr)
    end

    @tag fixtures: [:watcher_sandbox, :alice, :bob]
    test "Deposit utxo are moved to new owner if spent ", %{alice: alice, bob: bob} do
      assert %{"utxos" => []} = get_utxo(alice.addr)
      assert %{"utxos" => []} = get_utxo(bob.addr)
      UtxoDB.insert_deposits([%{owner: alice.addr, amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo(alice.addr)

      UtxoDB.consume_block(%Block{
        transactions: [API_Helper.create_recovered([{1, 0, 0, alice}], [{bob, 1}])],
        number: 2
      })

      assert %{"utxos" => []} = get_utxo(alice.addr)
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo(bob.addr)
    end
  end

  defp get_utxo(address) do
    TestHelper.rest_call(:get, "account/utxo?address=#{Client.encode(address)}")
  end
end
