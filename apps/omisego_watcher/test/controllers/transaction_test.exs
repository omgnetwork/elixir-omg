defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.TransactionDB

  @transaction %Transaction{
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

  @tag fixtures: [:watcher_sandbox]
  test "insert and retrive transaction" do
    txblknum = 0
    txindex = 0
    recovered = Transaction.make_recovered(@transaction)
    {:ok, %TransactionDB{txid: id}} = TransactionDB.insert(recovered, txblknum, txindex)
    expected_transaction = create_expected_transaction(id, recovered, txblknum, txindex)
    assert expected_transaction == delete_meta(TransactionDB.get(id))
  end

  @tag fixtures: [:watcher_sandbox]
  test "insert and retrive block of transactions " do
    txblknum = 0
    recovered1 = Transaction.make_recovered(@transaction)
    recovered2 = Transaction.make_recovered(put_in(@transaction.blknum1, 1))

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.insert(%Block{
        transactions: [
          recovered1,
          recovered2
        ],
        number: txblknum
      })

    expected_transaction_1 = create_expected_transaction(txid_1, recovered1, txblknum, 0)
    expected_transaction_2 = create_expected_transaction(txid_2, recovered2, txblknum, 1)

    assert expected_transaction_1 == delete_meta(TransactionDB.get(txid_1))
    assert expected_transaction_2 == delete_meta(TransactionDB.get(txid_2))
  end

  defp create_expected_transaction(txid, signed_tx, txblknum, txindex) do
    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      txid: txid
    }
    |> Map.merge(Map.from_struct(signed_tx.raw_tx))
    |> delete_meta
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end
end
