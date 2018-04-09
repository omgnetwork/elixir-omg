defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGOWatcher.TransactionDB
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGO.API.{Block}

  @moduletag :watcher_tests

  @empty_signed_tx %Signed{
    raw_tx: %Transaction{
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
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
  end

  test "insert and retrive transaction" do
    txblknum = 0
    txindex = 0

    {:ok, %TransactionDB{id: id}} = TransactionDB.insert(@empty_signed_tx, txblknum, txindex)

    expected_transaction = create_expected_transaction(id, txblknum, txindex)

    assert expected_transaction == TransactionDB.get(id) |> delete_meta
  end

  test "insert and retrive block of transactions " do
    txblknum = 0

    [{:ok, %TransactionDB{id: txid_1}}, {:ok, %TransactionDB{id: txid_2}}] =
      TransactionDB.insert(
        %Block{
          transactions: [
            @empty_signed_tx,
            @empty_signed_tx
          ]
        },
        txblknum
      )

    expected_transaction_1 = create_expected_transaction(txid_1, txblknum, 0)
    expected_transaction_2 = create_expected_transaction(txid_2, txblknum, 1)

    assert expected_transaction_1 == TransactionDB.get(txid_1) |> delete_meta
    assert expected_transaction_2 == TransactionDB.get(txid_2) |> delete_meta
  end

  defp create_expected_transaction(txid, txblknum, txindex) do
    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      id: txid
    }
    |> Map.merge(Map.from_struct( @empty_signed_tx.raw_tx))
    |> delete_meta
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end

end
