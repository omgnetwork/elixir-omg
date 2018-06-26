defmodule OmiseGOWatcherWeb.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.API.{Block}
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.TransactionDB
  alias OmiseGOWatcher.UtxoDB
  alias OmiseGOWatcher.TestHelper, as: Test

  @empty %Transaction{
    blknum1: 0,
    txindex1: 0,
    oindex1: 0,
    blknum2: 0,
    txindex2: 0,
    oindex2: 0,
    newowner1: "",
    amount1: 0,
    newowner2: "",
    amount2: 0,
    fee: 0
  }

  @signed_tx %Signed{
    raw_tx: @empty,
    sig1: <<>>,
    sig2: <<>>
  }

  describe "UTXO database." do
    @tag fixtures: [:watcher_sandbox]
    test "No utxo are returned for non-existing addresses." do
      assert get_utxo("cthulhu") == %{"utxos" => [], "address" => Client.encode("cthulhu")}
    end

    @tag fixtures: [:watcher_sandbox]
    test "Consumed block contents are available." do
      UtxoDB.consume_block(%Block{
        transactions: [
          @empty |> Map.merge(%{newowner1: "McDuck", amount1: 1947}) |> signed,
          @empty |> Map.merge(%{newowner1: "McDuck", amount1: 1952}) |> signed
        ],
        number: 2
      })

      %{"utxos" => [%{"amount" => amount1}, %{"amount" => amount2}]} = get_utxo("McDuck")

      assert Enum.sort([amount1, amount2]) == [1947, 1952]
    end

    @tag fixtures: [:watcher_sandbox]
    test "Spent utxos are moved to new owner." do
      UtxoDB.consume_block(%Block{
        transactions: [
          @empty |> Map.merge(%{newowner1: "Ebenezer", amount1: 1843}) |> signed,
          @empty |> Map.merge(%{newowner1: "Matilda", amount1: 1871}) |> signed
        ],
        number: 1
      })

      %{"utxos" => [%{"amount" => 1871}]} = get_utxo("Matilda")

      UtxoDB.consume_block(%Block{
        transactions: [
          @empty
          |> Map.merge(%{
            newowner1: "McDuck",
            amount1: 1000,
            blknum1: 1,
            txindex1: 1,
            oindex1: 0
          })
          |> signed
        ],
        number: 2
      })

      %{"utxos" => [%{"amount" => 1000}]} = get_utxo("McDuck")
      %{"utxos" => []} = get_utxo("Matilda")
    end

    @tag fixtures: [:watcher_sandbox]
    test "Deposits are a part of utxo set." do
      assert %{"utxos" => []} = get_utxo("Leon")
      UtxoDB.insert_deposits([%{owner: "Leon", amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo("Leon")
    end

    @tag fixtures: [:watcher_sandbox]
    test "Deposit utxo are moved to new owner if spent " do
      assert %{"utxos" => []} = get_utxo("Leon")
      assert %{"utxos" => []} = get_utxo("Matilda")
      UtxoDB.insert_deposits([%{owner: "Leon", amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo("Leon")

      spent = %{
        newowner1: "Matilda",
        amount1: 1,
        blknum1: 1,
        txindex1: 0,
        oindex1: 0
      }

      UtxoDB.consume_block(%Block{
        transactions: [
          @empty
          |> Map.merge(spent)
          |> signed
        ],
        number: 2
      })

      assert %{"utxos" => []} = get_utxo("Leon")
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo("Matilda")
    end
  end

  @tag fixtures: [:watcher_sandbox]
  test "The proof format is valid" do
    TransactionDB.insert(<<1>>, @signed_tx, 1, 1)
    TransactionDB.insert(<<2>>, @signed_tx, 1, 2)
    TransactionDB.insert(<<3>>, @signed_tx, 1, 3)

    %{
      utxo_pos: utxo_pos,
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = UtxoDB.compose_utxo_exit(1, 1, 0)

    assert << proof :: bytes-size(512)>> = proof

  end

  @tag fixtures: [:watcher_sandbox]
  test "The Utxo doesn't exsits" do
    
    %{
      utxo_pos: utxo_pos,
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = UtxoDB.compose_utxo_exit(1, 1, 0)

    assert << proof :: bytes-size(512)>> = proof

  end

  defp get_utxo(address) do
    Test.rest_call(:get, "account/utxo?address=#{Client.encode(address)}")
  end

  defp signed(transaction) do
    %Signed{raw_tx: transaction, sig1: <<>>, sig2: <<>>}
  end
end
